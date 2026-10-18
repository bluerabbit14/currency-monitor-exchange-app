import 'dart:async';

import 'package:currency/core/error/failures.dart';
import 'package:currency/features/auth/domain/entities/auth_session.dart';
import 'package:currency/features/auth/domain/entities/contact_identifier.dart';
import 'package:currency/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:currency/features/auth/domain/entities/otp_challenge.dart';
import 'package:currency/features/auth/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

final fakeSession = AuthSession(
  accessToken: 'a',
  refreshToken: 'r',
  accessTokenExpiresAt: DateTime(2030),
);
final fakeSignIn = SignInResult(session: fakeSession, isNewUser: false);

class FakeAuthRepository implements AuthRepository {
  final sessions = StreamController<AuthSession?>.broadcast();
  AuthSession? restored;
  int logouts = 0;
  int baseCurrencyMarks = 0;

  Future<Either<Failure, OtpChallenge>> Function(ContactIdentifier) onSend = (
    c,
  ) async => Right(OtpChallenge(contact: c, expiresInSeconds: 300));
  Future<Either<Failure, SignInResult>> Function(ContactIdentifier, String)
  onVerify = (_, _) async => Right(fakeSignIn);
  Future<Either<Failure, GoogleSignInOutcome>> Function() onGoogle = () async =>
      Right(GoogleSignedIn(fakeSignIn));
  Future<Either<Failure, SignInResult>> Function(String, String) onLink = (
    _,
    _,
  ) async => Right(fakeSignIn);

  final sent = <ContactIdentifier>[];

  @override
  Stream<AuthSession?> get sessionChanges => sessions.stream;
  @override
  Future<AuthSession?> restoreSession() async => restored;
  @override
  Future<Either<Failure, OtpChallenge>> sendOtp(ContactIdentifier c) {
    sent.add(c);
    return onSend(c);
  }

  @override
  Future<Either<Failure, SignInResult>> verifyOtp(
    ContactIdentifier c,
    String o,
  ) => onVerify(c, o);
  @override
  Future<Either<Failure, GoogleSignInOutcome>> signInWithGoogle() => onGoogle();
  @override
  Future<Either<Failure, SignInResult>> verifyGoogleLink({
    required String linkToken,
    required String otp,
  }) => onLink(linkToken, otp);
  @override
  Future<void> markBaseCurrencySelected() async {
    baseCurrencyMarks++;
    sessions.add(fakeSession);
  }

  @override
  Future<void> logout() async {
    logouts++;
    sessions.add(null);
  }
}
