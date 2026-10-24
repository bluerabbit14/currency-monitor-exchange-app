import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/alerts/domain/entities/price_alert.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/currency/domain/entities/currency.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_converter_repository.dart';

import '../../helpers/fake_alerts_notifications.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_profile_repository.dart';

/// The notifications sheet, alerts screen and alert editor at small / large /
/// landscape sizes with large text must never overflow.
void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'regular phone': Size(390, 844),
    'landscape': Size(800, 360),
  };

  for (final entry in sizes.entries) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('notifications + alerts: ${entry.key}, text x$textScale', (
        tester,
      ) async {
        await sl.reset();
        await init();
        await useFakeConverterRepository();
        final profile = await useFakeProfileRepository();
        final currencies = await useFakeCurrencyRepository();
        await useFakeNotificationRepository();
        final alerts = await useFakeAlertRepository();
        await useFakePushToken();
        const long = Currency(
          id: 'id-aed',
          code: 'AED',
          name: 'United Arab Emirates Dirham With A Very Long Name Indeed',
        );
        currencies.list = const Right([usd, eur, inr, long]);
        profile.result = const Right(
          UserProfile(
            email: 'me@example.com',
            baseCurrency: long,
            notificationsEnabled: true,
          ),
        );
        alerts.alerts = [
          for (var i = 0; i < 4; i++)
            alertOf(
              id: 'a$i',
              base: 'EUR',
              quote: 'AED',
              condition: i.isEven ? AlertCondition.above : AlertCondition.below,
              target: 123456.789012,
              status: AlertStatus.values[i % 3],
              createdAt: DateTime(2026, 1, 1 + i),
            ),
        ];

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });

        Future<void> reveal(Finder target, {Finder? within}) async {
          await tester.scrollUntilVisible(
            target,
            100,
            scrollable: (within ?? find.byType(Scrollable)).first,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
        }

        final session = AuthSessionCubit(
          FakeAuthRepository()..restored = fakeSession,
        );
        await tester.pumpWidget(CurrencyApp(sessionCubit: session));
        await session.start();
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(FloatingNavBar),
            matching: find.byIcon(Icons.settings_outlined),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'settings');

        // Notifications sheet.
        final row = find.text('Notifications');
        await reveal(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'notifications sheet');

        final myAlerts = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('My Alerts'),
        );
        await reveal(
          myAlerts,
          within: find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(myAlerts);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'alerts list');

        // Editor: edit an existing alert (long numbers + long currency name).
        final card = find.text('EUR / AED').first;
        await reveal(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'edit sheet');

        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'edit sheet + keyboard');
      });
    }
  }
}
