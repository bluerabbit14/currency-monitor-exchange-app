import '../../../../core/network/api_client.dart';
import '../../domain/entities/notification_preferences.dart';

class NotificationRemoteDataSource {
  const NotificationRemoteDataSource(this._client);

  /// The authenticated client.
  final ApiClient _client;

  static const _preferencesPath = '/api/v1/users/me/notification-preferences';
  static const _devicesPath = '/api/v1/users/me/devices';

  Future<NotificationPreferences> getPreferences() async =>
      _parse(await _client.get(_preferencesPath));

  Future<NotificationPreferences> setPushEnabled(bool enabled) async => _parse(
    await _client.patch(_preferencesPath, data: {'pushEnabled': enabled}),
  );

  /// Only Android is supported by the backend.
  Future<void> registerDevice({
    required String fcmToken,
    String? deviceName,
  }) async {
    await _client.post(
      _devicesPath,
      data: {
        'fcmToken': fcmToken,
        'platform': 'ANDROID',
        'deviceName': ?deviceName,
      },
    );
  }

  static NotificationPreferences _parse(Map<String, dynamic>? json) {
    final push = json?['pushEnabled'];
    final inApp = json?['inAppEnabled'];
    final email = json?['emailEnabled'];
    if (push is! bool || inApp is! bool || email is! bool) {
      throw const FormatException('Malformed notification preferences');
    }
    return NotificationPreferences(
      pushEnabled: push,
      inAppEnabled: inApp,
      emailEnabled: email,
    );
  }
}
