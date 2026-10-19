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
  });

  final String id;

  /// e.g. `USD`, `BTC`, `XAU`.
  final String symbol;

  /// e.g. `US Dollar`.
  final String name;
  final AssetKind kind;

  @override
  List<Object?> get props => [id, symbol, name, kind];
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
