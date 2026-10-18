import 'package:equatable/equatable.dart';

class Currency extends Equatable {
  const Currency({required this.id, required this.code, required this.name});

  final String id;

  /// ISO 4217 code, e.g. `USD`.
  final String code;

  /// English name, e.g. `US Dollar`.
  final String name;

  @override
  List<Object?> get props => [id, code, name];
}
