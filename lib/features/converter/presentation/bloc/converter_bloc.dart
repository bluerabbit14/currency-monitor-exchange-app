import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/convert_currency.dart';
import 'converter_event.dart';
import 'converter_state.dart';

class ConverterBloc extends Bloc<ConverterEvent, ConverterState> {
  ConverterBloc({required this._convertCurrency})
    : super(const ConverterInitial()) {
    on<ConvertRequested>(_onConvertRequested);
  }

  final ConvertCurrency _convertCurrency;

  Future<void> _onConvertRequested(
    ConvertRequested event,
    Emitter<ConverterState> emit,
  ) async {
    emit(const ConverterLoading());
    final result = await _convertCurrency(
      ConvertParams(amount: event.amount, from: event.from, to: event.to),
    );
    result.fold(
      (failure) => emit(ConverterFailure(failure.message)),
      (conversion) => emit(ConverterSuccess(conversion)),
    );
  }
}
