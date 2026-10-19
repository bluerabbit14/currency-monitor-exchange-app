/// Source of this device's push (FCM) registration token.
///
/// The backend only accepts Android FCM tokens. Firebase is not set up in the
/// app yet, so the default implementation has no token and device registration
/// is skipped. To enable push: add `firebase_core` + `firebase_messaging`,
/// the Firebase config files, and register an implementation that returns
/// `FirebaseMessaging.instance.getToken()` on Android in
/// `core/di/injection.dart`.
abstract interface class PushTokenProvider {
  /// The FCM token, or null when push is not available on this device.
  Future<String?> fcmToken();
}

class NoPushTokenProvider implements PushTokenProvider {
  const NoPushTokenProvider();

  @override
  Future<String?> fcmToken() async => null;
}
