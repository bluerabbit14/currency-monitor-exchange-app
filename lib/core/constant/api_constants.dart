abstract final class ApiConstants {
  static const String appName = 'MoneyEx';

  static const String WebBaseUrl = 'https://vercel.com';
  static const String stagingApiBaseUrl =
      'https://currency-monitor-exchange-app-backend.onrender.com';
  static const String liveApiBaseUrl =
      'https://currency-monitor-exchange-app-backend.onrender.com';

  static const bool isAppLive = false;

  static const String baseUrl = isAppLive ? liveApiBaseUrl : stagingApiBaseUrl;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String otpSend = '/api/v1/auth/otp/send';
  static const String otpVerify = '/api/v1/auth/otp/verify';
  static const String refreshToken = '/api/v1/auth/refresh';
  static const String logout = '/api/v1/auth/logout';
  static const String googleSignIn = '/api/v1/auth/oidc/google';
  static const String googleLinkVerify = '/api/v1/auth/oidc/google/link/verify';
}
