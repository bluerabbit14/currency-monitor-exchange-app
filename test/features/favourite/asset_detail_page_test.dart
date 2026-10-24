import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/favourite/domain/entities/asset_item.dart';
import 'package:currency/features/favourite/domain/entities/price_point.dart';
import 'package:currency/features/favourite/presentation/pages/asset_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_favorite_repository.dart';

void main() {
  late FakeFavoriteRepository repo;

  setUp(() async {
    await sl.reset();
    await init();
    repo = await useFakeFavoriteRepository();
    repo.assets = [eurAsset];
    repo.quotes = {'EUR': const AssetQuote(rate: 4.2, change: 0.05)};
    final now = DateTime.now().toUtc();
    repo.history = [
      for (var i = 0; i < 60; i++)
        PricePoint(
          time: now.subtract(Duration(minutes: 60 - i)),
          rate: 4 + i * 0.01,
        ),
    ];
  });

  Future<void> open(WidgetTester tester, {bool isFavorite = false}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AssetDetailPage(
          asset: eurAsset,
          quoteCurrency: 'AED',
          isFavorite: isFavorite,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the price, intervals, high / low and the alert button', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Euro'), findsOneWidget);
    expect(find.text('AED 4.20'), findsOneWidget);
    for (final label in ['10m', '1H', '1D', '1W', '1M']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Set Price Alert'), findsOneWidget);
    expect(find.text('Failed to load chart'), findsNothing);
  });

  testWidgets('the heart adds to favorites and says so', (tester) async {
    await open(tester);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.added, [eurAsset.id]);
    expect(find.text('Added to Favorites'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('a failed history load offers Retry', (tester) async {
    repo.historyFailure = const NetworkFailure();
    await open(tester);

    expect(find.text('Failed to load chart'), findsOneWidget);

    repo.historyFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to load chart'), findsNothing);
  });

  testWidgets('tapping an interval keeps the page working', (tester) async {
    await open(tester);

    await tester.tap(find.text('10m'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1D'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load chart'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
