import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

abstract class FeedbackRepository {
  /// Sends a 1 to 5 [rating], a [message], or both.
  Future<Either<Failure, Unit>> submit({int? rating, String? message});
}
