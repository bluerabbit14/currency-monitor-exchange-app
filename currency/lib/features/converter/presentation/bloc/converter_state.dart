import 'package:equatable/equatable.dart';

import '../../domain/entities/conversion.dart';

sealed class ConverterState extends Equatable {
  const ConverterState();

  @override
  List<Object?> get props => const [];
}

final class ConverterInitial extends ConverterState {
  const ConverterInitial();
}

final class ConverterLoading extends ConverterState {
  const ConverterLoading();
}

final class ConverterSuccess extends ConverterState {
  const ConverterSuccess(this.conversion);

  final Conversion conversion;

  @override
  List<Object?> get props => [conversion];
}

final class ConverterFailure extends ConverterState {
  const ConverterFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
