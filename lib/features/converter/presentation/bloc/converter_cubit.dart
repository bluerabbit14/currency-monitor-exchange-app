import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/domain/usecases/favorite_usecases.dart';
import '../../../profile/domain/usecases/get_profile.dart';
import '../../domain/entities/conversion.dart';
import '../../domain/expression_input.dart';
import '../../domain/repositories/converter_repository.dart';

enum ConverterStatus { loading, ready }

class ConverterState extends Equatable {
  const ConverterState({
    this.status = ConverterStatus.loading,
    this.assets = const [],
    this.activeSymbol,
    this.expression = '',
    this.rates = const {},
    this.failed = const {},
    this.fetching = false,
    this.updatedAt,
    this.error,
  });

  final ConverterStatus status;
  final List<AssetItem> assets;

  /// The row typed into; every other row is converted from it.
  final String? activeSymbol;

  /// What was typed, e.g. `12+3×2` (the active row shows it as is).
  final String expression;

  /// Price of one active-row unit in each other row's asset, by symbol.
  final Map<String, double> rates;

  /// Symbols whose rate could not be fetched (shown as "-").
  final Set<String> failed;
  final bool fetching;

  /// The oldest refresh time among the rates on screen.
  final DateTime? updatedAt;
  final String? error;

  /// The typed amount; null when nothing valid is typed yet.
  double? get amount => evaluateExpression(expression);

  /// What [symbol]'s row shows as a number, or null when it cannot be known
  /// (no amount typed is treated as 0 by the page, not here).
  double? convertedValue(String symbol) {
    final value = amount ?? 0;
    if (symbol == activeSymbol) return value;
    final rate = rates[symbol];
    return rate == null ? null : value * rate;
  }

  ConverterState copyWith({
    ConverterStatus? status,
    List<AssetItem>? assets,
    String? Function()? activeSymbol,
    String? expression,
    Map<String, double>? rates,
    Set<String>? failed,
    bool? fetching,
    DateTime? Function()? updatedAt,
    String? Function()? error,
  }) => ConverterState(
    status: status ?? this.status,
    assets: assets ?? this.assets,
    activeSymbol: activeSymbol != null ? activeSymbol() : this.activeSymbol,
    expression: expression ?? this.expression,
    rates: rates ?? this.rates,
    failed: failed ?? this.failed,
    fetching: fetching ?? this.fetching,
    updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [
    status,
    assets,
    activeSymbol,
    expression,
    rates,
    failed,
    fetching,
    updatedAt,
    error,
  ];
}

class ConverterCubit extends Cubit<ConverterState> {
  ConverterCubit(this._repository, this._getCatalog, this._getProfile)
    : super(const ConverterState());

  final ConverterRepository _repository;
  final GetAssetCatalog _getCatalog;
  final GetProfile _getProfile;

  /// Bumped on every rate fetch so a slow, older one cannot overwrite a newer.
  int _generation = 0;

  /// Currencies a first launch starts with, after the user's base currency.
  static const _defaultSymbols = ['USD', 'EUR'];

  Future<void> load() async {
    final saved = await _repository.loadSession();
    if (isClosed) return;
    if (saved != null) {
      emit(_ready(saved.assets, saved.activeSymbol, saved.expression));
      await _refreshRates();
      return;
    }
    final defaults = await _defaultAssets();
    if (isClosed) return;
    emit(_ready(defaults, null, ''));
    await _persist();
    await _refreshRates();
  }

  /// A key of the keypad was pressed.
  void keyPressed(String key) {
    if (state.activeSymbol == null) return;
    var expression = state.expression;
    if (key == Keys.equals) {
      final result = state.amount;
      if (result == null) return;
      expression = plainNumber(result);
    } else {
      expression = applyKey(expression, key);
    }
    if (expression == state.expression) return;
    emit(state.copyWith(expression: expression));
    _persist();
  }

  /// Makes [symbol]'s row the one typed into, carrying the amount over in that
  /// row's own currency.
  Future<void> selectActive(String symbol) async {
    if (symbol == state.activeSymbol) return;
    if (!state.assets.any((a) => a.symbol == symbol)) return;
    final carried = state.expression.isEmpty
        ? null
        : state.convertedValue(symbol);
    emit(
      state.copyWith(
        activeSymbol: () => symbol,
        expression: carried == null ? '' : plainNumber(carried),
        rates: const {},
        failed: const {},
        updatedAt: () => null,
      ),
    );
    _persist();
    await _refreshRates();
  }

