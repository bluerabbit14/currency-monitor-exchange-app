import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/asset_item.dart';
import '../../domain/entities/price_point.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../datasources/favorite_remote_data_source.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  const FavoriteRepositoryImpl(this.remote, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FavoriteRemoteDataSource remote;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, List<AssetItem>>> getFavorites() =>
      guardApi(() async => sortNewestFirst(await remote.getFavorites()));

  @override
  Future<Either<Failure, Map<AssetKind, List<AssetItem>>>> getAssetCatalog() =>
      guardApi(remote.getAssetCatalog);

  @override
  Future<Either<Failure, AssetItem>> addFavorite(String assetId) =>
      guardApi(() => remote.addFavorite(assetId));

  @override
  Future<Either<Failure, Unit>> removeFavorite(String assetId) =>
      guardApi(() async {
        await remote.removeFavorite(assetId);
        return unit;
      });

  @override
  Future<Either<Failure, AssetQuote>> getQuote({
    required String symbol,
    required String quote,
  }) async {
    // An asset priced in itself is always 1 and never moves; the backend has
    // no such pair.
    if (symbol.toUpperCase() == quote.toUpperCase()) {
      return const Right(AssetQuote(rate: 1, change: 0));
    }
    return guardApi(() async {
      final rate = await remote.getRate(symbol, quote);
      double? change;
      try {
        final now = _now();
        final oldest = await remote.getOldestRateSince(
          symbol,
          quote,
          now.subtract(const Duration(hours: 24)),
          now,
        );
        if (oldest != null) change = rate - oldest;
      } catch (_) {
        // The price is still useful without its change (history can be missing
        // or sparse for derived pairs), so a history failure is not an error.
      }
      return AssetQuote(rate: rate, change: change);
    });
  }

  @override
  Future<Either<Failure, List<PricePoint>>> getHistory({
    required String symbol,
    required String quote,
    required DateTime from,
    required DateTime to,
  }) => guardApi(() => remote.getHistory(symbol, quote, from, to));
}

/// Orders favorites by when they were added, newest first. Favorites without
/// a timestamp keep their given order, after the ones that have one.
List<AssetItem> sortNewestFirst(List<AssetItem> items) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final x = a.$2.createdAt;
    final y = b.$2.createdAt;
    if (x != null && y != null) {
      final byTime = y.compareTo(x);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    }
    if (x != null) return -1;
    if (y != null) return 1;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
