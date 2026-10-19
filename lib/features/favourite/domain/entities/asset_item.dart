import 'package:equatable/equatable.dart';

enum AssetKind {
  fiat,
  crypto,
  commodity;

  static AssetKind? fromApi(Object? value) {
    for (final k in values) {
      if (k.name.toUpperCase() == value) return k;
    }
    return null;
  }
}

/// A tradable asset: a currency, a coin or a commodity.
class AssetItem extends Equatable {
  const AssetItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.kind,
    this.isFavorite = false,
    this.createdAt,
  });

  final String id;

  /// e.g. `USD`, `BTC`, `XAU`.
  final String symbol;

  /// e.g. `US Dollar`.
  final String name;
  final AssetKind kind;

  /// Whether the signed-in user has favorited it. Only the grouped catalog
  /// (`GET /assets/grouped`) fills this in.
  final bool isFavorite;

  /// When the user favorited it. Only favorites carry it.
  final DateTime? createdAt;

  AssetItem copyWith({bool? isFavorite}) => AssetItem(
    id: id,
    symbol: symbol,
    name: name,
    kind: kind,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, symbol, name, kind, isFavorite, createdAt];
}

/// The current price of an asset in another currency.
class AssetQuote extends Equatable {
  const AssetQuote({required this.rate, this.change});

  final double rate;

  /// How much the price moved over the last 24 hours (positive = up); null
  /// when there is not enough history to tell.
  final double? change;

  @override
  List<Object?> get props => [rate, change];
}
