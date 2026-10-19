import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/domain/usecases/favorite_usecases.dart';
import '../../../profile/domain/usecases/get_profile.dart';

enum BrowseStatus { loading, ready, loadFailed }

/// The price of one asset while it loads, once it has loaded, or when it could
/// not be fetched.
class BrowseQuote extends Equatable {
  const BrowseQuote.loading() : quote = null, failed = false;
  const BrowseQuote.ready(AssetQuote this.quote) : failed = false;
  const BrowseQuote.failed() : quote = null, failed = true;

  final AssetQuote? quote;
  final bool failed;

  @override
  List<Object?> get props => [quote, failed];
}

class BrowseState extends Equatable {
  const BrowseState({
    this.status = BrowseStatus.loading,
    this.catalog = const {},
    this.quotes = const {},
    this.quoteCurrency = 'USD',
    this.error,
  });

  final BrowseStatus status;

  /// Every active asset by type.
  final Map<AssetKind, List<AssetItem>> catalog;

  /// Prices by asset id. An asset is only priced once its row is shown.
  final Map<String, BrowseQuote> quotes;

  /// The currency prices are shown in (the user's base currency).
  final String quoteCurrency;
  final String? error;

  List<AssetItem> assetsOf(AssetKind kind) => catalog[kind] ?? const [];

  BrowseState copyWith({
    BrowseStatus? status,
    Map<AssetKind, List<AssetItem>>? catalog,
    Map<String, BrowseQuote>? quotes,
    String? quoteCurrency,
    String? Function()? error,
  }) => BrowseState(
    status: status ?? this.status,
    catalog: catalog ?? this.catalog,
    quotes: quotes ?? this.quotes,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [status, catalog, quotes, quoteCurrency, error];
}

/// Loads every asset for the Browse tab and prices them in the base currency.
///
/// The list appears as soon as it loads. Prices are fetched row by row, only
/// for rows that are actually shown, so a long list does not fire hundreds of
/// requests at once.
class BrowseCubit extends Cubit<BrowseState> {
  BrowseCubit(this._getCatalog, this._getQuote, this._getProfile)
    : super(const BrowseState());

  final GetAssetCatalog _getCatalog;
  final GetAssetQuote _getQuote;
  final GetProfile _getProfile;

  /// Bumped on every load so a slow, older load or price cannot overwrite a
  /// newer one.
  int _generation = 0;

  /// [refresh] keeps the current list on screen (pull-to-refresh).
  Future<void> load({bool refresh = false}) async {
    final generation = ++_generation;
    if (!refresh || state.status != BrowseStatus.ready) {
      emit(state.copyWith(status: BrowseStatus.loading, error: () => null));
    }
    // Started together so the two requests run in parallel.
    final catalogRequest = _getCatalog(const NoParams());
    final profileRequest = _getProfile(const NoParams());
    final catalogResult = await catalogRequest;
    final profileResult = await profileRequest;
    if (isClosed || generation != _generation) return;

    final catalog = catalogResult.fold<Map<AssetKind, List<AssetItem>>?>(
      (_) => null,
      (c) => c,
    );
    if (catalog == null) {
      final message = catalogResult.fold((f) => f.message, (_) => '');
      // A failed refresh keeps what is shown; a failed first load shows the
      // error screen with Retry.
      final keep = refresh && state.catalog.isNotEmpty;
      emit(
        state.copyWith(
          status: keep ? BrowseStatus.ready : BrowseStatus.loadFailed,
          error: () => message,
        ),
      );
      return;
    }
    // Prices fall back to USD when the base currency is unknown.
    final quoteCurrency = profileResult.fold(
      (_) => 'USD',
      (p) => p.baseCurrency?.code ?? 'USD',
    );
    emit(
      state.copyWith(
        status: BrowseStatus.ready,
        catalog: catalog,
        // New prices after a reload; the old ones may be stale.
        quotes: const {},
        quoteCurrency: quoteCurrency,
        error: () => null,
      ),
    );
  }

  /// Fetches the price of [asset] unless it is already loaded or loading.
  /// Called by a row when it is first shown.
  Future<void> ensureQuote(AssetItem asset) async {
    if (state.quotes.containsKey(asset.id)) return;
    final generation = _generation;
    final currency = state.quoteCurrency;
    _setQuote(asset.id, const BrowseQuote.loading());
    final result = await _getQuote(
      AssetQuoteParams(symbol: asset.symbol, quote: currency),
    );
    if (isClosed || generation != _generation) return;
    _setQuote(
      asset.id,
      result.fold(
        (_) => const BrowseQuote.failed(),
        (quote) => BrowseQuote.ready(quote),
      ),
    );
  }

  void _setQuote(String id, BrowseQuote quote) {
    emit(state.copyWith(quotes: {...state.quotes, id: quote}));
  }
}
