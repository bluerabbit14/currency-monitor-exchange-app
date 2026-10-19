import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/asset_item.dart';
import '../../domain/usecases/favorite_usecases.dart';

enum AssetPickerStatus { loading, ready, loadFailed }

class AssetPickerState extends Equatable {
  const AssetPickerState({
    this.status = AssetPickerStatus.loading,
    this.assets = const [],
    this.error,
  });

  final AssetPickerStatus status;
  final List<AssetItem> assets;
  final String? error;

  @override
  List<Object?> get props => [status, assets, error];
}

/// Loads the asset catalog for the "add favorite" sheet.
class AssetPickerCubit extends Cubit<AssetPickerState> {
  AssetPickerCubit(this._getAssets) : super(const AssetPickerState());

  final GetAssets _getAssets;

  Future<void> load() async {
    emit(const AssetPickerState());
    final result = await _getAssets(const NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => AssetPickerState(
          status: AssetPickerStatus.loadFailed,
          error: failure.message,
        ),
        (assets) =>
            AssetPickerState(status: AssetPickerStatus.ready, assets: assets),
      ),
    );
  }
}
