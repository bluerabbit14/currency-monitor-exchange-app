import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/asset_item.dart';
import '../entities/price_point.dart';
import '../repositories/favorite_repository.dart';

class GetFavorites implements UseCase<List<AssetItem>, NoParams> {
  const GetFavorites(this.repository);

  final FavoriteRepository repository;

  @override
  Future<Either<Failure, List<AssetItem>>> call(NoParams params) =>
      repository.getFavorites();
}

class GetAssetCatalog
    implements UseCase<Map<AssetKind, List<AssetItem>>, NoParams> {
  const GetAssetCatalog(this.repository);

  final FavoriteRepository repository;

  @override
  Future<Either<Failure, Map<AssetKind, List<AssetItem>>>> call(
    NoParams params,
  ) => repository.getAssetCatalog();
}

class AddFavorite implements UseCase<AssetItem, String> {
  const AddFavorite(this.repository);

  final FavoriteRepository repository;

  /// [params] is the asset id.
  @override
  Future<Either<Failure, AssetItem>> call(String params) =>
      repository.addFavorite(params);
}

class RemoveFavorite implements UseCase<Unit, String> {
  const RemoveFavorite(this.repository);

  final FavoriteRepository repository;

  /// [params] is the asset id.
  @override
  Future<Either<Failure, Unit>> call(String params) =>
      repository.removeFavorite(params);
}

class GetAssetQuote implements UseCase<AssetQuote, AssetQuoteParams> {
  const GetAssetQuote(this.repository);

  final FavoriteRepository repository;

  @override
  Future<Either<Failure, AssetQuote>> call(AssetQuoteParams params) =>
      repository.getQuote(symbol: params.symbol, quote: params.quote);
}

class AssetQuoteParams extends Equatable {
  const AssetQuoteParams({required this.symbol, required this.quote});

  final String symbol;
  final String quote;

  @override
  List<Object?> get props => [symbol, quote];
}

class GetAssetHistory implements UseCase<List<PricePoint>, AssetHistoryParams> {
  const GetAssetHistory(this.repository);

  final FavoriteRepository repository;

  @override
  Future<Either<Failure, List<PricePoint>>> call(AssetHistoryParams params) =>
      repository.getHistory(
        symbol: params.symbol,
        quote: params.quote,
        from: params.from,
        to: params.to,
      );
}

class AssetHistoryParams extends Equatable {
  const AssetHistoryParams({
    required this.symbol,
    required this.quote,
    required this.from,
    required this.to,
  });

  final String symbol;
  final String quote;
  final DateTime from;
  final DateTime to;

  @override
  List<Object?> get props => [symbol, quote, from, to];
}
