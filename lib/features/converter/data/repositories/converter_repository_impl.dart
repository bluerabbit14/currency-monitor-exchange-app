import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/conversion.dart';
import '../../domain/repositories/converter_repository.dart';
import '../datasources/converter_local_data_source.dart';

class ConverterRepositoryImpl implements ConverterRepository {
  const ConverterRepositoryImpl(this.localDataSource);

  final ConverterLocalDataSource localDataSource;

  @override
  Future<Either<Failure, Conversion>> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    try {
      return Right(localDataSource.convert(amount: amount, from: from, to: to));
    } on ConversionException catch (error) {
      return Left(ConversionFailure(error.message));
    }
  }
}
