import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/format/number_format.dart';
import '../../../alerts/domain/usecases/alert_usecases.dart';
import '../../../alerts/presentation/widgets/alert_editor_sheet.dart';
import '../../domain/entities/asset_item.dart';
import '../../domain/entities/price_point.dart';
import '../bloc/asset_detail_cubit.dart';
import '../widgets/asset_flag.dart';
import '../widgets/price_chart.dart';

/// One asset: its price and daily move, a month of history on a chart (green
/// for a rising period, red for a falling one) at a chosen resolution, and the
/// favorite and price-alert actions.
///
/// Resolves to true when the favorite flag changed, so the page behind can
/// refresh.
class AssetDetailPage extends StatelessWidget {
  const AssetDetailPage({
    super.key,
    required this.asset,
    required this.quoteCurrency,
    required this.isFavorite,
  });

  final AssetItem asset;

  /// The currency the price is shown in (the user's base currency).
  final String quoteCurrency;
  final bool isFavorite;

  static Future<bool> open(
    BuildContext context, {
    required AssetItem asset,
    required String quoteCurrency,
    required bool isFavorite,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssetDetailPage(
          asset: asset,
          quoteCurrency: quoteCurrency,
          isFavorite: isFavorite,
        ),
      ),
    );
    return changed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AssetDetailCubit(
        sl(),
        sl(),
        sl(),
        sl(),
        asset: asset,
        quoteCurrency: quoteCurrency,
        isFavorite: isFavorite,
      )..load(),
      child: const _DetailView(),
    );
  }
}

const _background = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _blue = Color(0xFF0A84FF);
const _pink = Color(0xFFFF2D55);

class _DetailView extends StatelessWidget {
  const _DetailView();

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final cubit = context.read<AssetDetailCubit>();
    final adding = !cubit.state.isFavorite;
    final error = await cubit.toggleFavorite();
    if (!context.mounted) return;
    _snack(
      context,
      error != null
          ? "Couldn't update favorites. $error"
          : adding
          ? 'Added to Favorites'
          : 'Removed from Favorites',
    );
  }

  Future<void> _setAlert(BuildContext context) async {
    final state = context.read<AssetDetailCubit>().state;
    final asset = state.asset;
    final quote = state.quoteCurrency;
    if (asset.symbol.toUpperCase() == quote.toUpperCase()) {
      _snack(
        context,
        "This is your base currency, so it can't have a price alert",
      );
      return;
    }
    final created = await showAlertEditorSheet(
      context,
      quote: quote,
      fixedBase: asset.symbol,
      fixedName: asset.name,
      fixedKind: asset.kind,
      onSubmit: (base, condition, rate) async {
        final result = await sl<CreateAlert>()(
          CreateAlertParams(
            base: base,
            quote: quote,
            condition: condition,
            targetRate: rate,
          ),
        );
        return result.fold((failure) => failure.message, (_) => null);
      },
    );
    if (created && context.mounted) {
      _snack(context, 'Alert set for ${asset.symbol}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssetDetailCubit, AssetDetailState>(
      builder: (context, state) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(state.changed);
        },
        child: Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopBar(
                        state: state,
                        onBack: () => Navigator.of(context).pop(state.changed),
                        onFavorite: () => _toggleFavorite(context),
                      ),
                      const SizedBox(height: 20),
                      _Identity(asset: state.asset),
                      const SizedBox(height: 24),
                      _PriceBlock(state: state),
                      const SizedBox(height: 20),
                      _IntervalTabs(
                        selected: state.interval,
                        onSelected: context
                            .read<AssetDetailCubit>()
                            .selectInterval,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(height: 280, child: _Chart(state: state)),
                      const SizedBox(height: 16),
                      _HighLow(state: state),
                      const SizedBox(height: 24),
                      _AlertButton(onPressed: () => _setAlert(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.onBack,
    required this.onFavorite,
  });

  final AssetDetailState state;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Text(
              state.asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _RoundButton(
              icon: Icons.chevron_left_rounded,
              iconSize: 30,
              onTap: onBack,
              tooltip: 'Back',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _RoundButton(
              icon: state.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _pink,
              onTap: state.favoriteBusy ? null : onFavorite,
              tooltip: state.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
    this.iconSize = 26,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x22000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 52,
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.asset});

  final AssetItem asset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AssetFlag(asset: asset, width: 48),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            asset.symbol,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, color: _muted),
          ),
        ),
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.state});

  final AssetDetailState state;

  @override
  Widget build(BuildContext context) {
    final quote = state.quote;
    if (quote == null) {
      return const SizedBox(
        height: 96,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('···', style: TextStyle(fontSize: 44, color: _muted)),
        ),
      );
    }
    final change = quote.change;
    final moved = change != null && formatPrice(change.abs()) != '0.00';
    final color = moved && change < 0 ? bearishColor : bullishColor;
    // Percent against the price a day ago (rate - change).
    final before = change == null ? null : quote.rate - change;
    final percent = before == null || before == 0
        ? null
        : change! / before * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(quote.rate, state.quoteCurrency),
            maxLines: 1,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Text(
                formatMoneyChange(change, state.quoteCurrency),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              if (percent != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _IntervalTabs extends StatelessWidget {
  const _IntervalTabs({required this.selected, required this.onSelected});

  final ChartInterval selected;
  final ValueChanged<ChartInterval> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4EA),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (final interval in ChartInterval.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(interval),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: interval == selected
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    interval.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: interval == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.state});

  final AssetDetailState state;

  @override
  Widget build(BuildContext context) {
    switch (state.chartStatus) {
      case DetailChartStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DetailChartStatus.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Failed to load chart',
                style: TextStyle(fontSize: 18, color: _muted),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: context.read<AssetDetailCubit>().load,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case DetailChartStatus.ready:
        final series = state.series;
        if (series.isEmpty) {
          return const Center(
            child: Text(
              'No price history yet',
              style: TextStyle(fontSize: 18, color: _muted),
            ),
          );
        }
        final longSpan = state.interval.duration >= const Duration(days: 1);
        final timeFormat = longSpan
            ? DateFormat('d MMM')
            : DateFormat('d MMM, HH:mm');
        return PriceChart(
          series: series,
          formatValue: (v) => formatMoney(v, state.quoteCurrency),
          formatTime: (t) => timeFormat.format(t.toLocal()),
        );
    }
  }
}

class _HighLow extends StatelessWidget {
  const _HighLow({required this.state});

  final AssetDetailState state;

  @override
  Widget build(BuildContext context) {
    final series = state.series;
    final hasData =
        state.chartStatus == DetailChartStatus.ready && series.isNotEmpty;
    final high = hasData
        ? series.map((p) => p.rate).reduce((a, b) => a > b ? a : b)
        : null;
    final low = hasData
        ? series.map((p) => p.rate).reduce((a, b) => a < b ? a : b)
        : null;
    String text(double? v) =>
        v == null ? '—' : formatMoney(v, state.quoteCurrency);
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'High', value: text(high)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(label: 'Low', value: text(low)),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: _muted)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: const Icon(Icons.notifications_active_outlined, size: 26),
        label: const Text(
          'Set Price Alert',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
