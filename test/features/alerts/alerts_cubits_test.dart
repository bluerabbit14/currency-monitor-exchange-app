import 'dart:async';

import 'package:currency/core/error/failures.dart';
import 'package:currency/features/alerts/domain/entities/price_alert.dart';
import 'package:currency/features/alerts/domain/usecases/alert_usecases.dart';
import 'package:currency/features/alerts/presentation/bloc/alerts_cubit.dart';
import 'package:currency/features/notifications/domain/entities/notification_preferences.dart';
import 'package:currency/features/notifications/domain/usecases/notification_usecases.dart';
import 'package:currency/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:currency/features/notifications/presentation/bloc/push_device_registrar.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_alerts_notifications.dart';

class _SlowNotifications extends FakeNotificationRepository {
  final gate = Completer<void>();

  @override
  Future<Either<Failure, NotificationPreferences>> setPushEnabled(
    bool enabled,
  ) async {
    setCalls.add(enabled);
    await gate.future;
    push = enabled;
    return Right(
      NotificationPreferences(
        pushEnabled: enabled,
        inAppEnabled: true,
        emailEnabled: false,
      ),
    );
  }
}

NotificationsCubit notificationsCubit(
  FakeNotificationRepository repo, [
  String? token,
]) => NotificationsCubit(
  GetNotificationPreferences(repo),
  SetPushEnabled(repo),
  RegisterDevice(repo),
  FakePushTokenProvider(token),
);

AlertsCubit alertsCubit(FakeAlertRepository repo) => AlertsCubit(
  GetAlerts(repo),
  CreateAlert(repo),
  UpdateAlert(repo),
  DeleteAlert(repo),
);

void main() {
  group('NotificationsCubit', () {
    test(
      'a seeded value is usable at once and a failed refresh keeps it',
      () async {
        final repo = FakeNotificationRepository()
          ..getFailure = const NetworkFailure();
        final cubit = notificationsCubit(repo)..seed(true);
        expect(cubit.state.status, NotificationsStatus.ready);
        expect(cubit.state.pushEnabled, isTrue);

        await cubit.load();

        expect(cubit.state.status, NotificationsStatus.ready);
        expect(cubit.state.pushEnabled, isTrue);
        await cubit.close();
      },
    );

    test('load adopts the backend value over the seed', () async {
      final repo = FakeNotificationRepository()..push = false;
      final cubit = notificationsCubit(repo)..seed(true);
      await cubit.load();
      expect(cubit.state.pushEnabled, isFalse);
      await cubit.close();
    });

    test('a second toggle while one is saving is ignored', () async {
      final repo = _SlowNotifications();
      final cubit = notificationsCubit(repo)..seed(true);

      final first = cubit.setPush(false);
      await cubit.setPush(true);
      await cubit.setPush(false);
      expect(repo.setCalls, [false]);
      expect(cubit.state.isUpdating, isTrue);
      expect(cubit.state.pushEnabled, isFalse, reason: 'optimistic');

      repo.gate.complete();
      await first;
      expect(cubit.state.isUpdating, isFalse);
      await cubit.close();
    });

    test('setting the value it already has makes no request', () async {
      final repo = FakeNotificationRepository();
      final cubit = notificationsCubit(repo)..seed(true);
      await cubit.setPush(true);
      expect(repo.setCalls, isEmpty);
      await cubit.close();
    });

    test('an empty token is treated as no token', () async {
      final repo = FakeNotificationRepository()..push = false;
      final cubit = notificationsCubit(repo, '')..seed(false);
      await cubit.setPush(true);
      expect(repo.registered, isEmpty);
      await cubit.close();
    });

    test(
      'declining the permission leaves the setting off and untouched',
      () async {
        final repo = FakeNotificationRepository()..push = false;
        final tokens = FakePushTokenProvider('tok')..permissionGranted = false;
        final cubit = NotificationsCubit(
          GetNotificationPreferences(repo),
          SetPushEnabled(repo),
          RegisterDevice(repo),
          tokens,
        )..seed(false);

        await cubit.setPush(true);

        expect(cubit.state.pushEnabled, isFalse);
        expect(cubit.state.error, isNotNull);
        expect(repo.setCalls, isEmpty);
        expect(repo.registered, isEmpty);
        await cubit.close();
      },
    );

    test('turning it on asks permission and registers the device', () async {
      final repo = FakeNotificationRepository()..push = false;
      final tokens = FakePushTokenProvider('tok');
      final cubit = NotificationsCubit(
        GetNotificationPreferences(repo),
        SetPushEnabled(repo),
        RegisterDevice(repo),
        tokens,
      )..seed(false);

      await cubit.setPush(true);

      expect(tokens.permissionRequests, 1);
      expect(repo.registered, ['tok']);
      await cubit.close();
    });
  });

  group('PushDeviceRegistrar', () {
    test(
      'asks permission and registers on sign-in, again on refresh',
      () async {
        final repo = FakeNotificationRepository();
        final tokens = FakePushTokenProvider('t1');
        final registrar = PushDeviceRegistrar(tokens, RegisterDevice(repo));

        await registrar.onSignedIn();
        expect(tokens.permissionRequests, 1);
        expect(repo.registered, ['t1']);

        tokens.refreshes.add('t2');
        await Future<void>.delayed(Duration.zero);
        expect(repo.registered, ['t1', 't2']);

        await registrar.onSignedOut();
        tokens.refreshes.add('t3');
        await Future<void>.delayed(Duration.zero);
        expect(repo.registered, ['t1', 't2']);
      },
    );

    test('registers nothing when the permission is declined', () async {
      final repo = FakeNotificationRepository();
      final tokens = FakePushTokenProvider('t1')..permissionGranted = false;

      await PushDeviceRegistrar(tokens, RegisterDevice(repo)).onSignedIn();

      expect(repo.registered, isEmpty);
    });
  });

  group('AlertsCubit', () {
    test('keeps newest first as alerts are added', () async {
      final repo = FakeAlertRepository()
        ..alerts = [
          alertOf(id: 'old', createdAt: DateTime(2026, 1, 1)),
          alertOf(id: 'mid', createdAt: DateTime(2026, 3, 1)),
        ];
      final cubit = alertsCubit(repo);
      await cubit.load();
      expect(cubit.state.alerts.map((a) => a.id), ['mid', 'old']);

      final error = await cubit.create(
        const CreateAlertParams(
          base: 'EUR',
          quote: 'AED',
          condition: AlertCondition.above,
          targetRate: 4,
        ),
      );

      expect(error, isNull);
      expect(cubit.state.alerts.first.id, 'new-1');
      expect(cubit.state.alerts, hasLength(3));
      await cubit.close();
    });

    test('failures come back as messages and leave the list alone', () async {
      final repo = FakeAlertRepository()
        ..alerts = [alertOf(id: 'a1')]
        ..createFailure = const ServerFailure('nope')
        ..updateFailure = const ServerFailure('cannot update')
        ..deleteFailure = const NetworkFailure();
      final cubit = alertsCubit(repo);
      await cubit.load();

      expect(
        await cubit.create(
          const CreateAlertParams(
            base: 'EUR',
            quote: 'AED',
            condition: AlertCondition.above,
            targetRate: 4,
          ),
        ),
        'nope',
      );
      expect(
        await cubit.update(const UpdateAlertParams(id: 'a1', targetRate: 9)),
        'cannot update',
      );
      expect(await cubit.delete('a1'), const NetworkFailure().message);
      expect(cubit.state.alerts.single.targetRate, 4.0);
      await cubit.close();
    });
  });
}
