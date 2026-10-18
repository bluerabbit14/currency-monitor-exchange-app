import 'package:equatable/equatable.dart';

import 'auth_session.dart';

/// Result of the backend's Google sign-in step.
sealed class GoogleSignInOutcome extends Equatable {
  const GoogleSignInOutcome();
}

/// Signed in (account created if it was new). The session is already stored.
class GoogleSignedIn extends GoogleSignInOutcome {
  const GoogleSignedIn(this.result);

  final SignInResult result;

  @override
  List<Object?> get props => [result];
}

/// The Google email already belongs to an account. The backend emailed an OTP
/// to that account; nothing is linked until it is verified with [linkToken].
class GoogleLinkRequired extends GoogleSignInOutcome {
  const GoogleLinkRequired({
    required this.linkToken,
    required this.maskedEmail,
    required this.expiresInSeconds,
  });

  final String linkToken;
  final String maskedEmail;
  final int expiresInSeconds;

  @override
  List<Object?> get props => [linkToken, maskedEmail, expiresInSeconds];
}
