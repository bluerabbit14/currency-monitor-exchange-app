import 'dart:async';

import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/core/push/push_token_provider.dart';
import 'package:currency/features/alerts/domain/entities/price_alert.dart';
import 'package:currency/features/alerts/domain/repositories/alert_repository.dart';
import 'package:currency/features/notifications/domain/entities/notification_preferences.dart';
import 'package:currency/features/notifications/domain/repositories/notification_repository.dart';
import 'package:dartz/dartz.dart';

PriceAlert alertOf({
  String id = 'a1',
  String base = 'EUR',
  String quote = 'AED',
  AlertCondition condition = AlertCondition.above,
  double target = 4.0,
  AlertStatus status = AlertStatus.active,
  DateTime? createdAt,
}) => PriceAlert(
  id: id,
  base: base,
  quote: quote,
  condition: condition,
  targetRate: target,
  status: status,
  createdAt: createdAt ?? DateTime(2026, 1, 1),
);

class FakeAlertRepository implements AlertRepository {
  List<PriceAlert> alerts = [];
  Either<Failure, Unit>? failNext;
  Failure? listFailure;
  Failure? createFailure;
  Failure? updateFailure;
  Failure? deleteFailure;

  int loads = 0;
  final created = <Map<String, Object?>>[];
  final updated = <Map<String, Object?>>[];
  final deleted = <String>[];
  var _seq = 0;

  @override
  Future<Either<Failure, List<PriceAlert>>> getAlerts() async {
    loads++;
    final f = listFailure;
    return f != null ? Left(f) : Right(List.of(alerts));
  }

  @override
  Future<Either<Failure, PriceAlert>> createAlert({
    required String base,
    required String quote,
    required AlertCondition condition,
    required double targetRate,
  }) async {
    created.add({
      'base': base,
      'quote': quote,
      'condition': condition,
      'targetRate': targetRate,
    });
    final f = createFailure;
    if (f != null) return Left(f);
    final alert = alertOf(
      id: 'new-${++_seq}',
      base: base,
      quote: quote,
      condition: condition,
      target: targetRate,
      createdAt: DateTime(2026, 6, 1).add(Duration(minutes: _seq)),
    );
    alerts = [alert, ...alerts];
    return Right(alert);
  }

  @override
  Future<Either<Failure, PriceAlert>> updateAlert(
    String id, {
    AlertCondition? condition,
    double? targetRate,
  }) async {
    updated.add({'id': id, 'condition': condition, 'targetRate': targetRate});
    final f = updateFailure;
    if (f != null) return Left(f);
    final current = alerts.firstWhere((a) => a.id == id);
    final next = current.copyWith(condition: condition, targetRate: targetRate);
    alerts = [for (final a in alerts) a.id == id ? next : a];
    return Right(next);
  }

  @override
  Future<Either<Failure, Unit>> deleteAlert(String id) async {
    deleted.add(id);
    final f = deleteFailure;
    if (f != null) return Left(f);
    alerts = alerts.where((a) => a.id != id).toList();
    return const Right(unit);
  }
}

class FakeNotificationRepository implements NotificationRepository {
  bool push = true;
  Failure? getFailure;
  Failure? setFailure;
  Failure? registerFailure;

  int gets = 0;
  final setCalls = <bool>[];
  final registered = <String>[];

  NotificationPreferences get _prefs => NotificationPreferences(
    pushEnabled: push,
    inAppEnabled: true,
    emailEnabled: false,
  );

  @override
  Future<Either<Failure, NotificationPreferences>> getPreferences() async {
    gets++;
    final f = getFailure;
    return f != null ? Left(f) : Right(_prefs);
  }

  @override
  Future<Either<Failure, NotificationPreferences>> setPushEnabled(
    bool enabled,
  ) async {
    setCalls.add(enabled);
    final f = setFailure;
    if (f != null) return Left(f);
    push = enabled;
    return Right(_prefs);
  }

  @override
  Future<Either<Failure, Unit>> registerDevice({
    required String fcmToken,
    String? deviceName,
  }) async {
    registered.add(fcmToken);
    final f = registerFailure;
    return f != null ? Left(f) : const Right(unit);
  }
}

class FakePushTokenProvider implements PushTokenProvider {
  FakePushTokenProvider([this.token]);

  String? token;
  bool permissionGranted = true;
  int permissionRequests = 0;
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<String?> fcmToken() async => token;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;
}

Future<FakeAlertRepository> useFakeAlertRepository() async {
  final fake = FakeAlertRepository();
  await sl.unregister<AlertRepository>();
  sl.registerLazySingleton<AlertRepository>(() => fake);
  return fake;
}

Future<FakeNotificationRepository> useFakeNotificationRepository() async {
  final fake = FakeNotificationRepository();
  await sl.unregister<NotificationRepository>();
  sl.registerLazySingleton<NotificationRepository>(() => fake);
  return fake;
}

Future<FakePushTokenProvider> useFakePushToken([String? token]) async {
  final fake = FakePushTokenProvider(token);
  await sl.unregister<PushTokenProvider>();
  sl.registerLazySingleton<PushTokenProvider>(() => fake);
  return fake;
}
