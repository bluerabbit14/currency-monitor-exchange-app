import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/currency_repository.dart';

class SetBaseCurrency implements UseCase<Unit, String> {
  const SetBaseCurrency(this.repository);

  final CurrencyRepository repository;

  /// [params] is the currency id.
  @override
  Future<Either<Failure, Unit>> call(String params) =>
      repository.setBaseCurrency(params);
}
