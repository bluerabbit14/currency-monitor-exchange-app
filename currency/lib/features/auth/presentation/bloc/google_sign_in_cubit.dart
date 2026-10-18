import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/google_sign_in_data_source.dart';

sealed class GoogleSignInState extends Equatable {
  const GoogleSignInState();

  @override
  List<Object?> get props => [];
}

class GoogleSignInIdle extends GoogleSignInState {
  const GoogleSignInIdle();
}

class GoogleSignInLoading extends GoogleSignInState {
  const GoogleSignInLoading();
}

/// Google returned an ID token. Backend verification is still pending, so the
/// user is NOT logged in at this point.
class GoogleSignInTokenReceived extends GoogleSignInState {
  const GoogleSignInTokenReceived(this.idToken);

  final String idToken;

  @override
  List<Object?> get props => [idToken];
}

class GoogleSignInError extends GoogleSignInState {
  const GoogleSignInError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class GoogleSignInCubit extends Cubit<GoogleSignInState> {
  GoogleSignInCubit(this._dataSource) : super(const GoogleSignInIdle());

  final GoogleSignInDataSource _dataSource;

  Future<void> signIn() async {
    if (state is GoogleSignInLoading) return; // ignore repeated taps
    emit(const GoogleSignInLoading());
    final result = await _dataSource.signIn();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        failure is GoogleSignInCancelledFailure
            ? const GoogleSignInIdle()
            : GoogleSignInError(failure.message),
      ),
      (ok) => emit(GoogleSignInTokenReceived(ok.idToken)),
    );
  }
}
