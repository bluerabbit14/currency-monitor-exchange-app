import 'package:currency/core/di/injection.dart';
import 'package:currency/features/alerts/presentation/pages/price_alerts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_alerts_notifications.dart';

void main() {
  late FakeAlertRepository alerts;

  setUp(() async {
    await sl.reset();
    await init();
    alerts = await useFakeAlertRepository();
  });

  Future<void> open(WidgetTester tester, String? highlight) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PriceAlertsPage(baseCurrency: null, highlightAlertId: highlight),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says so when the alert from the notification is gone', (
    tester,
  ) async {
    alerts.alerts = [alertOf(id: 'a1')];

    await open(tester, 'deleted-alert-id');

    expect(find.text('This alert no longer exists'), findsOneWidget);
  });

  testWidgets('shows no message when the alert exists', (tester) async {
    alerts.alerts = [alertOf(id: 'a1')];

    await open(tester, 'a1');

    expect(find.text('This alert no longer exists'), findsNothing);
    expect(find.text('EUR / AED'), findsOneWidget);
  });

  testWidgets('shows no message when opened without an alert id', (
    tester,
  ) async {
    await open(tester, null);

    expect(find.text('This alert no longer exists'), findsNothing);
  });
}
