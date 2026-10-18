import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/contact_identifier.dart';
import '../../domain/entities/google_sign_in_outcome.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/google_sign_in_data_source.dart';
import '../models/auth_models.dart';
import '../token_manager.dart';

final _logger = Logger();

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._google,
    this._tokens, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AuthRemoteDataSource _remote;
  final GoogleSignInDataSource _google;
  final TokenManager _tokens;
  final DateTime Function() _now;

  @override
  Stream<AuthSession?> get sessionChanges => _tokens.changes;

  @override
  Future<AuthSession?> restoreSession() async {
    final session = await _tokens.current();
    if (session == null) return null;
    if (!session.isAccessTokenExpired(now: _now())) return session;
    // Null here means either "rejected" (already cleared) or "couldn't
    // reach the server". In the second case keep the user signed in; the
    // next authenticated request retries the refresh.
    return await _tokens.refresh() ?? await _tokens.current();
  }

  @override
  Future<Either<Failure, OtpChallenge>> sendOtp(
    ContactIdentifier contact,
  ) => _guard(() async {
    final res = await _remote.sendOtp(contact.value);
    // Keep our parsed contact: the backend echoes it normalised, which is the
    // same value we sent.
    return OtpChallenge(contact: contact, expiresInSeconds: res.expiresInSeconds);
  });

  @override
  Future<Either<Failure, SignInResult>> verifyOtp(
    ContactIdentifier contact,
    String otp,
  ) => _guard(() async => _store(await _remote.verifyOtp(contact.value, otp)));

  @override
  Future<Either<Failure, GoogleSignInOutcome>> signInWithGoogle() async {
    final google = await _google.signIn();
    return google.fold(
      (failure) async => Left<Failure, GoogleSignInOutcome>(failure),
      (ok) => _guard<GoogleSignInOutcome>(() async {
        final res = await _remote.googleSignIn(ok.idToken);
        if (res.signedIn) return GoogleSignedIn(await _store(res.tokens!));
        return GoogleLinkRequired(
          linkToken: res.linkToken!,
          maskedEmail: res.maskedEmail!,
          expiresInSeconds: res.linkExpiresInSeconds!,
        );
      }),
    );
  }

  @override
  Future<Either<Failure, SignInResult>> verifyGoogleLink({
    required String linkToken,
    required String otp,
  }) => _guard(
    () async => _store(await _remote.googleLinkVerify(linkToken, otp)),
  );

  @override
  Future<void> logout() async {
    final session = await _tokens.current();
    // Sign out locally first so the UI never waits on the network.
    await _tokens.clear();
    await _google.signOut();
    if (session == null) return;
    try {
      await _remote.logout(session.refreshToken);
    } catch (e) {
      // The refresh token stays valid server-side until it expires (30 days).
      _logger.w('Server-side logout failed: $e');
    }
  }

  Future<SignInResult> _store(AuthTokensModel tokens) async {
    final session = tokens.toSession(_now());
    await _tokens.save(session);
    return SignInResult(session: session, isNewUser: tokens.newUser);
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ApiException catch (e) {
      return Left(_fromApi(e));
    } on FormatException catch (e) {
      _logger.e('Malformed auth response: ${e.message}');
      return const Left(ServerFailure('Unexpected response from server'));
    } catch (e, st) {
      _logger.e('Unexpected auth error', error: e, stackTrace: st);
      return const Left(AuthFailure());
    }
  }

  /// Backend 4xx messages are written for end users ("Invalid or expired
  /// OTP."), so they are shown as-is. 5xx details are not.
  static Failure _fromApi(ApiException e) {
    if (e.statusCode == 429) {
      return ServerFailure(
        'Too many attempts. Please wait a moment and try again',
        statusCode: e.statusCode,
        code: e.code,
      );
    }
    if (e.statusCode >= 500) {
      return ServerFailure(
        e.statusCode == 503
            ? 'Service temporarily unavailable. Please try again shortly'
            : 'Something went wrong. Please try again',
        statusCode: e.statusCode,
        code: e.code,
      );
    }
    final message = e.statusCode == 400 && e.fieldErrors.isNotEmpty
        ? e.fieldErrors.values.first
        : e.message;
    return ServerFailure(message, statusCode: e.statusCode, code: e.code);
  }
}
