import 'package:currency/core/error/failures.dart';
import 'package:currency/features/alerts/data/datasources/alert_remote_data_source.dart';
import 'package:currency/features/alerts/data/repositories/alert_repository_impl.dart';
import 'package:currency/features/alerts/domain/entities/price_alert.dart';
import 'package:currency/features/alerts/presentation/widgets/alert_editor_sheet.dart';
import 'package:currency/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:currency/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

Map<String, dynamic> alertJson({
  String id = 'a1',
  String condition = 'ABOVE',
  Object target = 4.0,
  String status = 'ACTIVE',
}) => {
  'id': id,
  'base': 'EUR',
  'quote': 'AED',
  'condition': condition,
  'targetRate': target,
  'status': status,
  'createdAt': '2026-10-12T04:00:00Z',
  'updatedAt': '2026-10-12T04:00:00Z',
  'triggeredAt': null,
};

void main() {
  late FakeAdapter adapter;
  late AlertRepositoryImpl repo;

  setUp(() {
    adapter = FakeAdapter((_) => apiError(500, 'unhandled'));
    repo = AlertRepositoryImpl(AlertRemoteDataSource(clientFor(adapter)));
  });

  group('alerts API', () {
    test('lists the user alerts from the Spring page', () async {
      adapter.handler = (_) => ok({
        'content': [
          alertJson(),
          alertJson(id: 'a2', condition: 'BELOW', target: 3),
        ],
        'page': {'size': 100, 'number': 0, 'totalElements': 2, 'totalPages': 1},
      });

      final alerts = (await repo.getAlerts()).getOrElse(() => throw 'x');

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/users/me/alerts');
      expect(request.queryParameters, {'page': 0, 'size': 100});
      expect(alerts.map((a) => a.id), ['a1', 'a2']);
      expect(alerts.first.condition, AlertCondition.above);
      expect(alerts.first.status, AlertStatus.active);
      expect(alerts.first.targetRate, 4.0);
      expect(alerts.last.condition, AlertCondition.below);
      expect(alerts.last.targetRate, 3.0, reason: 'integers parse too');
      expect(alerts.first.createdAt, DateTime.utc(2026, 10, 12, 4));
    });

    test(
      'creates with the backend field names and upper-case condition',
      () async {
        adapter.handler = (_) => ok(alertJson(id: 'new'), status: 201);

        final alert = (await repo.createAlert(
          base: 'EUR',
          quote: 'AED',
          condition: AlertCondition.below,
          targetRate: 3.95,
        )).getOrElse(() => throw 'x');

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/api/v1/users/me/alerts');
        expect(request.data, {
          'base': 'EUR',
          'quote': 'AED',
          'condition': 'BELOW',
          'targetRate': 3.95,
        });
        expect(alert.id, 'new');
      },
    );

    test('an unsupported pair gets a friendly message', () async {
      adapter.handler = (_) => apiError(
        404,
        'Pair EUR/AED is not supported',
        code: 'UNSUPPORTED_PAIR',
      );

      final failure = (await repo.createAlert(
        base: 'EUR',
        quote: 'AED',
        condition: AlertCondition.above,
        targetRate: 4,
      )).swap().getOrElse(() => throw 'x');

      expect(failure.message, "Alerts for EUR in AED aren't available yet");
      expect((failure as ServerFailure).code, 'UNSUPPORTED_PAIR');
    });

    test('updates send only the fields that changed', () async {
      adapter.handler = (_) => ok(alertJson(target: 5));

      await repo.updateAlert('a1', targetRate: 5);
      expect(adapter.requests.last.method, 'PATCH');
      expect(adapter.requests.last.path, '/api/v1/users/me/alerts/a1');
      expect(adapter.requests.last.data, {'targetRate': 5.0});

      await repo.updateAlert('a1', condition: AlertCondition.below);
      expect(adapter.requests.last.data, {'condition': 'BELOW'});

      await repo.updateAlert(
        'a1',
        condition: AlertCondition.above,
        targetRate: 4,
      );
      expect(adapter.requests.last.data, {
        'condition': 'ABOVE',
        'targetRate': 4.0,
      });
    });

    test('deletes with 204 No Content', () async {
      adapter.handler = (_) => noContent();

      final result = await repo.deleteAlert('a1');

      expect(result.isRight(), isTrue);
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/api/v1/users/me/alerts/a1');
    });

    test(
      '404, 400 and offline become failures with the right message',
      () async {
        adapter.handler = (_) => apiError(404, 'Alert not found');
        expect(
          (await repo.deleteAlert('x'))
              .swap()
              .getOrElse(() => throw 'x')
              .message,
          'Alert not found',
        );

        adapter.handler = (_) => apiError(
          400,
          'Validation failed',
          details: [
            {'field': 'targetRate', 'message': 'targetRate must be positive'},
          ],
        );
        expect(
          (await repo.updateAlert(
            'a',
            targetRate: 1,
          )).swap().getOrElse(() => throw 'x').message,
          'targetRate must be positive',
        );

        adapter.handler = (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
        expect(
          (await repo.getAlerts()).swap().getOrElse(() => throw 'x'),
          const NetworkFailure(),
        );
      },
    );

    test('a malformed alert is a failure, not a crash', () async {
      adapter.handler = (_) => ok({
        'content': [
          {'id': 'a', 'base': 'EUR'},
        ],
      });
      expect((await repo.getAlerts()).isLeft(), isTrue);

      adapter.handler = (_) => ok({
        'content': [alertJson(condition: 'SIDEWAYS')],
      });
      expect((await repo.getAlerts()).isLeft(), isTrue);

      adapter.handler = (_) => ok({'no': 'content'});
      expect((await repo.getAlerts()).isLeft(), isTrue);
    });
  });

  group('notification preferences + devices API', () {
    late NotificationRepositoryImpl notifications;

    setUp(() {
      notifications = NotificationRepositoryImpl(
        NotificationRemoteDataSource(clientFor(adapter)),
      );
    });

    Map<String, dynamic> prefs({bool push = true}) => {
      'pushEnabled': push,
      'inAppEnabled': true,
      'emailEnabled': false,
      'createdAt': '2026-10-12T04:00:00Z',
      'updatedAt': '2026-10-12T04:00:00Z',
    };

    test('reads the preferences', () async {
      adapter.handler = (_) => ok(prefs(push: false));

      final p = (await notifications.getPreferences()).getOrElse(
        () => throw 'x',
      );

      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.path,
        '/api/v1/users/me/notification-preferences',
      );
      expect(p.pushEnabled, isFalse);
      expect(p.inAppEnabled, isTrue);
      expect(p.emailEnabled, isFalse);
    });

    test('PATCHes only pushEnabled', () async {
      adapter.handler = (_) => ok(prefs(push: true));

      final p = (await notifications.setPushEnabled(true))
          .getOrElse(() => throw 'x');

      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.data, {'pushEnabled': true});
      expect(p.pushEnabled, isTrue);
    });

    test('registers the device as ANDROID with the FCM token', () async {
      adapter.handler = (_) =>
          ok({'id': 'd1', 'platform': 'ANDROID'}, status: 201);

      final result = await notifications.registerDevice(
        fcmToken: 'tok-123',
        deviceName: 'Pixel',
      );

      expect(result.isRight(), isTrue);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/v1/users/me/devices');
      expect(adapter.requests.single.data, {
        'fcmToken': 'tok-123',
        'platform': 'ANDROID',
        'deviceName': 'Pixel',
      });

      await notifications.registerDevice(fcmToken: 'tok-456');
      expect(adapter.requests.last.data, {
        'fcmToken': 'tok-456',
        'platform': 'ANDROID',
      });
    });

    test('failures and malformed bodies are reported', () async {
      adapter.handler = (_) => apiError(503, 'db');
      expect((await notifications.getPreferences()).isLeft(), isTrue);

      adapter.handler = (_) => ok({'pushEnabled': 'yes'});
      expect((await notifications.getPreferences()).isLeft(), isTrue);

      adapter.handler = (_) => apiError(400, 'FCM token is required');
      expect(
        (await notifications.registerDevice(fcmToken: 'x'))
            .swap()
            .getOrElse(() => throw 'x')
            .message,
        'FCM token is required',
      );
    });
  });

  group('target price parsing and formatting', () {
    test('accepts positive decimals with . or ,', () {
      expect(parseTargetRate('3.6725'), 3.6725);
      expect(parseTargetRate(' 90 '), 90);
      expect(parseTargetRate('3,67'), 3.67);
      expect(parseTargetRate('.5'), 0.5);
    });

    test('rejects empty, zero, negative and garbage', () {
      for (final bad in ['', ' ', '0', '0.0', '-1', 'abc', '1.2.3', '..']) {
        expect(parseTargetRate(bad), isNull, reason: bad);
      }
    });

    test('formatRate trims trailing zeros', () {
      expect(formatRate(3.6725), '3.6725');
      expect(formatRate(90), '90');
      expect(formatRate(4.5), '4.5');
      expect(formatRate(0.0045), '0.0045');
    });
  });
}
