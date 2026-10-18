abstract final class ApiConstants {
  /// Override per build: `--dart-define=IS_APP_LIVE=true`.
  static const bool isAppLive = bool.fromEnvironment('IS_APP_LIVE');

  /// Override with `--dart-define=STAGING_API_BASE_URL=http://10.0.2.2:8080`
  /// to reach a backend on the host machine from the Android emulator.
  static const String stagingApiBaseUrl = String.fromEnvironment(
    'STAGING_API_BASE_URL',
    defaultValue: 'https://currency-monitor-exchange-app-backend.onrender.com',
  );

  /// `--dart-define=LIVE_API_BASE_URL=https://...`. No default on purpose: a
  /// release build must not silently talk to a guessed host.
  static const String liveApiBaseUrl = String.fromEnvironment(
    'LIVE_API_BASE_URL',
  );

  static const String baseUrl = isAppLive ? liveApiBaseUrl : stagingApiBaseUrl;

  // Generous: a free-tier Render instance can take a minute to wake up.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  static const String otpSend = '/api/v1/auth/otp/send';
  static const String otpVerify = '/api/v1/auth/otp/verify';
  static const String refreshToken = '/api/v1/auth/refresh';
  static const String logout = '/api/v1/auth/logout';
  static const String googleSignIn = '/api/v1/auth/oidc/google';
  static const String googleLinkVerify = '/api/v1/auth/oidc/google/link/verify';
}
