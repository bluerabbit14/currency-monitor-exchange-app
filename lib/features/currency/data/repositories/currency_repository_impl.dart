import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/currency.dart';
import '../../domain/repositories/currency_repository.dart';
import '../datasources/currency_remote_data_source.dart';

class CurrencyRepositoryImpl implements CurrencyRepository {
  const CurrencyRepositoryImpl(this.remote);

  final CurrencyRemoteDataSource remote;

  @override
  Future<Either<Failure, List<Currency>>> getCurrencies() =>
      guardApi(remote.getCurrencies);

  @override
  Future<Either<Failure, Unit>> setBaseCurrency(String currencyId) =>
      guardApi(() async {
        await remote.setBaseCurrency(currencyId);
        return unit;
      });
}
