import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/asset_item.dart';
import '../entities/price_point.dart';

abstract class FavoriteRepository {
  /// The user's favorite assets, newest first.
  Future<Either<Failure, List<AssetItem>>> getFavorites();

  /// Every active asset grouped by type, each flagged when it is a favorite
  /// (for choosing what to favorite).
  Future<Either<Failure, Map<AssetKind, List<AssetItem>>>> getAssetCatalog();

  /// Adding twice is harmless (the backend returns the existing favorite).
  Future<Either<Failure, AssetItem>> addFavorite(String assetId);

  Future<Either<Failure, Unit>> removeFavorite(String assetId);

  /// Price of [symbol] in [quote] plus its 24-hour change. The change is
  /// best-effort: it is null when the history is unavailable.
  Future<Either<Failure, AssetQuote>> getQuote({
    required String symbol,
    required String quote,
  });

  /// Stored prices of [symbol] in [quote] between [from] and [to], oldest
  /// first. May be empty when nothing was stored for that period.
  Future<Either<Failure, List<PricePoint>>> getHistory({
    required String symbol,
    required String quote,
    required DateTime from,
    required DateTime to,
  });
}
