import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../currency/domain/entities/currency.dart';
import '../../domain/entities/price_alert.dart';
import '../../domain/usecases/alert_usecases.dart';
import '../bloc/alerts_cubit.dart';
import '../widgets/alert_editor_sheet.dart';

/// The user's price alerts: list, create, edit and delete.
///
/// [baseCurrency] is the user's base currency; targets are priced in it. It can
/// be null (not chosen yet), in which case alerts cannot be created.
class PriceAlertsPage extends StatelessWidget {
  const PriceAlertsPage({super.key, required this.baseCurrency});

  final Currency? baseCurrency;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AlertsCubit>()..load(),
      child: _AlertsView(baseCurrency: baseCurrency),
    );
  }
}

const _background = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _blue = Color(0xFF1E88FF);

class _AlertsView extends StatelessWidget {
  const _AlertsView({required this.baseCurrency});

  final Currency? baseCurrency;

  Future<void> _add(BuildContext context) async {
    final quote = baseCurrency?.code;
    if (quote == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Choose your currency in Settings to add alerts'),
          ),
        );
      return;
    }
    final cubit = context.read<AlertsCubit>();
    await showAlertEditorSheet(
      context,
      quote: quote,
      onSubmit: (base, condition, rate) => cubit.create(
        CreateAlertParams(
          base: base,
          quote: quote,
          condition: condition,
          targetRate: rate,
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, PriceAlert alert) async {
    final cubit = context.read<AlertsCubit>();
    await showAlertEditorSheet(
      context,
      quote: alert.quote,
      existing: alert,
      onSubmit: (base, condition, rate) => cubit.update(
        UpdateAlertParams(
          id: alert.id,
          condition: condition == alert.condition ? null : condition,
          targetRate: rate == alert.targetRate ? null : rate,
        ),
      ),
      onDelete: () => cubit.delete(alert.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: BlocBuilder<AlertsCubit, AlertsState>(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const _BackButton(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(2, 16, 2, 24),
                  child: Text(
                    'Price Alerts',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                ),
                ..._content(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, AlertsState state) {
    switch (state.status) {
      case AlertsStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case AlertsStatus.loadFailed:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Text(
                  state.error ?? 'Unable to load your alerts',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: context.read<AlertsCubit>().load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ];
      case AlertsStatus.ready:
        return [
          if (state.alerts.isEmpty)
            const _EmptyState()
          else
            for (final alert in state.alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AlertCard(
                  alert: alert,
                  onTap: () => _edit(context, alert),
                ),
              ),
          const SizedBox(height: 12),
          _AddAlertButton(onTap: () => _add(context)),
        ];
    }
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: const Color(0x22000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: const SizedBox.square(
            dimension: 48,
            child: Icon(Icons.chevron_left_rounded, size: 30),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 72,
            color: Color(0xFFC4C4C9),
          ),
          SizedBox(height: 22),
          Text(
            'No alerts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Create an alert to get notifications about price changes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final PriceAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final above = alert.condition == AlertCondition.above;
    final color = above ? const Color(0xFF1FA463) : const Color(0xFFE5383B);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  above
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.base} / ${alert.quote}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Notify when ${above ? 'above' : 'below'} ${formatRate(alert.targetRate)} ${alert.quote}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(alert.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AlertStatus.active => ('Active', _blue),
      AlertStatus.triggered => ('Triggered', const Color(0xFF1FA463)),
      AlertStatus.cancelled => ('Cancelled', _muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AddAlertButton extends StatelessWidget {
  const _AddAlertButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: _blue.withValues(alpha: 0.5),
          radius: 26,
        ),
        child: const SizedBox(
          height: 82,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: _blue,
                  child: Icon(Icons.add, color: Colors.white, size: 22),
                ),
                SizedBox(width: 14),
                Flexible(
                  child: Text(
                    'Add alert',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(1),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 10), paint);
        distance += 18;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
