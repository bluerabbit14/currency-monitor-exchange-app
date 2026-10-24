import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/push/push_token_provider.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/notification_usecases.dart';

enum NotificationsStatus { loading, ready, loadFailed }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.loading,
    this.pushEnabled = false,
    this.isUpdating = false,
    this.error,
  });

  final NotificationsStatus status;
  final bool pushEnabled;

  /// A change is in flight; the switch is locked meanwhile.
  final bool isUpdating;
  final String? error;

  NotificationsState copyWith({
    NotificationsStatus? status,
    bool? pushEnabled,
    bool? isUpdating,
    String? Function()? error,
  }) => NotificationsState(
    status: status ?? this.status,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    isUpdating: isUpdating ?? this.isUpdating,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, pushEnabled, isUpdating, error];
}

/// Backs the Notifications sheet: loads the preferences and toggles push.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._getPreferences,
    this._setPushEnabled,
    this._registerDevice,
    this._tokens,
  ) : super(const NotificationsState());

  final GetNotificationPreferences _getPreferences;
  final SetPushEnabled _setPushEnabled;
  final RegisterDevice _registerDevice;
  final PushTokenProvider _tokens;

  /// Starts from the value the profile already carries (when known), so the
  /// switch is right immediately; [load] then confirms it with the backend.
  void seed(bool? pushEnabled) {
    if (pushEnabled != null) {
      emit(
        state.copyWith(
          status: NotificationsStatus.ready,
          pushEnabled: pushEnabled,
        ),
      );
    }
  }

  Future<void> load() async {
    final hadValue = state.status == NotificationsStatus.ready;
    if (!hadValue) {
      emit(
        state.copyWith(status: NotificationsStatus.loading, error: () => null),
      );
    }
    final result = await _getPreferences(const NoParams());
    if (isClosed) return;
    result.fold(
      (failure) {
        // A seeded switch stays usable; only a cold failure blocks the sheet.
        if (!hadValue) {
          emit(
            state.copyWith(
              status: NotificationsStatus.loadFailed,
              error: () => failure.message,
            ),
          );
        }
      },
      (prefs) => emit(
        state.copyWith(
          status: NotificationsStatus.ready,
          pushEnabled: prefs.pushEnabled,
          error: () => null,
        ),
      ),
    );
  }

  Future<void> setPush(bool enabled) async {
    if (state.isUpdating || enabled == state.pushEnabled) return;
    final previous = state.pushEnabled;
    if (enabled && !await _tokens.requestPermission()) {
      if (isClosed) return;
      emit(
        state.copyWith(
          error: () => 'Allow notifications for MoneyEx in your phone settings to turn this on.',
        ),
      );
      return;
    }
    if (isClosed) return;
    // Optimistic: the switch moves at once and goes back if the save fails.
    emit(
      state.copyWith(pushEnabled: enabled, isUpdating: true, error: () => null),
    );
    final result = await _setPushEnabled(enabled);
    if (isClosed) return;
    var error = result.fold<String?>((failure) => failure.message, (_) => null);
    if (result.isLeft()) {
      emit(
        state.copyWith(
          pushEnabled: previous,
          isUpdating: false,
          error: () => error,
        ),
      );
      return;
    }
    if (enabled) error = await _registerThisDevice();
    if (isClosed) return;
    emit(state.copyWith(isUpdating: false, error: () => error));
  }

  /// Registers the device when a push token exists; no token (Firebase not set
  /// up, or not Android) is not an error. Returns a message on failure.
  Future<String?> _registerThisDevice() async {
    final token = await _tokens.fcmToken();
    if (token == null || token.isEmpty) return null;
    final result = await _registerDevice(RegisterDeviceParams(fcmToken: token));
    return result.fold(
      (failure) =>
          "Notifications are on, but this device couldn't be registered. ${failure.message}",
      (_) => null,
    );
  }
}
