import 'package:currency/core/error/failures.dart';
import 'package:currency/features/converter/domain/entities/conversion.dart';
import 'package:currency/features/converter/domain/repositories/converter_repository.dart';
import 'package:currency/features/converter/domain/usecases/convert_currency.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConverterRepository implements ConverterRepository {
  _FakeConverterRepository({this.failure});

  final Failure? failure;

  @override
  Future<Either<Failure, Conversion>> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    final failure = this.failure;
    if (failure != null) {
      return Left(failure);
    }

    return Right(
      Conversion(amount: amount, from: from, to: to, result: amount * 2),
    );
  }
}

void main() {
  const params = ConvertParams(amount: 10, from: 'USD', to: 'EUR');

  test('returns a conversion when the repository succeeds', () async {
    final useCase = ConvertCurrency(_FakeConverterRepository());

    final result = await useCase(params);

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected a conversion'), (conversion) {
      expect(conversion.result, 20);
      expect(conversion.from, 'USD');
      expect(conversion.to, 'EUR');
    });
  });

  test('returns a failure when the repository fails', () async {
    const failure = ConversionFailure('Unsupported currency');
    final useCase = ConvertCurrency(_FakeConverterRepository(failure: failure));

    final result = await useCase(params);

    expect(result, const Left<Failure, Conversion>(failure));
  });
}
