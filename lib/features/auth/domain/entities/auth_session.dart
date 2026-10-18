import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;

  /// True when the access token is expired or about to be. [leeway] absorbs
  /// clock skew and request latency.
  bool isAccessTokenExpired({
    DateTime? now,
    Duration leeway = const Duration(seconds: 30),
  }) => !(now ?? DateTime.now()).add(leeway).isBefore(accessTokenExpiresAt);

  @override
  List<Object?> get props => [accessToken, refreshToken, accessTokenExpiresAt];
}

class SignInResult extends Equatable {
  const SignInResult({required this.session, required this.isNewUser});

  final AuthSession session;
  final bool isNewUser;

  @override
  List<Object?> get props => [session, isNewUser];
}
