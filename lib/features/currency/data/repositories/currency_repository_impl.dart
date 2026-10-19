import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/currency.dart';
import '../../domain/repositories/currency_repository.dart';
import '../datasources/currency_remote_data_source.dart';

/// Registered as a singleton, so the currency list is fetched once and shared
/// by everything that asks for it (the login-time preload, the base-currency
/// screen, the picker sheet).
class CurrencyRepositoryImpl implements CurrencyRepository {
  CurrencyRepositoryImpl(this.remote);

  final CurrencyRemoteDataSource remote;

  List<Currency>? _cached;
  Future<Either<Failure, List<Currency>>>? _inFlight;

  /// Returns the cached list, joins a request already in flight, or starts
  /// one. Only a success is cached, so a failed load is retried by the next
  /// call instead of being remembered.
  @override
  Future<Either<Failure, List<Currency>>> getCurrencies() {
    final cached = _cached;
    if (cached != null) return Future.value(Right(cached));
    return _inFlight ??= _fetch();
  }

  Future<Either<Failure, List<Currency>>> _fetch() async {
    try {
      final result = await guardApi(remote.getCurrencies);
      result.fold((_) {}, (currencies) => _cached = currencies);
      return result;
    } finally {
      _inFlight = null;
    }
  }

  @override
  Future<Either<Failure, Unit>> setBaseCurrency(String currencyId) =>
      guardApi(() async {
        await remote.setBaseCurrency(currencyId);
        return unit;
      });
}
