abstract final class GoogleAuthConstants {
  /// Web OAuth client ID, used as `serverClientId`.
  static const String webClientId =
      '213653578071-ghp3ir66ej9520umikoujhtrvb6ahhvt.apps.googleusercontent.com';

  static final RegExp _clientIdPattern = RegExp(
    r'^\d+-[a-z0-9]+\.apps\.googleusercontent\.com$',
  );

  /// True only for a non-empty, correctly formatted client ID (rejects
  /// placeholders such as `YOUR_...` and stray characters).
  static bool get isConfigured => _clientIdPattern.hasMatch(webClientId);
}
