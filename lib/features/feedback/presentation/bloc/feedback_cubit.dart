import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/submit_feedback.dart';

enum FeedbackStatus { editing, sending, sent }

class FeedbackState extends Equatable {
  const FeedbackState({
    this.status = FeedbackStatus.editing,
    this.rating,
    this.message = '',
    this.error,
  });

  final FeedbackStatus status;
  final int? rating;
  final String message;
  final String? error;

  bool get isSending => status == FeedbackStatus.sending;

  /// A rating or a non-blank comment is enough.
  bool get canSubmit => rating != null || message.trim().isNotEmpty;

  FeedbackState copyWith({
    FeedbackStatus? status,
    int? Function()? rating,
    String? message,
    String? Function()? error,
  }) => FeedbackState(
    status: status ?? this.status,
    rating: rating != null ? rating() : this.rating,
    message: message ?? this.message,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, rating, message, error];
}

/// Backs the Feedback sheet: holds the rating and comment and sends them.
class FeedbackCubit extends Cubit<FeedbackState> {
  FeedbackCubit(this._submit) : super(const FeedbackState());

  final SubmitFeedback _submit;

  /// Tapping the current star count again clears the rating.
  void setRating(int value) => emit(
    state.copyWith(
      rating: () => state.rating == value ? null : value,
      error: () => null,
    ),
  );

  void setMessage(String value) =>
      emit(state.copyWith(message: value, error: () => null));

  Future<void> submit() async {
    if (state.isSending || !state.canSubmit) return;
    emit(state.copyWith(status: FeedbackStatus.sending, error: () => null));
    final result = await _submit(
      SubmitFeedbackParams(rating: state.rating, message: state.message),
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: FeedbackStatus.editing,
          error: () => failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: FeedbackStatus.sent)),
    );
  }
}
