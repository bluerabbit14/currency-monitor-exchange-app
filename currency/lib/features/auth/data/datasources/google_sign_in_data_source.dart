import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constant/google_auth_constants.dart';
import '../../../../core/error/failures.dart';

import 'package:logger/logger.dart';

final _logger = Logger();

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
        _logger.i('Google Sign-In initialized');
      } catch (e, st) {
        _initialization = null; // allow retry after a failed init
        _logger.e('Google Sign-In initialization failed', error: e, stackTrace: st);
        rethrow;
      }
    }();
  }

  Future<Either<Failure, GoogleSignInResult>> signIn() async {
    if (!GoogleAuthConstants.isConfigured) {
      _logger.w(
        'Google Sign-In not configured: web client ID is missing or malformed '
        '(length ${GoogleAuthConstants.webClientId.length})',
      );
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
        _logger.w('Google sign-in succeeded but returned no ID token');
        return const Left(AuthFailure('Google did not return an ID token'));
      }
      return Right(GoogleSignInResult(idToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _logger.i('Google sign-in cancelled by user');
        return const Left(GoogleSignInCancelledFailure());
      }
      _logger.e('Google sign-in failed: ${e.code} ${e.description}');
      return const Left(AuthFailure());
    } catch (e, st) {
      _logger.e('Unexpected Google sign-in error', error: e, stackTrace: st);
      return const Left(AuthFailure());
    }
  }
}
