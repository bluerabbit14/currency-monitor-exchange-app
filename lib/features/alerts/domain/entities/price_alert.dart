import 'package:equatable/equatable.dart';

enum AlertCondition {
  above,
  below;

  /// Value used by the backend (`ABOVE` / `BELOW`).
  String get api => name.toUpperCase();

  static AlertCondition? fromApi(Object? value) {
    for (final c in values) {
      if (c.api == value) return c;
    }
    return null;
  }
}

enum AlertStatus {
  active,
  triggered,
  cancelled;

  static AlertStatus? fromApi(Object? value) {
    for (final s in values) {
      if (s.name.toUpperCase() == value) return s;
    }
    return null;
  }
}

class PriceAlert extends Equatable {
  const PriceAlert({
    required this.id,
    required this.base,
    required this.quote,
    required this.condition,
    required this.targetRate,
    required this.status,
    this.createdAt,
    this.triggeredAt,
  });

  final String id;

  /// The asset being watched, e.g. `USD`.
  final String base;

  /// The currency the target is expressed in, e.g. `AED`.
  final String quote;
  final AlertCondition condition;
  final double targetRate;
  final AlertStatus status;
  final DateTime? createdAt;
  final DateTime? triggeredAt;

  PriceAlert copyWith({AlertCondition? condition, double? targetRate}) =>
      PriceAlert(
        id: id,
        base: base,
        quote: quote,
        condition: condition ?? this.condition,
        targetRate: targetRate ?? this.targetRate,
        status: status,
        createdAt: createdAt,
        triggeredAt: triggeredAt,
      );

  @override
  List<Object?> get props => [
    id,
    base,
    quote,
    condition,
    targetRate,
    status,
    createdAt,
    triggeredAt,
  ];
}
