import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/favourite/domain/entities/asset_item.dart';
import 'package:currency/features/favourite/domain/entities/price_point.dart';
import 'package:currency/features/favourite/domain/usecases/favorite_usecases.dart';
import 'package:currency/features/favourite/presentation/bloc/asset_detail_cubit.dart';
import 'package:currency/features/favourite/presentation/widgets/price_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_favorite_repository.dart';

PricePoint at(int minute, double rate) =>
    PricePoint(time: DateTime.utc(2026, 1, 1, 0, minute), rate: rate);

void main() {
  group('bucketPoints', () {
    test('keeps the last point of each bucket, oldest first', () {
      final points = [at(14, 3), at(1, 1), at(4, 2), at(6, 5), at(9, 6)];

      final result = bucketPoints(points, const Duration(minutes: 5));

      expect(result.map((p) => p.rate), [2, 6, 3]);
    });

    test('empty stays empty', () {
      expect(bucketPoints(const [], const Duration(hours: 1)), isEmpty);
    });
  });

  group('trend colour', () {
    test('rising is bullish, falling is bearish, flat counts as bullish', () {
      expect(isBullish([at(0, 1), at(5, 2)]), isTrue);
      expect(isBullish([at(0, 2), at(5, 1)]), isFalse);
      expect(isBullish([at(0, 2), at(5, 2)]), isTrue);
      expect(isBullish(const []), isTrue);
    });
  });

  group('AssetDetailCubit', () {
    late FakeFavoriteRepository repo;
    final now = DateTime.utc(2026, 1, 8);

    setUp(() async {
      await sl.reset();
      repo = FakeFavoriteRepository()
        ..quotes = {'EUR': const AssetQuote(rate: 4, change: 0.1)}
        ..assets = [eurAsset];
    });

    AssetDetailCubit cubit({bool isFavorite = false}) => AssetDetailCubit(
      GetAssetQuote(repo),
      GetAssetHistory(repo),
      AddFavorite(repo),
      RemoveFavorite(repo),
      asset: eurAsset,
      quoteCurrency: 'AED',
      isFavorite: isFavorite,
      now: () => now,
    );

    test('loads the price and a week of history', () async {
      repo.history = [at(0, 3.9), at(10, 4)];
      final c = cubit();

      await c.load();

      expect(c.state.quote?.rate, 4);
      expect(c.state.chartStatus, DetailChartStatus.ready);
      expect(c.state.history, hasLength(2));
      expect(repo.historyRequests, ['EUR/AED']);
    });

    test('switching the interval re-buckets without another request', () async {
      repo.history = [at(0, 1), at(1, 2), at(6, 3)];
      final c = cubit();
      await c.load();

      c.selectInterval(ChartInterval.m10);
      expect(c.state.series.map((p) => p.rate), [2, 3]);

      c.selectInterval(ChartInterval.h1);
      expect(c.state.series.map((p) => p.rate), [3]);
      expect(repo.historyRequests, hasLength(1));
    });

    test(
      'a history failure marks the chart failed but keeps the price',
      () async {
        repo.historyFailure = const NetworkFailure();
        final c = cubit();

        await c.load();

        expect(c.state.chartStatus, DetailChartStatus.failed);
        expect(c.state.quote?.rate, 4);
      },
    );

    test('an asset priced in itself has no chart request', () async {
      final c = AssetDetailCubit(
        GetAssetQuote(repo),
        GetAssetHistory(repo),
        AddFavorite(repo),
        RemoveFavorite(repo),
        asset: aedAsset,
        quoteCurrency: 'AED',
        isFavorite: false,
        now: () => now,
      );

      await c.load();

      expect(repo.historyRequests, isEmpty);
      expect(c.state.chartStatus, DetailChartStatus.ready);
      expect(c.state.series, isEmpty);
    });

    test('toggling adds, then removes the favorite', () async {
      final c = cubit();

      expect(await c.toggleFavorite(), isNull);
      expect(c.state.isFavorite, isTrue);
      expect(c.state.changed, isTrue);
      expect(repo.added, [eurAsset.id]);

      expect(await c.toggleFavorite(), isNull);
      expect(c.state.isFavorite, isFalse);
      expect(repo.removed, [eurAsset.id]);
    });

    test('a failed toggle keeps the flag and reports why', () async {
      repo.addFailure = const NetworkFailure();
      final c = cubit();

      final error = await c.toggleFavorite();

      expect(error, const NetworkFailure().message);
      expect(c.state.isFavorite, isFalse);
      expect(c.state.changed, isFalse);
      expect(c.state.favoriteBusy, isFalse);
    });
  });
}
