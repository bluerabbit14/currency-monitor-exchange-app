import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/conversion.dart';
import '../repositories/converter_repository.dart';

class ConvertCurrency implements UseCase<Conversion, ConvertParams> {
  const ConvertCurrency(this.repository);

  final ConverterRepository repository;

  @override
  Future<Either<Failure, Conversion>> call(ConvertParams params) {
    return repository.convert(
      amount: params.amount,
      from: params.from,
      to: params.to,
    );
  }
}

class ConvertParams extends Equatable {
  const ConvertParams({
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
