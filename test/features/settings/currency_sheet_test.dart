import 'package:country_flags/country_flags.dart';
import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/currency/domain/entities/currency.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:currency/features/settings/presentation/pages/settings_page.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_converter_repository.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_profile_repository.dart';

const aed = Currency(id: 'id-aed', code: 'AED', name: 'UAE Dirham');
const rub = Currency(id: 'id-rub', code: 'RUB', name: 'Russian Ruble');

void main() {
  late FakeAuthRepository auth;
  late FakeCurrencyRepository currencies;
  late FakeProfileRepository profile;

  setUp(() async {
    await sl.reset();
    await init();
    await useFakeConverterRepository();
    profile = await useFakeProfileRepository();
    currencies = await useFakeCurrencyRepository();
    currencies.list = const Right([usd, eur, inr, aed, rub]);
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

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Your currency'));
    await tester.pumpAndSettle();
  }

  testWidgets('the row shows the saved base currency from the profile', (
    tester,
  ) async {
    profile.result = const Right(
      UserProfile(email: 'me@example.com', baseCurrency: usd),
    );
    await openSettings(tester);

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('AED'), findsNothing);
  });

  testWidgets('no base currency yet: the row has no value', (tester) async {
    await openSettings(tester);

    expect(find.text('USD'), findsNothing);
    await openSheet(tester);
    expect(find.text('Select a currency'), findsOneWidget);
  });

  testWidgets('tapping the row opens the sheet with the current currency', (
    tester,
  ) async {
    profile.result = const Right(
      UserProfile(email: 'me@example.com', baseCurrency: usd),
    );
    await openSettings(tester);
    await openSheet(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(currencies.loads, 1);
    // Hero shows the current choice with its name.
    expect(inSheet(find.text('US Dollar')), findsOneWidget);
    // Popular grid (in the fixed order) then everything else.
    expect(inSheet(find.text('POPULAR')), findsOneWidget);
    expect(inSheet(find.text('OTHER')), findsOneWidget);
    expect(inSheet(find.text('AED')), findsOneWidget);
    expect(inSheet(find.text('UAE Dirham')), findsOneWidget);
    expect(inSheet(find.byType(CountryFlag)), findsWidgets);
    // Opening it saves nothing.
    expect(currencies.saved, isEmpty);
  });

  testWidgets(
    'tapping a currency only selects it: sheet stays open, nothing saved',
    (tester) async {
      profile.result = const Right(
        UserProfile(email: 'me@example.com', baseCurrency: usd),
      );
      await openSettings(tester);
      await openSheet(tester);

      await tester.tap(inSheet(find.text('AED')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(currencies.saved, isEmpty);
      // The hero follows the pick, the Settings row still shows the saved one.
      expect(inSheet(find.text('UAE Dirham')), findsNWidgets(2));
      expect(inSheet(find.text('US Dollar')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SettingsPage),
          matching: find.text('USD'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('closing saves the last pick exactly once', (tester) async {
    profile.result = const Right(
      UserProfile(email: 'me@example.com', baseCurrency: usd),
    );
    await openSettings(tester);
    await openSheet(tester);

    await tester.tap(inSheet(find.text('AED')));
    await tester.pump();
    await tester.tap(inSheet(find.text('RUB')));
    await tester.pump();
    await tester.tap(inSheet(find.text('EUR')));
    await tester.pump();
    expect(currencies.saved, isEmpty);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(currencies.saved, ['id-eur'], reason: 'one request, last pick');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
    expect(profile.calls, 1, reason: 'no refetch needed');
  });

  testWidgets('every way of closing the sheet saves the pick', (tester) async {
    profile.result = const Right(
      UserProfile(email: 'me@example.com', baseCurrency: usd),
    );
    await openSettings(tester);

    // Tap outside (the modal barrier).
    await openSheet(tester);
    await tester.tap(inSheet(find.text('AED')));
    await tester.pump();
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();
    expect(currencies.saved, ['id-aed']);
    expect(find.byType(BottomSheet), findsNothing);

    // System back.
    await openSheet(tester);
    await tester.tap(inSheet(find.text('RUB')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(currencies.saved, ['id-aed', 'id-rub']);

    // Swipe down.
    await openSheet(tester);
    await tester.tap(inSheet(find.text('EUR')));
    await tester.pump();
    await tester.drag(
      inSheet(find.text('Your currency')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    expect(currencies.saved, ['id-aed', 'id-rub', 'id-eur']);
    expect(find.text('EUR'), findsOneWidget);
  });

  testWidgets('no request when the pick is the current currency or nothing', (
    tester,
  ) async {
    profile.result = const Right(
      UserProfile(email: 'me@example.com', baseCurrency: usd),
    );
    await openSettings(tester);

    // Close without touching anything.
    await openSheet(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Pick something else, then go back to the original before closing.
    await openSheet(tester);
    await tester.tap(inSheet(find.text('AED')));
    await tester.pump();
    await tester.tap(inSheet(find.text('USD')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(currencies.saved, isEmpty);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets(
    'a failed save after closing keeps the old currency and says so',
    (tester) async {
      profile.result = const Right(
        UserProfile(email: 'me@example.com', baseCurrency: usd),
      );
      currencies.saveResult = const Left(NetworkFailure());
      await openSettings(tester);
      await openSheet(tester);

      await tester.tap(inSheet(find.text('AED')));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(currencies.saved, ['id-aed']);
      expect(
        find.textContaining("Couldn't update your currency"),
        findsOneWidget,
      );
      expect(find.text('USD'), findsOneWidget, reason: 'still the saved one');
      expect(find.text('AED'), findsNothing);
    },
  );

  testWidgets('the close button with no pick leaves the row alone', (
    tester,
  ) async {
    profile.result = const Right(
      UserProfile(email: 'me@example.com', baseCurrency: usd),
    );
    await openSettings(tester);
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(currencies.saved, isEmpty);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets('search filters every currency by code or name', (tester) async {
    await openSettings(tester);
    await openSheet(tester);

    await tester.enterText(inSheet(find.byType(TextField)), 'ruble');
    await tester.pumpAndSettle();
    expect(inSheet(find.text('RESULTS')), findsOneWidget);
    expect(inSheet(find.text('RUB')), findsOneWidget);
    expect(inSheet(find.text('POPULAR')), findsNothing);
    expect(inSheet(find.text('EUR')), findsNothing);

    // Popular currencies are searchable too.
    await tester.enterText(inSheet(find.byType(TextField)), 'eur');
    await tester.pumpAndSettle();
    expect(inSheet(find.text('EUR')), findsOneWidget);

    await tester.enterText(inSheet(find.byType(TextField)), 'zzz');
    await tester.pumpAndSettle();
    expect(inSheet(find.text('No currencies found')), findsOneWidget);
  });

  testWidgets('a failed list load shows Retry', (tester) async {
    currencies.list = const Left(NetworkFailure());
    await openSettings(tester);
    await openSheet(tester);

    expect(inSheet(find.text(const NetworkFailure().message)), findsOneWidget);

    currencies.list = const Right([usd, eur]);
    await tester.tap(inSheet(find.text('Retry')));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('POPULAR')), findsOneWidget);
    expect(currencies.loads, 2);
  });

  group('currency UI never overflows', () {
    const sizes = {
      'small phone': Size(320, 568),
      'compact phone': Size(360, 640),
      'regular phone': Size(390, 844),
      'landscape': Size(800, 360),
      'tablet': Size(820, 1180),
    };

    for (final entry in sizes.entries) {
      for (final textScale in [1.0, 1.5, 2.0]) {
        testWidgets('sheet + settings: ${entry.key}, text x$textScale', (
          tester,
        ) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearAllTestValues();
          });
          profile.result = const Right(
            UserProfile(
              displayName: 'A Very Long Display Name That Keeps Going',
              email: 'a.really.long.email.address@subdomain.example.com',
              baseCurrency: Currency(
                id: 'id-long',
                code: 'AED',
                name: 'United Arab Emirates Dirham With A Very Long Name',
              ),
            ),
          );
          currencies.list = const Right([
            usd,
            eur,
            inr,
            aed,
            rub,
            Currency(
              id: 'id-long',
              code: 'AED2',
              name: 'United Arab Emirates Dirham With A Very Long Name',
            ),
          ]);

          final session = AuthSessionCubit(auth);
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
          expect(tester.takeException(), isNull, reason: 'settings page');

          // Scroll each target into view first: with large text on a small
          // screen it can sit past the viewport and not be built yet.
          Future<void> reveal(Finder target, Finder scrollable) async {
            await tester.scrollUntilVisible(
              target,
              100,
              scrollable: scrollable.first,
            );
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
          }

          final settingsScroll = find.descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          );
          final row = find.text('Your currency');
          await reveal(row, settingsScroll);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'sheet, idle');

          final sheetScroll = inSheet(find.byType(Scrollable));

          // Keyboard up with the search field focused.
          final search = inSheet(find.byType(TextField));
          await reveal(search, sheetScroll);
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.tap(search);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'sheet, keyboard');
          tester.view.viewInsets = FakeViewPadding.zero;
          await tester.pumpAndSettle();

          // A selected popular tile shows the check mark: the tightest layout.
          final usdTile = inSheet(find.text('USD'));
          await reveal(usdTile, sheetScroll);
          await tester.tap(usdTile);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'sheet, selected');
        });
      }
    }
  });
}
