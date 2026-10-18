import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    this.requiresBaseCurrency = false,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;

  /// Set when the account was just created: the user must pick a base
  /// currency before entering the app. It is stored with the session, so it
  /// survives the app being closed before the choice is made.
  final bool requiresBaseCurrency;

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    bool? requiresBaseCurrency,
  }) => AuthSession(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
    requiresBaseCurrency: requiresBaseCurrency ?? this.requiresBaseCurrency,
  );

  /// True when the access token is expired or about to be. [leeway] absorbs
  /// clock skew and request latency.
  bool isAccessTokenExpired({
    DateTime? now,
    Duration leeway = const Duration(seconds: 30),
  }) => !(now ?? DateTime.now()).add(leeway).isBefore(accessTokenExpiresAt);

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    accessTokenExpiresAt,
    requiresBaseCurrency,
  ];
}

class SignInResult extends Equatable {
  const SignInResult({required this.session, required this.isNewUser});

  final AuthSession session;
  final bool isNewUser;

  @override
  List<Object?> get props => [session, isNewUser];
}
