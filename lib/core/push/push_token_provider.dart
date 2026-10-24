import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Source of this device's push (FCM) registration token.
///
/// The backend only accepts Android FCM tokens, so on any other platform (or
/// when Firebase failed to start) there is no token and registration is skipped.
abstract interface class PushTokenProvider {
  /// The FCM token, or null when push is not available on this device.
  Future<String?> fcmToken();

  /// Asks the user to allow notifications. False only when they declined;
  /// where there is nothing to ask (no push on this platform) it is true.
  Future<bool> requestPermission();

  /// A new token, whenever FCM rotates this device's token.
  Stream<String> get tokenRefreshes;
}

class NoPushTokenProvider implements PushTokenProvider {
  const NoPushTokenProvider();

  @override
  Future<String?> fcmToken() async => null;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

class FirebasePushTokenProvider implements PushTokenProvider {
  const FirebasePushTokenProvider();

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> fcmToken() async {
    if (!_supported) return null;
    try {
      // The backend sends to FCM registration tokens; the newer register() API
      // yields a Firebase Installation ID instead.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      // Firebase unavailable: nothing to ask, and nothing to register.
      return true;
    }
  }

  @override
  Stream<String> get tokenRefreshes {
    if (!_supported) return const Stream.empty();
    try {
      // ignore: deprecated_member_use
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }
}
