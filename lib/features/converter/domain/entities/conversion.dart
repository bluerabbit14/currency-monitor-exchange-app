import 'package:equatable/equatable.dart';

import '../../../favourite/domain/entities/asset_item.dart';

/// How many units of the quote asset one unit of the base asset buys.
class ConverterRate extends Equatable {
  const ConverterRate({required this.rate, this.fetchedAt});

  final double rate;

  /// When the backend last refreshed this rate; null when it did not say.
  final DateTime? fetchedAt;

  @override
  List<Object?> get props => [rate, fetchedAt];
}

/// What the Converter remembers between launches: the rows, the row typed
/// into, and what was typed.
class ConverterSession extends Equatable {
  const ConverterSession({
    this.assets = const [],
    this.activeSymbol,
    this.expression = '',
  });

  final List<AssetItem> assets;
  final String? activeSymbol;
  final String expression;

  @override
  List<Object?> get props => [assets, activeSymbol, expression];
}
