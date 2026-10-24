import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/alerts/domain/entities/price_alert.dart';
import 'package:currency/features/alerts/presentation/pages/price_alerts_page.dart';
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
import '../../helpers/fake_favorite_repository.dart';
import '../../helpers/fake_profile_repository.dart';

const aed = Currency(id: 'id-aed', code: 'AED', name: 'UAE Dirham');

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeCurrencyRepository currencies;
  late FakeNotificationRepository notifications;
  late FakeAlertRepository alerts;
  late FakeFavoriteRepository assetCatalog;
  late FakePushTokenProvider push;

  setUp(() async {
    await sl.reset();
    await init();
    await useFakeConverterRepository();
    profile = await useFakeProfileRepository();
    currencies = await useFakeCurrencyRepository();
    notifications = await useFakeNotificationRepository();
    alerts = await useFakeAlertRepository();
    push = await useFakePushToken();
    assetCatalog = await useFakeFavoriteRepository();
    assetCatalog.assets = [usdAsset, eurAsset, inrAsset, aedAsset, btcAsset];
    currencies.list = const Right([usd, eur, inr, aed]);
    profile.result = const Right(
      UserProfile(
        email: 'me@example.com',
        baseCurrency: aed,
        notificationsEnabled: true,
      ),
    );
    auth = FakeAuthRepository()..restored = fakeSession;
  });

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = AuthSessionCubit(auth);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(BottomSheet), matching: f);

  Finder settingsRow(String value) =>
      find.descendant(of: find.byType(ListView), matching: find.text(value));

  Future<void> openNotifications(WidgetTester tester) async {
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();
  }

  Future<void> openAlertsPage(WidgetTester tester) async {
    await openSettings(tester);
    await openNotifications(tester);
    await tester.tap(inSheet(find.text('My Alerts')));
    await tester.pumpAndSettle();
  }

  group('notifications row and sheet', () {
    testWidgets('the row shows On / Off from the profile', (tester) async {
      await openSettings(tester);
      expect(settingsRow('On'), findsOneWidget);
    });

    testWidgets('Off when the profile says notifications are off', (
      tester,
    ) async {
      profile.result = const Right(
        UserProfile(email: 'a@b.co', notificationsEnabled: false),
      );
      await openSettings(tester);
      expect(settingsRow('Off'), findsOneWidget);
    });

    testWidgets('no value when the backend did not say', (tester) async {
      profile.result = const Right(UserProfile(email: 'a@b.co'));
      await openSettings(tester);
      expect(settingsRow('On'), findsNothing);
      expect(settingsRow('Off'), findsNothing);
    });

    testWidgets('tapping opens the sheet with both options', (tester) async {
      await openSettings(tester);
      expect(notifications.gets, 0, reason: 'nothing loads before it opens');

      await openNotifications(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(inSheet(find.text('Notifications')), findsOneWidget);
      expect(inSheet(find.text('My Alerts')), findsOneWidget);
      expect(
        inSheet(find.text('Get notified when price reaches your target')),
        findsOneWidget,
      );
      expect(inSheet(find.text('Significant Changes')), findsOneWidget);
      expect(tester.widget<Switch>(inSheet(find.byType(Switch))).value, isTrue);
      expect(notifications.gets, 1);
    });

    testWidgets('the switch saves, and the row follows after closing', (
      tester,
    ) async {
      await openSettings(tester);
      await openNotifications(tester);

      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(notifications.setCalls, [false]);
      expect(
        tester.widget<Switch>(inSheet(find.byType(Switch))).value,
        isFalse,
      );
      expect(notifications.registered, isEmpty, reason: 'only when turning on');

      await closeSheet(tester);
      expect(settingsRow('Off'), findsOneWidget);
      expect(profile.calls, 1, reason: 'no profile refetch');
    });

    testWidgets('a failed save puts the switch back and says why', (
      tester,
    ) async {
      notifications.setFailure = const NetworkFailure();
      await openSettings(tester);
      await openNotifications(tester);

      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(inSheet(find.byType(Switch))).value, isTrue);
      expect(
        inSheet(find.text(const NetworkFailure().message)),
        findsOneWidget,
      );
      await closeSheet(tester);
      expect(settingsRow('On'), findsOneWidget);
    });

    testWidgets('turning push on registers this device when a token exists', (
      tester,
    ) async {
      profile.result = const Right(
        UserProfile(email: 'a@b.co', notificationsEnabled: false),
      );
      notifications.push = false;
      push.token = 'fcm-token-1';
      await openSettings(tester);
      await openNotifications(tester);

      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(notifications.setCalls, [true]);
      expect(notifications.registered, isNotEmpty);
      expect(notifications.registered, everyElement('fcm-token-1'));
    });

    testWidgets(
      'no push token (Firebase not set up): preference saves, no device call',
      (tester) async {
        profile.result = const Right(
          UserProfile(email: 'a@b.co', notificationsEnabled: false),
        );
        notifications.push = false;
        await openSettings(tester);
        await openNotifications(tester);

        await tester.tap(inSheet(find.byType(Switch)));
        await tester.pumpAndSettle();

        expect(notifications.setCalls, [true]);
        expect(notifications.registered, isEmpty);
        expect(
          tester.widget<Switch>(inSheet(find.byType(Switch))).value,
          isTrue,
        );
      },
    );

    testWidgets('a device registration failure keeps the setting and warns', (
      tester,
    ) async {
      profile.result = const Right(
        UserProfile(email: 'a@b.co', notificationsEnabled: false),
      );
      notifications.push = false;
      notifications.registerFailure = const ServerFailure(
        'FCM token is required',
      );
      push.token = 'tok';
      await openSettings(tester);
      await openNotifications(tester);

      await tester.tap(inSheet(find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(inSheet(find.byType(Switch))).value, isTrue);
      expect(
        inSheet(find.textContaining("couldn't be registered")),
        findsOneWidget,
      );
    });

    testWidgets(
      'an unknown setting loads from the backend; failure offers Retry',
      (tester) async {
        profile.result = const Right(UserProfile(email: 'a@b.co'));
        notifications.getFailure = const NetworkFailure();
        await openSettings(tester);
        await openNotifications(tester);

        expect(
          inSheet(find.text(const NetworkFailure().message)),
          findsOneWidget,
        );
        expect(inSheet(find.byType(Switch)), findsNothing);

        notifications.getFailure = null;
        await tester.tap(inSheet(find.text('Retry')));
        await tester.pumpAndSettle();
        expect(inSheet(find.byType(Switch)), findsOneWidget);
      },
    );

    testWidgets('My Alerts closes the sheet and opens the alerts screen', (
      tester,
    ) async {
      await openAlertsPage(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(PriceAlertsPage), findsOneWidget);
      expect(find.text('Price Alerts'), findsOneWidget);
      expect(alerts.loads, 1);
    });
  });

  group('price alerts screen', () {
    testWidgets('empty state', (tester) async {
      await openAlertsPage(tester);

      expect(find.text('No alerts'), findsOneWidget);
      expect(
        find.text('Create an alert to get notifications about price changes'),
        findsOneWidget,
      );
      expect(find.text('Add alert'), findsOneWidget);
    });

    testWidgets('lists the user alerts', (tester) async {
      alerts.alerts = [
        alertOf(id: 'a1', base: 'EUR', target: 4.1),
        alertOf(
          id: 'a2',
          base: 'GBP',
          condition: AlertCondition.below,
          target: 4.6,
          status: AlertStatus.triggered,
          createdAt: DateTime(2026, 2, 1),
        ),
      ];
      await openAlertsPage(tester);

      expect(find.text('No alerts'), findsNothing);
      expect(find.text('GBP / AED'), findsOneWidget);
      expect(find.text('Notify when below 4.6 AED'), findsOneWidget);
      expect(find.text('Triggered'), findsOneWidget);
      expect(find.text('EUR / AED'), findsOneWidget);
      expect(find.text('Notify when above 4.1 AED'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      // Newest first.
      expect(
        tester.getTopLeft(find.text('GBP / AED')).dy,
        lessThan(tester.getTopLeft(find.text('EUR / AED')).dy),
      );
    });

    testWidgets('a failed load shows the error and Retry', (tester) async {
      alerts.listFailure = const NetworkFailure();
      await openAlertsPage(tester);
      expect(find.text(const NetworkFailure().message), findsOneWidget);

      alerts.listFailure = null;
      alerts.alerts = [alertOf()];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('EUR / AED'), findsOneWidget);
    });

    testWidgets('the back button returns to Settings', (tester) async {
      await openAlertsPage(tester);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(PriceAlertsPage), findsNothing);
      expect(find.text('Your currency'), findsOneWidget);
    });

    testWidgets('without a base currency, adding explains what to do', (
      tester,
    ) async {
      profile.result = const Right(
        UserProfile(email: 'a@b.co', notificationsEnabled: true),
      );
      await openAlertsPage(tester);

      await tester.tap(find.text('Add alert'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.text('Choose your currency in Settings to add alerts'),
        findsOneWidget,
      );
    });
  });

  group('creating an alert', () {
    Future<void> openCreate(WidgetTester tester) async {
      await openAlertsPage(tester);
      await tester.tap(find.text('Add alert'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseEuro(WidgetTester tester) async {
      await tester.tap(inSheet(find.text('Add Asset')));
      await tester.pumpAndSettle();
      // Two sheets are open now; tapping a row picks it and closes the chooser.
      await tester.tap(find.text('EUR').last);
      await tester.pumpAndSettle();
    }

    testWidgets('the editor opens with Create disabled', (tester) async {
      await openCreate(tester);

      expect(find.text('My Alerts'), findsOneWidget);
      expect(find.text('Asset'), findsOneWidget);
      expect(find.text('Add Asset'), findsOneWidget);
      expect(find.text('Notify when price is'), findsOneWidget);
      expect(find.text('above'), findsOneWidget);
      expect(find.text('below'), findsOneWidget);
      expect(find.text('Target price'), findsOneWidget);
      expect(find.text('AED'), findsOneWidget, reason: 'the base currency');
      final button = find.widgetWithText(FilledButton, 'Create Alert');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('the asset chooser never offers the base currency', (
      tester,
    ) async {
      await openCreate(tester);

      await tester.tap(inSheet(find.text('Add Asset')));
      await tester.pumpAndSettle();

      expect(find.text('Add Asset'), findsNWidgets(2));
      expect(find.text('EUR'), findsWidgets);
      // AED appears once: the quote label of the editor behind the chooser.
      expect(find.text('AED'), findsOneWidget);
    });

    testWidgets('create needs an asset and a positive price', (tester) async {
      await openCreate(tester);
      final button = find.widgetWithText(FilledButton, 'Create Alert');

      await tester.enterText(inSheet(find.byType(TextField)), '3.95');
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await chooseEuro(tester);
      expect(find.text('EUR · Euro'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await tester.enterText(inSheet(find.byType(TextField)), '0');
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.enterText(inSheet(find.byType(TextField)), 'abc');
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('creates the alert and shows it in the list', (tester) async {
      await openCreate(tester);
      await chooseEuro(tester);
      await tester.tap(inSheet(find.text('below')));
      await tester.pump();
      await tester.enterText(inSheet(find.byType(TextField)), '3,95');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Alert'));
      await tester.pumpAndSettle();

      expect(alerts.created, [
        {
          'base': 'EUR',
          'quote': 'AED',
          'condition': AlertCondition.below,
          'targetRate': 3.95,
        },
      ]);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('EUR / AED'), findsOneWidget);
      expect(find.text('Notify when below 3.95 AED'), findsOneWidget);
      expect(find.text('No alerts'), findsNothing);
    });

    testWidgets('defaults to above', (tester) async {
      await openCreate(tester);
      await chooseEuro(tester);
      await tester.enterText(inSheet(find.byType(TextField)), '4');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Alert'));
      await tester.pumpAndSettle();

      expect(alerts.created.single['condition'], AlertCondition.above);
    });

    testWidgets('an unsupported pair is explained and the sheet stays open', (
      tester,
    ) async {
      alerts.createFailure = const ServerFailure(
        "Alerts for EUR in AED aren't available yet",
        statusCode: 404,
        code: 'UNSUPPORTED_PAIR',
      );
      await openCreate(tester);
      await chooseEuro(tester);
      await tester.enterText(inSheet(find.byType(TextField)), '4');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Create Alert'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text("Alerts for EUR in AED aren't available yet"),
        findsOneWidget,
      );
      // The user can change their mind and retry.
      alerts.createFailure = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Create Alert'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(alerts.created, hasLength(2));
    });

    testWidgets('the close button discards the draft', (tester) async {
      await openCreate(tester);
      await chooseEuro(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(alerts.created, isEmpty);
    });
  });

  group('editing and deleting', () {
    setUp(() => alerts.alerts = [alertOf(id: 'a1', target: 4)]);

    Future<void> openEdit(WidgetTester tester) async {
      await openAlertsPage(tester);
      await tester.tap(find.text('EUR / AED'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens pre-filled with the pair fixed', (tester) async {
      await openEdit(tester);

      expect(find.text('Edit Alert'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save Changes'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(inSheet(find.byType(TextField)))
            .controller
            ?.text,
        '4',
      );
      // The watched currency cannot be changed: tapping the row does nothing.
      await tester.tap(inSheet(find.text('EUR')));
      await tester.pumpAndSettle();
      expect(find.text('Add Asset'), findsNothing);
    });

    testWidgets('saving sends only what changed', (tester) async {
      await openEdit(tester);

      await tester.enterText(inSheet(find.byType(TextField)), '4.5');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(alerts.updated, [
        {'id': 'a1', 'condition': null, 'targetRate': 4.5},
      ]);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Notify when above 4.5 AED'), findsOneWidget);
    });

    testWidgets('changing the condition is sent on its own', (tester) async {
      await openEdit(tester);

      await tester.tap(inSheet(find.text('below')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(alerts.updated, [
        {'id': 'a1', 'condition': AlertCondition.below, 'targetRate': null},
      ]);
      expect(find.text('Notify when below 4 AED'), findsOneWidget);
    });

    testWidgets('a failed update keeps the sheet open with the error', (
      tester,
    ) async {
      alerts.updateFailure = const ServerFailure('Alert not found');
      await openEdit(tester);

      await tester.enterText(inSheet(find.byType(TextField)), '5');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Alert not found'), findsOneWidget);
    });

    testWidgets('delete asks first, then removes the alert', (tester) async {
      await openEdit(tester);

      await tester.tap(find.text('Delete alert'));
      await tester.pumpAndSettle();
      expect(find.text('Delete alert?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(alerts.deleted, isEmpty);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.text('Delete alert'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(alerts.deleted, ['a1']);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('EUR / AED'), findsNothing);
      expect(find.text('No alerts'), findsOneWidget);
    });

    testWidgets('a failed delete is reported inline', (tester) async {
      alerts.deleteFailure = const NetworkFailure();
      await openEdit(tester);

      await tester.tap(find.text('Delete alert'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(const NetworkFailure().message), findsOneWidget);
      expect(find.text('EUR / AED'), findsOneWidget);
    });
  });
}
