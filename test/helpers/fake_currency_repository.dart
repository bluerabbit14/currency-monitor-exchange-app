import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/currency/domain/entities/currency.dart';
import 'package:currency/features/currency/domain/repositories/currency_repository.dart';
import 'package:dartz/dartz.dart';

const usd = Currency(id: 'id-usd', code: 'USD', name: 'US Dollar');
const eur = Currency(id: 'id-eur', code: 'EUR', name: 'Euro');
const inr = Currency(id: 'id-inr', code: 'INR', name: 'Indian Rupee');

class FakeCurrencyRepository implements CurrencyRepository {
  Either<Failure, List<Currency>> list = const Right([usd, eur, inr]);
  Either<Failure, Unit> saveResult = const Right(unit);
  int loads = 0;
  final saved = <String>[];

  @override
  Future<Either<Failure, List<Currency>>> getCurrencies() async {
    loads++;
    return list;
  }

  @override
  Future<Either<Failure, Unit>> setBaseCurrency(String currencyId) async {
    saved.add(currencyId);
    return saveResult;
  }
}

/// Replaces the network-backed currency repository registered by `init()`.
Future<FakeCurrencyRepository> useFakeCurrencyRepository() async {
  final fake = FakeCurrencyRepository();
  await sl.unregister<CurrencyRepository>();
  sl.registerLazySingleton<CurrencyRepository>(() => fake);
  return fake;
}
