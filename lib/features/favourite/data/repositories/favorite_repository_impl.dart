import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/asset_item.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../datasources/favorite_remote_data_source.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  const FavoriteRepositoryImpl(this.remote, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FavoriteRemoteDataSource remote;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, List<AssetItem>>> getFavorites() =>
      guardApi(remote.getFavorites);

  @override
  Future<Either<Failure, List<AssetItem>>> getAssets() =>
      guardApi(remote.getAssets);

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
}
