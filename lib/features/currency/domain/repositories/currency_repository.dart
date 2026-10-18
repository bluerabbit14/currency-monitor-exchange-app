import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/currency.dart';

abstract class CurrencyRepository {
  /// All active currencies, by name.
  Future<Either<Failure, List<Currency>>> getCurrencies();

  /// Saves the user's base currency on the backend.
  Future<Either<Failure, Unit>> setBaseCurrency(String currencyId);
}
