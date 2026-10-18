import 'package:equatable/equatable.dart';

sealed class ConverterEvent extends Equatable {
  const ConverterEvent();

  @override
  List<Object?> get props => const [];
}

final class ConvertRequested extends ConverterEvent {
  const ConvertRequested({
    required this.amount,
    required this.from,
    required this.to,
  });

  final double amount;
  final String from;
  final String to;

  @override
  List<Object?> get props => [amount, from, to];
}
