import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/price_alert.dart';
import '../repositories/alert_repository.dart';

class GetAlerts implements UseCase<List<PriceAlert>, NoParams> {
  const GetAlerts(this.repository);

  final AlertRepository repository;

  @override
  Future<Either<Failure, List<PriceAlert>>> call(NoParams params) =>
      repository.getAlerts();
}

class CreateAlert implements UseCase<PriceAlert, CreateAlertParams> {
  const CreateAlert(this.repository);

  final AlertRepository repository;

  @override
  Future<Either<Failure, PriceAlert>> call(CreateAlertParams params) =>
      repository.createAlert(
        base: params.base,
        quote: params.quote,
        condition: params.condition,
        targetRate: params.targetRate,
      );
}

class CreateAlertParams extends Equatable {
  const CreateAlertParams({
    required this.base,
    required this.quote,
    required this.condition,
    required this.targetRate,
  });

  final String base;
  final String quote;
  final AlertCondition condition;
  final double targetRate;

  @override
  List<Object?> get props => [base, quote, condition, targetRate];
}

class UpdateAlert implements UseCase<PriceAlert, UpdateAlertParams> {
  const UpdateAlert(this.repository);

  final AlertRepository repository;

  @override
  Future<Either<Failure, PriceAlert>> call(UpdateAlertParams params) =>
      repository.updateAlert(
        params.id,
        condition: params.condition,
        targetRate: params.targetRate,
      );
}

class UpdateAlertParams extends Equatable {
  const UpdateAlertParams({required this.id, this.condition, this.targetRate});

  final String id;
  final AlertCondition? condition;
  final double? targetRate;

  @override
  List<Object?> get props => [id, condition, targetRate];
}

class DeleteAlert implements UseCase<Unit, String> {
  const DeleteAlert(this.repository);

  final AlertRepository repository;

  /// [params] is the alert id.
  @override
  Future<Either<Failure, Unit>> call(String params) =>
      repository.deleteAlert(params);
}
