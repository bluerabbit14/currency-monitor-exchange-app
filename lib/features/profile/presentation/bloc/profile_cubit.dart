import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../currency/domain/entities/currency.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/get_profile.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}

class ProfileError extends ProfileState {
  const ProfileError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._getProfile) : super(const ProfileLoading());

  final GetProfile _getProfile;

  /// The user saved a new base currency: reflect it without refetching.
  void baseCurrencyChanged(Currency currency) {
    final current = state;
    if (current is ProfileLoaded) {
      emit(ProfileLoaded(current.profile.withBaseCurrency(currency)));
    }
  }

  /// The user changed the push setting: reflect it without refetching.
  void notificationsChanged(bool enabled) {
    final current = state;
    if (current is ProfileLoaded) {
      emit(ProfileLoaded(current.profile.withNotificationsEnabled(enabled)));
    }
  }

  Future<void> load() async {
    if (state is! ProfileLoading) emit(const ProfileLoading());
    final result = await _getProfile(const NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => ProfileError(failure.message),
        (profile) => ProfileLoaded(profile),
      ),
    );
  }
}
