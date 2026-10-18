import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/currency.dart';
import '../repositories/currency_repository.dart';

class GetCurrencies implements UseCase<List<Currency>, NoParams> {
  const GetCurrencies(this.repository);

  final CurrencyRepository repository;

  @override
  Future<Either<Failure, List<Currency>>> call(NoParams params) =>
      repository.getCurrencies();
}
