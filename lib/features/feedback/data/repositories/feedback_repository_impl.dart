import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../datasources/feedback_remote_data_source.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  const FeedbackRepositoryImpl(this.remote);

  final FeedbackRemoteDataSource remote;

  @override
  Future<Either<Failure, Unit>> submit({int? rating, String? message}) =>
      guardApi(() async {
        await remote.submit(rating: rating, message: message);
        return unit;
      });
}
