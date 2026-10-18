import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constant/google_auth_constants.dart';
import '../../../../core/error/failures.dart';

/// Result of a successful Google sign-in. The [idToken] has NOT been verified
/// by our backend, so it must not be treated as a logged-in session.
class GoogleSignInResult {
  const GoogleSignInResult(this.idToken);

  final String idToken;
}

/// Raised when the user dismisses the Google account picker.
class GoogleSignInCancelledFailure extends AuthFailure {
  const GoogleSignInCancelledFailure() : super('Sign-in cancelled');
}

class GoogleSignInDataSource {
  GoogleSignInDataSource({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  /// `initialize` must be called exactly once; later calls reuse the same future.
  Future<void> _ensureInitialized() {
    return _initialization ??= () async {
      try {
        await _googleSignIn.initialize(
          serverClientId: GoogleAuthConstants.webClientId,
        );
      } catch (_) {
        _initialization = null; // allow retry after a failed init
        rethrow;
      }
    }();
  }

  Future<Either<Failure, GoogleSignInResult>> signIn() async {
    if (!GoogleAuthConstants.isConfigured) {
      return const Left(AuthFailure('Google Sign-In is not configured'));
    }
    try {
      await _ensureInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        return const Left(AuthFailure('Google Sign-In is not supported here'));
      }
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const Left(AuthFailure('Google did not return an ID token'));
      }
      return Right(GoogleSignInResult(idToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Left(GoogleSignInCancelledFailure());
      }
      return const Left(AuthFailure());
    } catch (_) {
      return const Left(AuthFailure());
    }
  }

  /// Forgets the selected Google account so the next sign-in shows the account
  /// picker. Best effort: never blocks or fails a logout.
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Nothing to do: the local session is already cleared.
    }
  }
}
