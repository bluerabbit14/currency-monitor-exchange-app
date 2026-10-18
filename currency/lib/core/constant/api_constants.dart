abstract final class ApiConstants {
  static const bool isAppLive = false;

  static const String stagingApiBaseUrl = '';
  static const String liveApiBasebaseUrl = '';

  static const String baseUrl = isAppLive
      ? liveApiBasebaseUrl
      : stagingApiBaseUrl;
}
