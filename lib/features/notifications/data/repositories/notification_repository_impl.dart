import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this.remote);

  final NotificationRemoteDataSource remote;

  @override
  Future<Either<Failure, NotificationPreferences>> getPreferences() =>
      guardApi(remote.getPreferences);

  @override
  Future<Either<Failure, NotificationPreferences>> setPushEnabled(
    bool enabled,
  ) => guardApi(() => remote.setPushEnabled(enabled));

  @override
  Future<Either<Failure, Unit>> registerDevice({
    required String fcmToken,
    String? deviceName,
  }) => guardApi(() async {
    await remote.registerDevice(fcmToken: fcmToken, deviceName: deviceName);
    return unit;
  });
}
