import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/asset_item.dart';
import '../../domain/entities/price_point.dart';
import '../../domain/usecases/favorite_usecases.dart';

enum DetailChartStatus { loading, ready, failed }

class AssetDetailState extends Equatable {
  const AssetDetailState({
    required this.asset,
    required this.quoteCurrency,
    required this.isFavorite,
    this.quote,
    this.interval = ChartInterval.h1,
    this.chartStatus = DetailChartStatus.loading,
    this.history = const [],
    this.favoriteBusy = false,
    this.changed = false,
  });

  final AssetItem asset;
  final String quoteCurrency;
  final bool isFavorite;

  /// Current price and 24-hour change; null until loaded (or if it failed).
  final AssetQuote? quote;
  final ChartInterval interval;
  final DetailChartStatus chartStatus;

  /// Every stored price of the last month, oldest first.
  final List<PricePoint> history;
  final bool favoriteBusy;

  /// True once the favorite flag was flipped, so the page behind can refresh.
  final bool changed;

  /// The chart: [history] reduced to one point per [interval].
  List<PricePoint> get series => bucketPoints(history, interval.duration);

  AssetDetailState copyWith({
    bool? isFavorite,
    AssetQuote? quote,
    ChartInterval? interval,
    DetailChartStatus? chartStatus,
    List<PricePoint>? history,
    bool? favoriteBusy,
    bool? changed,
  }) => AssetDetailState(
    asset: asset,
    quoteCurrency: quoteCurrency,
    isFavorite: isFavorite ?? this.isFavorite,
    quote: quote ?? this.quote,
    interval: interval ?? this.interval,
    chartStatus: chartStatus ?? this.chartStatus,
    history: history ?? this.history,
    favoriteBusy: favoriteBusy ?? this.favoriteBusy,
    changed: changed ?? this.changed,
  );

  @override
  List<Object?> get props => [
    asset,
    quoteCurrency,
    isFavorite,
    quote,
    interval,
    chartStatus,
    history,
    favoriteBusy,
    changed,
  ];
}

/// One asset's detail page: its price, a month of history at a chosen
/// resolution, and the favorite flag.
class AssetDetailCubit extends Cubit<AssetDetailState> {
  AssetDetailCubit(
    this._getQuote,
    this._getHistory,
    this._addFavorite,
    this._removeFavorite, {
    required AssetItem asset,
    required String quoteCurrency,
    required bool isFavorite,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(
         AssetDetailState(
           asset: asset,
           quoteCurrency: quoteCurrency,
           isFavorite: isFavorite,
         ),
       );

  final GetAssetQuote _getQuote;
  final GetAssetHistory _getHistory;
  final AddFavorite _addFavorite;
  final RemoveFavorite _removeFavorite;
  final DateTime Function() _now;

  Future<void> load() async {
    emit(state.copyWith(chartStatus: DetailChartStatus.loading));
    final now = _now();
    final asset = state.asset;
    // An asset priced in itself has no pair and no history.
    final same =
        asset.symbol.toUpperCase() == state.quoteCurrency.toUpperCase();
    final quoteFuture = _getQuote(
      AssetQuoteParams(symbol: asset.symbol, quote: state.quoteCurrency),
    );
    final historyFuture = same
        ? null
        : _getHistory(
            AssetHistoryParams(
              symbol: asset.symbol,
              quote: state.quoteCurrency,
              from: now.subtract(chartWindow),
              to: now.add(const Duration(minutes: 1)),
            ),
          );
    final quote = await quoteFuture;
    if (isClosed) return;
    quote.fold((_) {}, (q) => emit(state.copyWith(quote: q)));

    if (historyFuture == null) {
      emit(state.copyWith(chartStatus: DetailChartStatus.ready, history: []));
      return;
    }
    final history = await historyFuture;
    if (isClosed) return;
    history.fold(
      (_) => emit(state.copyWith(chartStatus: DetailChartStatus.failed)),
      (points) => emit(
        state.copyWith(chartStatus: DetailChartStatus.ready, history: points),
      ),
    );
  }

  void selectInterval(ChartInterval interval) =>
      emit(state.copyWith(interval: interval));

  /// Adds or removes the favorite. Returns null on success, otherwise the
  /// failure message. Ignored while a request is in flight.
  Future<String?> toggleFavorite() async {
    if (state.favoriteBusy) return null;
    final adding = !state.isFavorite;
    emit(state.copyWith(favoriteBusy: true));
    final result = adding
        ? await _addFavorite(state.asset.id)
        : await _removeFavorite(state.asset.id);
    if (isClosed) return null;
    return result.fold(
      (failure) {
        emit(state.copyWith(favoriteBusy: false));
        return failure.message;
      },
      (_) {
        emit(
          state.copyWith(
            isFavorite: adding,
            favoriteBusy: false,
            changed: true,
          ),
        );
        return null;
      },
    );
  }
}
