import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/price_alert.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_remote_data_source.dart';

class AlertRepositoryImpl implements AlertRepository {
  const AlertRepositoryImpl(this.remote);

  final AlertRemoteDataSource remote;

  @override
  Future<Either<Failure, List<PriceAlert>>> getAlerts() =>
      guardApi(remote.getAlerts);

  @override
  Future<Either<Failure, PriceAlert>> createAlert({
    required String base,
    required String quote,
    required AlertCondition condition,
    required double targetRate,
  }) async {
    final result = await guardApi(
      () => remote.createAlert(
        base: base,
        quote: quote,
        condition: condition,
        targetRate: targetRate,
      ),
    );
    return result.leftMap((failure) {
      // The backend only prices alerts for pairs it collects rates for.
      if (failure is ServerFailure && failure.code == 'UNSUPPORTED_PAIR') {
        return ServerFailure(
          "Alerts for $base in $quote aren't available yet",
          statusCode: failure.statusCode,
          code: failure.code,
        );
      }
      return failure;
    });
  }

  @override
  Future<Either<Failure, PriceAlert>> updateAlert(
    String id, {
    AlertCondition? condition,
    double? targetRate,
  }) => guardApi(
    () => remote.updateAlert(id, condition: condition, targetRate: targetRate),
  );

  @override
  Future<Either<Failure, Unit>> deleteAlert(String id) => guardApi(() async {
    await remote.deleteAlert(id);
    return unit;
  });
}
