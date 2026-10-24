import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification taps, as the FCM `data` map the backend sent.
///
/// Like [PushTokenProvider], this is a no-op where push is unavailable (not
/// Android, or Firebase failed to start), so the rest of the app never needs
/// to know.
abstract interface class PushMessageSource {
  /// Starts listening and showing foreground pushes. Safe to call once.
  Future<void> start();

  /// A notification was tapped while the app was running (foreground or
  /// background).
  Stream<Map<String, String>> get opened;

  /// The notification that launched the app from a terminated state, if any.
  Future<Map<String, String>?> initialMessage();
}

class NoPushMessageSource implements PushMessageSource {
  const NoPushMessageSource();

  @override
  Future<void> start() async {}

  @override
  Stream<Map<String, String>> get opened => const Stream.empty();

  @override
  Future<Map<String, String>?> initialMessage() async => null;
}

class FirebasePushMessageSource implements PushMessageSource {
  FirebasePushMessageSource();

  static const _channelId = 'moneyex_alerts';

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final _opened = StreamController<Map<String, String>>.broadcast();
  final _local = FlutterLocalNotificationsPlugin();
  var _started = false;

  @override
  Stream<Map<String, String>> get opened => _opened.stream;

  @override
  Future<void> start() async {
    if (!_supported || _started) return;
    _started = true;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _emit(_decode(response.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Price alerts',
              importance: Importance.high,
            ),
          );
      // Android does not show a push while the app is open: show it ourselves
      // so it can be tapped like any other.
      FirebaseMessaging.onMessage.listen(_showForeground);
      // A push shown by the system, tapped while the app was in the background.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _emit(_stringData(message.data)),
      );
    } catch (_) {
      // Firebase unavailable: no push, the app still works.
    }
  }

  @override
  Future<Map<String, String>?> initialMessage() async {
    if (!_supported) return null;
    try {
      final remote = await FirebaseMessaging.instance.getInitialMessage();
      if (remote != null) return _stringData(remote.data);
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        return _decode(launch?.notificationResponse?.payload);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Price alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(_stringData(message.data)),
    );
  }

  void _emit(Map<String, String>? data) {
    if (data != null) _opened.add(data);
  }

  static Map<String, String> _stringData(Map<String, dynamic> data) => {
    for (final entry in data.entries) entry.key: '${entry.value}',
  };

  static Map<String, String>? _decode(String? payload) {
    if (payload == null) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return {for (final e in decoded.entries) '${e.key}': '${e.value}'};
    } catch (_) {
      return null;
    }
  }
}
