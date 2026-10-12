import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/conversion.dart';

abstract class ConverterRepository {
  Future<Either<Failure, Conversion>> convert({
    required double amount,
    required String from,
    required String to,
  });
}
