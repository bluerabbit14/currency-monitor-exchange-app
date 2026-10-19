import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/notification_preferences.dart';
import '../repositories/notification_repository.dart';

class GetNotificationPreferences
    implements UseCase<NotificationPreferences, NoParams> {
  const GetNotificationPreferences(this.repository);

  final NotificationRepository repository;

  @override
  Future<Either<Failure, NotificationPreferences>> call(NoParams params) =>
      repository.getPreferences();
}

class SetPushEnabled implements UseCase<NotificationPreferences, bool> {
  const SetPushEnabled(this.repository);

  final NotificationRepository repository;

  @override
  Future<Either<Failure, NotificationPreferences>> call(bool params) =>
      repository.setPushEnabled(params);
}

class RegisterDevice implements UseCase<Unit, RegisterDeviceParams> {
  const RegisterDevice(this.repository);

  final NotificationRepository repository;

  @override
  Future<Either<Failure, Unit>> call(RegisterDeviceParams params) => repository
      .registerDevice(fcmToken: params.fcmToken, deviceName: params.deviceName);
}

class RegisterDeviceParams extends Equatable {
  const RegisterDeviceParams({required this.fcmToken, this.deviceName});

  final String fcmToken;
  final String? deviceName;

  @override
  List<Object?> get props => [fcmToken, deviceName];
}
