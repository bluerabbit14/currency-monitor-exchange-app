import '../../domain/entities/auth_session.dart';

/// `AuthTokenResponse` / `OtpVerifyResponse` / the SIGNED_IN variant of
/// `GoogleOidcResponse` all share these fields.
class AuthTokensModel {
  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    required this.newUser,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expires = json['expiresInSeconds'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        expires is! num) {
      throw const FormatException('Malformed token response');
    }
    return AuthTokensModel(
      accessToken: access,
      refreshToken: refresh,
      expiresInSeconds: expires.toInt(),
      // Absent on /auth/refresh.
      newUser: json['newUser'] == true,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;
  final bool newUser;

  AuthSession toSession(DateTime now) => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiresAt: now.add(Duration(seconds: expiresInSeconds)),
  );
}

class OtpSendModel {
  const OtpSendModel({required this.contact, required this.expiresInSeconds});

  factory OtpSendModel.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'];
    final expires = json['expiresInSeconds'];
    if (contact is! String || expires is! num) {
      throw const FormatException('Malformed OTP send response');
    }
    return OtpSendModel(contact: contact, expiresInSeconds: expires.toInt());
  }

  final String contact;
  final int expiresInSeconds;
}

class GoogleOidcModel {
  const GoogleOidcModel({
    required this.signedIn,
    this.tokens,
    this.linkToken,
    this.maskedEmail,
    this.linkExpiresInSeconds,
  });

  factory GoogleOidcModel.fromJson(Map<String, dynamic> json) {
    switch (json['status']) {
      case 'SIGNED_IN':
        return GoogleOidcModel(
          signedIn: true,
          tokens: AuthTokensModel.fromJson(json),
        );
      case 'LINK_VERIFICATION_REQUIRED':
        final token = json['linkToken'];
        final masked = json['maskedEmail'];
        final expires = json['linkExpiresInSeconds'];
        if (token is! String ||
            token.isEmpty ||
            masked is! String ||
            expires is! num) {
          throw const FormatException('Malformed Google link response');
        }
        return GoogleOidcModel(
          signedIn: false,
          linkToken: token,
          maskedEmail: masked,
          linkExpiresInSeconds: expires.toInt(),
        );
      default:
        throw const FormatException('Unknown Google sign-in status');
    }
  }

  final bool signedIn;
  final AuthTokensModel? tokens;
  final String? linkToken;
  final String? maskedEmail;
  final int? linkExpiresInSeconds;
}
