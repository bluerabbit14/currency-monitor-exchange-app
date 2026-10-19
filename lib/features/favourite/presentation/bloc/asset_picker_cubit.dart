import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/asset_item.dart';
import '../../domain/usecases/favorite_usecases.dart';

enum AssetPickerStatus { loading, ready, loadFailed }

class AssetPickerState extends Equatable {
  const AssetPickerState({
    this.status = AssetPickerStatus.loading,
    this.catalog = const {},
    this.pending = const {},
    this.changed = false,
    this.error,
  });

  final AssetPickerStatus status;

  /// Every active asset by type, each flagged when it is a favorite.
  final Map<AssetKind, List<AssetItem>> catalog;

  /// Ids whose add/remove request is in flight.
  final Set<String> pending;

  /// True once any favorite was added or removed, so the page behind the
  /// sheet knows to refresh.
  final bool changed;
  final String? error;

  List<AssetItem> assetsOf(AssetKind kind) => catalog[kind] ?? const [];

  AssetPickerState copyWith({
    AssetPickerStatus? status,
    Map<AssetKind, List<AssetItem>>? catalog,
    Set<String>? pending,
    bool? changed,
    String? Function()? error,
  }) => AssetPickerState(
    status: status ?? this.status,
    catalog: catalog ?? this.catalog,
    pending: pending ?? this.pending,
    changed: changed ?? this.changed,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, catalog, pending, changed, error];
}

/// Loads the asset catalog for the "Add to Favorites" sheet and toggles
/// favorites straight from it.
class AssetPickerCubit extends Cubit<AssetPickerState> {
  AssetPickerCubit(this._getCatalog, this._addFavorite, this._removeFavorite)
    : super(const AssetPickerState());

  final GetAssetCatalog _getCatalog;
  final AddFavorite _addFavorite;
  final RemoveFavorite _removeFavorite;

  Future<void> load() async {
    emit(const AssetPickerState());
    final result = await _getCatalog(const NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => AssetPickerState(
          status: AssetPickerStatus.loadFailed,
          error: failure.message,
        ),
        (catalog) =>
            AssetPickerState(status: AssetPickerStatus.ready, catalog: catalog),
      ),
    );
  }

  /// Flips the favorite flag at once and confirms with the backend; the flag
  /// is put back if the request fails. Returns null on success, otherwise the
  /// failure message. Ignored while that asset's request is in flight.
  Future<String?> toggle(AssetItem asset) async {
    if (state.pending.contains(asset.id)) return null;
    final wanted = !asset.isFavorite;
    emit(
      state.copyWith(
        catalog: _withFavorite(asset, wanted),
        pending: {...state.pending, asset.id},
      ),
    );
    final result = wanted
        ? (await _addFavorite(asset.id)).map((_) => null)
        : (await _removeFavorite(asset.id)).map((_) => null);
    if (isClosed) return null;
    final failure = result.fold((f) => f.message, (_) => null);
    emit(
      state.copyWith(
        catalog: failure == null ? null : _withFavorite(asset, !wanted),
        pending: {...state.pending}..remove(asset.id),
        changed: failure == null ? true : state.changed,
      ),
    );
    return failure;
  }

  Map<AssetKind, List<AssetItem>> _withFavorite(AssetItem asset, bool value) =>
      {
        for (final entry in state.catalog.entries)
          entry.key: [
            for (final a in entry.value)
              if (a.id == asset.id) a.copyWith(isFavorite: value) else a,
          ],
      };
}
