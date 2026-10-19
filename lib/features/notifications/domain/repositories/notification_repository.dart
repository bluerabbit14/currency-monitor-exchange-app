import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/notification_preferences.dart';

abstract class NotificationRepository {
  Future<Either<Failure, NotificationPreferences>> getPreferences();

  /// Turns push notifications on or off. Returns the saved preferences.
  Future<Either<Failure, NotificationPreferences>> setPushEnabled(bool enabled);

  /// Registers this Android device's FCM token for the signed-in user.
  Future<Either<Failure, Unit>> registerDevice({
    required String fcmToken,
    String? deviceName,
  });
}
