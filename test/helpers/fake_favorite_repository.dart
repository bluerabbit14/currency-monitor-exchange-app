import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/favourite/domain/entities/asset_item.dart';
import 'package:currency/features/favourite/domain/repositories/favorite_repository.dart';
import 'package:dartz/dartz.dart';

AssetItem fiat(String symbol, String name) => AssetItem(
  id: 'id-$symbol',
  symbol: symbol,
  name: name,
  kind: AssetKind.fiat,
);

final inrAsset = fiat('INR', 'Indian Rupee');
final usdAsset = fiat('USD', 'US Dollar');
final eurAsset = fiat('EUR', 'Euro');
final aedAsset = fiat('AED', 'United Arab Emirates Dirham');
const btcAsset = AssetItem(
  id: 'id-BTC',
  symbol: 'BTC',
  name: 'Bitcoin',
  kind: AssetKind.crypto,
);
const goldAsset = AssetItem(
  id: 'id-XAU',
  symbol: 'XAU',
  name: 'Gold',
  kind: AssetKind.commodity,
);

class FakeFavoriteRepository implements FavoriteRepository {
  List<AssetItem> favorites = [];
  List<AssetItem> assets = [];
  Failure? favoritesFailure;
  Failure? assetsFailure;
  Failure? addFailure;
  Failure? removeFailure;

  /// Quotes by symbol; a symbol in [quoteFailures] fails; a symbol with no
  /// entry fails too.
  Map<String, AssetQuote> quotes = {};
  final quoteFailures = <String>{};

  int loads = 0;
  final added = <String>[];
  final removed = <String>[];
  final quoteRequests = <String>[];

  @override
  Future<Either<Failure, List<AssetItem>>> getFavorites() async {
    loads++;
    final f = favoritesFailure;
    return f != null ? Left(f) : Right(List.of(favorites));
  }

  @override
  Future<Either<Failure, List<AssetItem>>> getAssets() async {
    final f = assetsFailure;
    return f != null ? Left(f) : Right(List.of(assets));
  }

  @override
  Future<Either<Failure, AssetItem>> addFavorite(String assetId) async {
    added.add(assetId);
    final f = addFailure;
    if (f != null) return Left(f);
    final asset = assets.firstWhere((a) => a.id == assetId);
    favorites = [asset, ...favorites];
    return Right(asset);
  }

  @override
  Future<Either<Failure, Unit>> removeFavorite(String assetId) async {
    removed.add(assetId);
    final f = removeFailure;
    if (f != null) return Left(f);
    favorites = favorites.where((a) => a.id != assetId).toList();
    return const Right(unit);
  }

  @override
  Future<Either<Failure, AssetQuote>> getQuote({
    required String symbol,
    required String quote,
  }) async {
    quoteRequests.add('$symbol/$quote');
    final q = quotes[symbol];
    if (quoteFailures.contains(symbol) || q == null) {
      return const Left(NetworkFailure());
    }
    return Right(q);
  }
}

/// Replaces the network-backed favorites repository registered by `init()`.
Future<void> installFavoriteRepository(FavoriteRepository fake) async {
  await sl.unregister<FavoriteRepository>();
  sl.registerLazySingleton<FavoriteRepository>(() => fake);
}

Future<FakeFavoriteRepository> useFakeFavoriteRepository() async {
  final fake = FakeFavoriteRepository();
  await installFavoriteRepository(fake);
  return fake;
}