  /// Replaces the list with [selected]: rows already there keep their place,
  /// new ones go to the end, unticked ones go away.
  Future<void> setAssets(List<AssetItem> selected) async {
    final ids = {for (final a in selected) a.id};
    final kept = [
      for (final a in state.assets)
        if (ids.contains(a.id)) a,
    ];
    final keptIds = {for (final a in kept) a.id};
    final added = [
      for (final a in selected)
        if (!keptIds.contains(a.id)) a,
    ];
    await _setList([...kept, ...added]);
  }

  Future<void> remove(String symbol) => _setList([
    for (final a in state.assets)
      if (a.symbol != symbol) a,
  ]);

  /// Empties the whole list.
  Future<void> clear() => _setList(const []);

  /// Pull-to-refresh: refetches every rate.
  Future<void> refresh() => _refreshRates(refresh: true);

  Future<void> _setList(List<AssetItem> assets) async {
    final stillActive = assets.any((a) => a.symbol == state.activeSymbol);
    final active = stillActive
        ? state.activeSymbol
        : (assets.isEmpty ? null : assets.first.symbol);
    final baseChanged = active != state.activeSymbol;
    emit(
      state.copyWith(
        assets: assets,
        activeSymbol: () => active,
        expression: active == null || baseChanged ? '' : state.expression,
        rates: baseChanged ? const {} : state.rates,
        failed: baseChanged ? const {} : state.failed,
        updatedAt: () => baseChanged ? null : state.updatedAt,
      ),
    );
    _persist();
    await _refreshRates();
  }

  ConverterState _ready(
    List<AssetItem> assets,
    String? activeSymbol,
    String expression,
  ) {
    final active = assets.any((a) => a.symbol == activeSymbol)
        ? activeSymbol
        : (assets.isEmpty ? null : assets.first.symbol);
    return ConverterState(
      status: ConverterStatus.ready,
      assets: assets,
      activeSymbol: active,
      expression: expression,
    );
  }

  /// The user's base currency, then USD and EUR, taken from the catalog.
  Future<List<AssetItem>> _defaultAssets() async {
    final catalog = await _getCatalog(const NoParams());
    final fiat = catalog.fold<List<AssetItem>>(
      (_) => const [],
      (c) => c[AssetKind.fiat] ?? const [],
    );
    if (fiat.isEmpty) return const [];
    final profile = await _getProfile(const NoParams());
    final base = profile.fold<String?>(
      (_) => null,
      (p) => p.baseCurrency?.code,
    );
    final wanted = <String>{?base, ..._defaultSymbols};
    return [
      for (final symbol in wanted)
        for (final asset in fiat)
          if (asset.symbol == symbol) asset,
    ];
  }

  Future<void> _refreshRates({bool refresh = false}) async {
    final generation = ++_generation;
    final base = state.activeSymbol;
    if (base == null) {
      emit(
        state.copyWith(
          rates: const {},
          failed: const {},
          fetching: false,
          updatedAt: () => null,
        ),
      );
      return;
    }
    final targets = [
      for (final a in state.assets)
        if (a.symbol != base) a.symbol,
    ];
    if (targets.isEmpty) {
      emit(state.copyWith(fetching: false, updatedAt: () => null));
      return;
    }
    emit(state.copyWith(fetching: true, error: () => null));
    final results = await Future.wait([
      for (final symbol in targets)
        _repository.getRate(from: base, to: symbol, refresh: refresh),
    ]);
    if (isClosed || generation != _generation) return;

    final rates = <String, double>{};
    final failed = <String>{};
    DateTime? oldest;
    String? error;
    for (var i = 0; i < targets.length; i++) {
      results[i].fold(
        (failure) {
          failed.add(targets[i]);
          error ??= failure.message;
        },
        (rate) {
          rates[targets[i]] = rate.rate;
          final at = rate.fetchedAt;
          if (at != null && (oldest == null || at.isBefore(oldest!))) {
            oldest = at;
          }
        },
      );
    }
    emit(
      state.copyWith(
        rates: rates,
        failed: failed,
        fetching: false,
        updatedAt: () => oldest,
        error: () => error,
      ),
    );
  }

  Future<void> _persist() => _repository.saveSession(
    ConverterSession(
      assets: state.assets,
      activeSymbol: state.activeSymbol,
      expression: state.expression,
    ),
  );
}
