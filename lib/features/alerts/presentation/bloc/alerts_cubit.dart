import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/price_alert.dart';
import '../../domain/usecases/alert_usecases.dart';

enum AlertsStatus { loading, ready, loadFailed }

class AlertsState extends Equatable {
  const AlertsState({
    this.status = AlertsStatus.loading,
    this.alerts = const [],
    this.error,
  });

  final AlertsStatus status;
  final List<PriceAlert> alerts;

  /// Why the list could not be loaded.
  final String? error;

  AlertsState copyWith({
    AlertsStatus? status,
    List<PriceAlert>? alerts,
    String? Function()? error,
  }) => AlertsState(
    status: status ?? this.status,
    alerts: alerts ?? this.alerts,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, alerts, error];
}

/// The user's price alerts. Create / update / delete return the failure (if
/// any) so the editor sheet can show it inline and stay open.
class AlertsCubit extends Cubit<AlertsState> {
  AlertsCubit(
    this._getAlerts,
    this._createAlert,
    this._updateAlert,
    this._deleteAlert,
  ) : super(const AlertsState());

  final GetAlerts _getAlerts;
  final CreateAlert _createAlert;
  final UpdateAlert _updateAlert;
  final DeleteAlert _deleteAlert;

  Future<void> load() async {
    emit(state.copyWith(status: AlertsStatus.loading, error: () => null));
    final result = await _getAlerts(const NoParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: AlertsStatus.loadFailed,
          error: () => failure.message,
        ),
      ),
      (alerts) => emit(
        state.copyWith(
          status: AlertsStatus.ready,
          alerts: _newestFirst(alerts),
          error: () => null,
        ),
      ),
    );
  }

  /// Returns null on success, otherwise the failure message.
  Future<String?> create(CreateAlertParams params) async {
    final result = await _createAlert(params);
    if (isClosed) return null;
    return result.fold((failure) => failure.message, (alert) {
      emit(state.copyWith(alerts: _newestFirst([alert, ...state.alerts])));
      return null;
    });
  }

  Future<String?> update(UpdateAlertParams params) async {
    final result = await _updateAlert(params);
    if (isClosed) return null;
    return result.fold((failure) => failure.message, (updated) {
      emit(
        state.copyWith(
          alerts: [
            for (final a in state.alerts)
              if (a.id == updated.id) updated else a,
          ],
        ),
      );
      return null;
    });
  }

  Future<String?> delete(String id) async {
    final Either<Failure, Unit> result = await _deleteAlert(id);
    if (isClosed) return null;
    return result.fold((failure) => failure.message, (_) {
      emit(
        state.copyWith(
          alerts: [
            for (final a in state.alerts)
              if (a.id != id) a,
          ],
        ),
      );
      return null;
    });
  }

  static List<PriceAlert> _newestFirst(List<PriceAlert> alerts) {
    final sorted = [...alerts];
    sorted.sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null || y == null) return 0;
      return y.compareTo(x);
    });
    return sorted;
  }
}
