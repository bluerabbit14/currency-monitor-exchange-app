import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/browse/presentation/pages/browse_page.dart';
import 'package:currency/features/currency/domain/entities/currency.dart';
import 'package:currency/features/favourite/domain/entities/asset_item.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_favorite_repository.dart';
import '../../helpers/fake_profile_repository.dart';

void main() {
  late FakeFavoriteRepository favorites;
  late FakeProfileRepository profile;

  setUp(() async {
    await sl.reset();
    await init();
    profile = await useFakeProfileRepository();
    favorites = await useFakeFavoriteRepository();
    profile.result = const Right(
      UserProfile(
        email: 'me@example.com',
        baseCurrency: Currency(id: 'id-aed', code: 'AED', name: 'UAE Dirham'),
      ),
    );
    favorites
      ..assets = [inrAsset, usdAsset, eurAsset, aedAsset, btcAsset, goldAsset]
      ..favorites = [usdAsset]
      ..quotes = {
        'INR': const AssetQuote(rate: 0.038306, change: 0.000018),
        'USD': const AssetQuote(rate: 3.67, change: 0.0002),
        'EUR': const AssetQuote(rate: 4.22, change: -0.004105),
        'AED': const AssetQuote(rate: 1, change: 0),
        'BTC': const AssetQuote(rate: 250000.5, change: 1200.25),
        'XAU': const AssetQuote(rate: 9000, change: -15),
      };
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: BrowsePage()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title, search, tabs and the currencies', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Search...'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Crypto'), findsOneWidget);
    expect(find.text('Commodities'), findsOneWidget);
    expect(find.text('INR'), findsOneWidget);
    expect(find.text('US Dollar'), findsOneWidget);
    // Other types are on their own tabs.
    expect(find.text('Bitcoin'), findsNothing);
    expect(find.text('Gold'), findsNothing);
  });

  testWidgets('prices are shown in the base currency with the 24h change', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('AED 0.038306'), findsOneWidget);
    expect(find.text('+AED 0.000018'), findsOneWidget);
    expect(find.text('AED 3.67'), findsOneWidget);
    expect(find.text('-AED 0.004105'), findsOneWidget);
    expect(favorites.quoteRequests, contains('USD/AED'));
  });

  testWidgets('the tabs switch between currencies, crypto and commodities', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Crypto'));
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('AED 250,000.50'), findsOneWidget);
    expect(find.text('Euro'), findsNothing);

    await tester.tap(find.text('Commodities'));
    await tester.pumpAndSettle();
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('-AED 15.00'), findsOneWidget);
    expect(find.text('Bitcoin'), findsNothing);
  });

  testWidgets('search filters by symbol or name within the tab', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'eur');
    await tester.pump();
    expect(find.text('Euro'), findsOneWidget);
    expect(find.text('US Dollar'), findsNothing);

    await tester.enterText(find.byType(TextField), 'dollar');
    await tester.pump();
    expect(find.text('US Dollar'), findsOneWidget);
    expect(find.text('Euro'), findsNothing);

    // Bitcoin lives on another tab.
    await tester.enterText(find.byType(TextField), 'bit');
    await tester.pump();
    expect(find.text('Nothing found'), findsOneWidget);
    await tester.tap(find.text('Crypto'));
    await tester.pumpAndSettle();
    expect(find.text('Bitcoin'), findsOneWidget);
  });

  testWidgets('only rows that are shown are priced', (tester) async {
    favorites.assets = [for (var i = 0; i < 60; i++) fiat('Q$i', 'Extra $i')];
    favorites.quotes = {
      for (var i = 0; i < 60; i++) 'Q$i': const AssetQuote(rate: 2, change: 0),
    };
    await open(tester);

    expect(favorites.quoteRequests, isNotEmpty);
    expect(favorites.quoteRequests.length, lessThan(60));
  });

  testWidgets('a price that fails shows a dash and does not block the rest', (
    tester,
  ) async {
    favorites.quoteFailures.add('EUR');
    await open(tester);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('AED 3.67'), findsOneWidget);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    favorites.assetsFailure = const NetworkFailure();
    await open(tester);
    expect(find.text(const NetworkFailure().message), findsOneWidget);
    expect(find.text('INR'), findsNothing);

    favorites.assetsFailure = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('INR'), findsOneWidget);
  });

  testWidgets('without a base currency prices are in USD', (tester) async {
    profile.result = const Right(UserProfile(email: 'me@example.com'));
    await open(tester);

    expect(favorites.quoteRequests, contains('INR/USD'));
    expect(find.text(r'$3.67'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(800, 360)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('never overflows at $size, text x$scale, keyboard up', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        await tester.pumpWidget(const MaterialApp(home: BrowsePage()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
