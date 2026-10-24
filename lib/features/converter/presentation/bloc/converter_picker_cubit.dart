import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/domain/usecases/favorite_usecases.dart';

enum ConverterPickerStatus { loading, ready, loadFailed }

class ConverterPickerState extends Equatable {
  const ConverterPickerState({
    this.status = ConverterPickerStatus.loading,
    this.catalog = const {},
    this.selected = const {},
    this.error,
  });

  final ConverterPickerStatus status;
  final Map<AssetKind, List<AssetItem>> catalog;

  /// The assets ticked, by id. Nothing is saved until the page is closed.
  final Map<String, AssetItem> selected;
  final String? error;

  List<AssetItem> assetsOf(AssetKind kind) => catalog[kind] ?? const [];

  @override
  List<Object?> get props => [status, catalog, selected, error];
}

/// Loads the asset catalog for the Add Currency page and keeps which assets
/// are ticked in memory.
class ConverterPickerCubit extends Cubit<ConverterPickerState> {
  ConverterPickerCubit(this._getCatalog, List<AssetItem> initial)
    : super(ConverterPickerState(selected: {for (final a in initial) a.id: a}));

  final GetAssetCatalog _getCatalog;

  Future<void> load() async {
    emit(ConverterPickerState(selected: state.selected));
    final result = await _getCatalog(const NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => ConverterPickerState(
          status: ConverterPickerStatus.loadFailed,
          selected: state.selected,
          error: failure.message,
        ),
        (catalog) => ConverterPickerState(
          status: ConverterPickerStatus.ready,
          catalog: catalog,
          selected: state.selected,
        ),
      ),
    );
  }

  void toggle(AssetItem asset) {
    final selected = {...state.selected};
    if (selected.remove(asset.id) == null) selected[asset.id] = asset;
    emit(
      ConverterPickerState(
        status: state.status,
        catalog: state.catalog,
        selected: selected,
        error: state.error,
      ),
    );
  }
}
