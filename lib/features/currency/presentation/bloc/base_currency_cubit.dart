import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/currency.dart';
import '../../domain/usecases/get_currencies.dart';
import '../../domain/usecases/set_base_currency.dart';

enum BaseCurrencyStatus { loading, ready, loadFailed, saving, saved }

class BaseCurrencyState extends Equatable {
  const BaseCurrencyState({
    this.status = BaseCurrencyStatus.loading,
    this.currencies = const [],
    this.selected,
    this.error,
  });

  final BaseCurrencyStatus status;
  final List<Currency> currencies;
  final Currency? selected;

  /// Load failure message, or the reason saving failed (shown in a snack bar).
  final String? error;

  bool get isSaving => status == BaseCurrencyStatus.saving;

  BaseCurrencyState copyWith({
    BaseCurrencyStatus? status,
    List<Currency>? currencies,
    Currency? Function()? selected,
    String? Function()? error,
  }) => BaseCurrencyState(
    status: status ?? this.status,
    currencies: currencies ?? this.currencies,
    selected: selected != null ? selected() : this.selected,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, currencies, selected, error];
}

/// Loads the currency list and saves the user's choice.
class BaseCurrencyCubit extends Cubit<BaseCurrencyState> {
  BaseCurrencyCubit(this._getCurrencies, this._setBaseCurrency)
    : super(const BaseCurrencyState());

  final GetCurrencies _getCurrencies;
  final SetBaseCurrency _setBaseCurrency;

  Future<void> load() async {
    emit(state.copyWith(status: BaseCurrencyStatus.loading, error: () => null));
    final result = await _getCurrencies(const NoParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BaseCurrencyStatus.loadFailed,
          error: () => failure.message,
        ),
      ),
      (currencies) => emit(
        state.copyWith(
          status: BaseCurrencyStatus.ready,
          currencies: currencies,
          error: () => null,
        ),
      ),
    );
  }

  /// Shows [currency] (the already-saved choice) as selected without saving.
  void setCurrent(Currency? currency) {
    emit(state.copyWith(selected: () => currency, error: () => null));
  }

  void select(Currency currency) {
    if (state.isSaving) return;
    emit(state.copyWith(selected: () => currency, error: () => null));
  }

  /// On success the state becomes [BaseCurrencyStatus.saved].
  Future<void> save() async {
    final selected = state.selected;
    if (selected == null || state.isSaving) return;
    emit(state.copyWith(status: BaseCurrencyStatus.saving, error: () => null));
    final result = await _setBaseCurrency(selected.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BaseCurrencyStatus.ready,
          error: () => failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: BaseCurrencyStatus.saved)),
    );
  }
}
