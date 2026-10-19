import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../profile/domain/usecases/get_profile.dart';
import '../../domain/entities/asset_item.dart';
import '../../domain/usecases/favorite_usecases.dart';

enum FavoritesStatus { loading, ready, loadFailed }

/// A favorite and its price. While the price is loading both [quote] and
/// [quoteFailed] are unset.
class FavoriteRow extends Equatable {
  const FavoriteRow(this.asset, {this.quote, this.quoteFailed = false});

  final AssetItem asset;
  final AssetQuote? quote;
  final bool quoteFailed;

  FavoriteRow withQuote(AssetQuote quote) => FavoriteRow(asset, quote: quote);

  FavoriteRow withQuoteFailed() => FavoriteRow(asset, quoteFailed: true);

  @override
  List<Object?> get props => [asset, quote, quoteFailed];
}

class FavoritesState extends Equatable {
  const FavoritesState({
    this.status = FavoritesStatus.loading,
    this.rows = const [],
    this.quoteCurrency = 'USD',
    this.error,
  });

  final FavoritesStatus status;
  final List<FavoriteRow> rows;

  /// The currency prices are shown in (the user's base currency).
  final String quoteCurrency;
  final String? error;

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<FavoriteRow>? rows,
    String? quoteCurrency,
    String? Function()? error,
  }) => FavoritesState(
    status: status ?? this.status,
    rows: rows ?? this.rows,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, rows, quoteCurrency, error];
}

/// The user's favorite assets, each priced in their base currency.
///
/// The list appears as soon as it loads; prices fill in row by row.
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(
    this._getFavorites,
    this._addFavorite,
    this._removeFavorite,
    this._getQuote,
    this._getProfile,
  ) : super(const FavoritesState());

  final GetFavorites _getFavorites;
  final AddFavorite _addFavorite;
  final RemoveFavorite _removeFavorite;
  final GetAssetQuote _getQuote;
  final GetProfile _getProfile;

  /// Bumped on every load so a slow, older load cannot overwrite a newer one.
  int _generation = 0;

  /// [refresh] keeps the current rows on screen (pull-to-refresh).
  Future<void> load({bool refresh = false}) async {
    final generation = ++_generation;
    if (!refresh || state.status != FavoritesStatus.ready) {
      emit(state.copyWith(status: FavoritesStatus.loading, error: () => null));
    }

    // Prices are shown in the base currency; fall back to USD when it is not
    // known (profile failed, or the user has not chosen one).
    final profile = await _getProfile(const NoParams());
    final quoteCurrency = profile.fold(
      (_) => 'USD',
      (p) => p.baseCurrency?.code ?? 'USD',
    );
    final favorites = await _getFavorites(const NoParams());
    if (isClosed || generation != _generation) return;

    final loaded = favorites.fold<List<AssetItem>?>((_) => null, (a) => a);
    if (loaded == null) {
      final message = favorites.fold((f) => f.message, (_) => '');
      // A refresh that fails keeps what is already shown (and reports why);
      // a first load that fails shows the error screen.
      final keepRows = refresh && state.rows.isNotEmpty;
      emit(
        state.copyWith(
          status: keepRows ? FavoritesStatus.ready : FavoritesStatus.loadFailed,
          error: () => message,
          quoteCurrency: quoteCurrency,
        ),
      );
      return;
    }

    // Keep a price we already have while the new one loads, so a refresh does
    // not blank the screen.
    final previous = {for (final r in state.rows) r.asset.id: r};
    final rows = [
      for (final asset in loaded)
        refresh && previous[asset.id]?.quote != null
            ? FavoriteRow(asset, quote: previous[asset.id]!.quote)
            : FavoriteRow(asset),
    ];
    emit(
      state.copyWith(
        status: FavoritesStatus.ready,
        rows: rows,
        quoteCurrency: quoteCurrency,
        error: () => null,
      ),
    );
    await Future.wait([
      for (final asset in loaded) _loadQuote(asset, quoteCurrency, generation),
    ]);
  }

  Future<void> _loadQuote(
    AssetItem asset,
    String quoteCurrency,
    int generation,
  ) async {
    final result = await _getQuote(
      AssetQuoteParams(symbol: asset.symbol, quote: quoteCurrency),
    );
    if (isClosed || generation != _generation) return;
    _replaceRow(
      asset.id,
      (row) => result.fold(
        (_) => row.quote != null ? row : row.withQuoteFailed(),
        (quote) => row.withQuote(quote),
      ),
    );
  }

  void _replaceRow(String assetId, FavoriteRow Function(FavoriteRow) change) {
    emit(
      state.copyWith(
        rows: [
          for (final row in state.rows)
            if (row.asset.id == assetId) change(row) else row,
        ],
      ),
    );
  }

  /// Favorites [asset]. Returns null on success, otherwise the failure message.
  Future<String?> add(AssetItem asset) async {
    final result = await _addFavorite(asset.id);
    if (isClosed) return null;
    return result.fold((failure) => failure.message, (added) {
      if (state.rows.any((r) => r.asset.id == added.id)) return null;
      emit(state.copyWith(rows: [FavoriteRow(added), ...state.rows]));
      _loadQuote(added, state.quoteCurrency, _generation);
      return null;
    });
  }

  /// Removes the favorite on the backend. The row stays in the list until
  /// [dropRow] is called, so a swipe animation can finish first. Returns null
  /// on success, otherwise the failure message.
  Future<String?> remove(String assetId) async {
    final result = await _removeFavorite(assetId);
    return result.fold((failure) => failure.message, (_) => null);
  }

  void dropRow(String assetId) {
    if (isClosed) return;
    emit(
      state.copyWith(
        rows: [
          for (final row in state.rows)
            if (row.asset.id != assetId) row,
        ],
      ),
    );
  }
}
