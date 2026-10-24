import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/feedback_repository.dart';

class SubmitFeedback implements UseCase<Unit, SubmitFeedbackParams> {
  const SubmitFeedback(this.repository);

  final FeedbackRepository repository;

  @override
  Future<Either<Failure, Unit>> call(SubmitFeedbackParams params) {
    final message = params.message?.trim();
    final hasMessage = message != null && message.isNotEmpty;
    if (params.rating == null && !hasMessage) {
      return Future.value(
        const Left(ValidationFailure('Add a rating or a comment first')),
      );
    }
    return repository.submit(
      rating: params.rating,
      message: hasMessage ? message : null,
    );
  }
}

class SubmitFeedbackParams extends Equatable {
  const SubmitFeedbackParams({this.rating, this.message});

  final int? rating;
  final String? message;

  @override
  List<Object?> get props => [rating, message];
}
