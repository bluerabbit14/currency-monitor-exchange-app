import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/auth_session.dart';
import '../entities/contact_identifier.dart';
import '../entities/google_sign_in_outcome.dart';
import '../entities/otp_challenge.dart';

abstract class AuthRepository {
  /// Emits the current session whenever it changes: a sign-in, a logout, or
  /// the backend rejecting the refresh token (null = signed out).
  Stream<AuthSession?> get sessionChanges;

  /// Loads the persisted session from secure storage. Makes no network call:
  /// an expired access token is renewed lazily on the first authenticated
  /// request, and a rejected refresh token signs the user out at that point.
  Future<AuthSession?> restoreSession();

  Future<Either<Failure, OtpChallenge>> sendOtp(ContactIdentifier contact);

  Future<Either<Failure, SignInResult>> verifyOtp(
    ContactIdentifier contact,
    String otp,
  );

  /// Google account picker, then backend verification of the ID token.
  Future<Either<Failure, GoogleSignInOutcome>> signInWithGoogle();

  Future<Either<Failure, SignInResult>> verifyGoogleLink({
    required String linkToken,
    required String otp,
  });

  /// Always clears the local session, even if revoking it on the server fails.
  Future<void> logout();
}
