/// What the network layer needs from the session, without knowing how it is
/// stored or refreshed.
abstract interface class TokenProvider {
  Future<String?> accessToken();

  /// Gets a new access token. Returns it, or null when the session could not
  /// be renewed (the implementation signs the user out when the refresh token
  /// was rejected).
  Future<String?> refreshAccessToken();
}
