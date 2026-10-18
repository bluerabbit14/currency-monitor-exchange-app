 import 'package:equatable/equatable.dart';

const supportedCurrencyCodes = ['USD', 'EUR', 'GBP', 'INR'];

class Conversion extends Equatable {
  const Conversion({
    required this.amount,
    required this.from,
    required this.to,
    required this.result,
  });

  final double amount;
  final String from;
  final String to;
  final double result;

  @override
  List<Object?> get props => [amount, from, to, result];
}
