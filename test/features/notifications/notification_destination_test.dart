import 'package:currency/features/notifications/domain/entities/notification_destination.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '3f2b8c1e-9d4a-4e0b-8a57-1c2d3e4f5a6b';

void main() {
  group('NotificationDestination.fromData', () {
    test('PRICE_ALERT with an alert id opens the alerts list on that alert', () {
      expect(
        NotificationDestination.fromData({'type': 'PRICE_ALERT', 'alertId': _id}),
        const PriceAlertsDestination(alertId: _id),
      );
    });

    test('PRICE_ALERT without an alert id just opens the alerts list', () {
      expect(
        NotificationDestination.fromData({
          'type': 'PRICE_ALERT',
          'notificationId': _id,
        }),
        const PriceAlertsDestination(),
      );
    });

    test('a malformed alert id is rejected', () {
      expect(
        NotificationDestination.fromData({
          'type': 'PRICE_ALERT',
          'alertId': "1; DROP TABLE alerts",
        }),
        const UnsupportedDestination(),
      );
    });

    test('an unknown or missing type is unsupported', () {
      expect(
        NotificationDestination.fromData({'type': 'SOMETHING_NEW'}),
        const UnsupportedDestination(),
      );
      expect(
        NotificationDestination.fromData({'alertId': _id}),
        const UnsupportedDestination(),
      );
      expect(
        NotificationDestination.fromData({}),
        const UnsupportedDestination(),
      );
    });
  });
}
