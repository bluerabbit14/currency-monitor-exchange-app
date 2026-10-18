import '../../../../core/constant/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/auth_models.dart';

/// Raw auth endpoints. Throws [ApiException] / [NetworkException] /
/// [FormatException]; the repository maps those to failures.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  /// Must be an unauthenticated client: refreshing a token with the
  /// interceptor attached would recurse.
  final ApiClient _client;

  Future<OtpSendModel> sendOtp(String contact) async => OtpSendModel.fromJson(
    await _body(ApiConstants.otpSend, {'contact': contact}),
  );

  Future<AuthTokensModel> verifyOtp(String contact, String otp) async =>
      AuthTokensModel.fromJson(
        await _body(ApiConstants.otpVerify, {'contact': contact, 'otp': otp}),
      );

  Future<AuthTokensModel> refresh(String refreshToken) async =>
      AuthTokensModel.fromJson(
        await _body(ApiConstants.refreshToken, {'refreshToken': refreshToken}),
      );

  Future<void> logout(String refreshToken) async {
    await _client.post(
      ApiConstants.logout,
      data: {'refreshToken': refreshToken},
    );
  }

  Future<GoogleOidcModel> googleSignIn(String idToken) async =>
      GoogleOidcModel.fromJson(
        await _body(ApiConstants.googleSignIn, {'idToken': idToken}),
      );

  Future<AuthTokensModel> googleLinkVerify(String linkToken, String otp) async =>
      AuthTokensModel.fromJson(
        await _body(ApiConstants.googleLinkVerify, {
          'linkToken': linkToken,
          'otp': otp,
        }),
      );

  Future<Map<String, dynamic>> _body(
    String path,
    Map<String, dynamic> data,
  ) async {
    final body = await _client.post(path, data: data);
    if (body == null) throw const FormatException('Empty response body');
    return body;
  }
}
