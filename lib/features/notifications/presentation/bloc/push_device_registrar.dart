import 'dart:async';

import '../../../../core/push/push_token_provider.dart';
import '../../domain/usecases/notification_usecases.dart';

/// Keeps this device registered with the backend while a user is signed in:
/// asks for the notification permission right after sign-in, registers the FCM
/// token, and registers again whenever FCM rotates it.
class PushDeviceRegistrar {
  PushDeviceRegistrar(this._tokens, this._registerDevice);

  final PushTokenProvider _tokens;
  final RegisterDevice _registerDevice;
  StreamSubscription<String>? _refreshes;

  Future<void> onSignedIn() async {
    if (!await _tokens.requestPermission()) return;
    await _register(await _tokens.fcmToken());
    await _refreshes?.cancel();
    _refreshes = _tokens.tokenRefreshes.listen(_register);
  }

  Future<void> onSignedOut() async {
    await _refreshes?.cancel();
    _refreshes = null;
  }

  // Best effort: a failed registration is retried on the next sign-in or
  // token refresh, and the user has nothing to act on.
  Future<void> _register(String? token) async {
    if (token == null || token.isEmpty) return;
    await _registerDevice(RegisterDeviceParams(fcmToken: token));
  }
}
