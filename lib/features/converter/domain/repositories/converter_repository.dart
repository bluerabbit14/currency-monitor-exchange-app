import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/conversion.dart';

abstract class ConverterRepository {
  /// Price of one [from] in [to]. A recent answer is reused unless [refresh].
  Future<Either<Failure, ConverterRate>> getRate({
    required String from,
    required String to,
    bool refresh = false,
  });

  /// The saved rows, or null on a first launch.
  Future<ConverterSession?> loadSession();

  Future<void> saveSession(ConverterSession session);
}
