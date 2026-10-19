import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/asset_item.dart';

abstract class FavoriteRepository {
  /// The user's favorite assets, newest first.
  Future<Either<Failure, List<AssetItem>>> getFavorites();

  /// Every active asset (for choosing what to favorite).
  Future<Either<Failure, List<AssetItem>>> getAssets();

  /// Adding twice is harmless (the backend returns the existing favorite).
  Future<Either<Failure, AssetItem>> addFavorite(String assetId);

  Future<Either<Failure, Unit>> removeFavorite(String assetId);

  /// Price of [symbol] in [quote] plus its 24-hour change. The change is
  /// best-effort: it is null when the history is unavailable.
  Future<Either<Failure, AssetQuote>> getQuote({
    required String symbol,
    required String quote,
  });
}
