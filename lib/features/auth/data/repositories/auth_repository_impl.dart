import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/push/push_token_provider.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/contact_identifier.dart';
import '../../domain/entities/google_sign_in_outcome.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/google_sign_in_data_source.dart';
import '../models/auth_models.dart';
import '../token_manager.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._google,
    this._tokens, {
    PushTokenProvider? push,
    DateTime Function()? now,
  }) : _push = push ?? const NoPushTokenProvider(),
       _now = now ?? DateTime.now;

  final AuthRemoteDataSource _remote;
  final GoogleSignInDataSource _google;
  final TokenManager _tokens;
  final PushTokenProvider _push;
  final DateTime Function() _now;

  @override
  Stream<AuthSession?> get sessionChanges => _tokens.changes;

  @override
  Future<AuthSession?> restoreSession() async {
    // Local only: no request at launch. An expired access token is renewed
    // by the authenticated client on the first request that gets a 401.
    return _tokens.current();
  }

  @override
  Future<Either<Failure, OtpChallenge>> sendOtp(
    ContactIdentifier contact,
  ) => _guard(() async {
    final res = await _remote.sendOtp(contact.value);
    // Keep our parsed contact: the backend echoes it normalised, which is the
    // same value we sent.
    return OtpChallenge(
      contact: contact,
      expiresInSeconds: res.expiresInSeconds,
    );
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
  Future<void> markBaseCurrencySelected() async {
    final session = await _tokens.current();
    if (session == null || !session.requiresBaseCurrency) return;
    await _tokens.save(session.copyWith(requiresBaseCurrency: false));
  }

  @override
  Future<void> logout() async {
    final session = await _tokens.current();
    // Sign out locally first so the UI never waits on the network.
    await _tokens.clear();
    await _google.signOut();
    if (session == null) return;
    try {
      // Naming this device keeps the user's other devices registered.
      final fcmToken = await _push
          .fcmToken()
          .timeout(const Duration(seconds: 3), onTimeout: () => null)
          .catchError((_) => null);
      await _remote.logout(session.refreshToken, fcmToken: fcmToken);
    } catch (e) {
      // The refresh token stays valid server-side until it expires (30 days).
    }
  }

  Future<SignInResult> _store(AuthTokensModel tokens) async {
    // No base currency yet: the user must choose one before using the app.
    final session = tokens.toSession(
      _now(),
      requiresBaseCurrency: tokens.baseCurrencyId == null,
    );
    await _tokens.save(session);
    return SignInResult(session: session, isNewUser: tokens.newUser);
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) =>
      guardApi(action);
}
