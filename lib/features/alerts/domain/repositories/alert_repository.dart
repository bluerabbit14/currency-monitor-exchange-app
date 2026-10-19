import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/price_alert.dart';

abstract class AlertRepository {
  /// The signed-in user's alerts (newest page of up to 100).
  Future<Either<Failure, List<PriceAlert>>> getAlerts();

  /// Creates an alert for [base] priced in [quote]. Fails with a clear message
  /// when the backend has no such pair configured.
  Future<Either<Failure, PriceAlert>> createAlert({
    required String base,
    required String quote,
    required AlertCondition condition,
    required double targetRate,
  });

  /// Changes the condition and/or target; the pair cannot be changed.
  Future<Either<Failure, PriceAlert>> updateAlert(
    String id, {
    AlertCondition? condition,
    double? targetRate,
  });

  Future<Either<Failure, Unit>> deleteAlert(String id);
}
