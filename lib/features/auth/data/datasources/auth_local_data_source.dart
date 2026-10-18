import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/auth_session.dart';

/// Persists the session in the platform keystore (Android Keystore-backed
/// encrypted storage / iOS Keychain). Tokens are never written to plain
/// shared preferences or logs.
class AuthLocalDataSource {
  AuthLocalDataSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'auth_session_v1';

  Future<AuthSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(
          json['expiresAtMs'] as int,
        ),
      );
    } catch (_) {
      // Unreadable (corrupt, keystore reset after a restore/backup): treat as
      // signed out rather than crashing on launch.
      await clear();
      return null;
    }
  }

  Future<void> write(AuthSession session) => _storage.write(
    key: _key,
    value: jsonEncode({
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'expiresAtMs': session.accessTokenExpiresAt.millisecondsSinceEpoch,
    }),
  );

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing more we can do; the in-memory session is dropped by the caller.
    }
  }
}
