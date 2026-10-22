import 'package:flutter/material.dart';

import '../../domain/entities/price_point.dart';

const bullishColor = Color(0xFF34B35B);
const bearishColor = Color(0xFFE5383B);

/// Whether the series ended higher than it began (green) or lower (red). A
/// flat or single-point series counts as bullish.
bool isBullish(List<PricePoint> series) =>
    series.length < 2 || series.last.rate >= series.first.rate;

/// A line chart with a soft fill under it: green when the price rose over the
/// period, red when it fell. Touch and drag to read a price at a time.
class PriceChart extends StatefulWidget {
  const PriceChart({
    super.key,
    required this.series,
    required this.formatValue,
    required this.formatTime,
  });

  final List<PricePoint> series;
  final String Function(double value) formatValue;
  final String Function(DateTime time) formatTime;

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  int? _touched;

  void _touch(double dx, double width) {
    final n = widget.series.length;
    if (n == 0 || width <= 0) return;
    final i = ((dx / width) * (n - 1)).round().clamp(0, n - 1);
    if (i != _touched) setState(() => _touched = i);
  }

  @override
  void didUpdateWidget(PriceChart old) {
    super.didUpdateWidget(old);
    if (old.series != widget.series) _touched = null;
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final color = isBullish(series) ? bullishColor : bearishColor;
    final touched = _touched != null && _touched! < series.length
        ? series[_touched!]
        : null;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) =>
            _touch(d.localPosition.dx, constraints.maxWidth),
        onHorizontalDragUpdate: (d) =>
            _touch(d.localPosition.dx, constraints.maxWidth),
        onHorizontalDragEnd: (_) => setState(() => _touched = null),
        onHorizontalDragCancel: () => setState(() => _touched = null),
        onTapDown: (d) => _touch(d.localPosition.dx, constraints.maxWidth),
        onTapUp: (_) => setState(() => _touched = null),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ChartPainter(
                  series: series,
                  color: color,
                  touchedIndex: _touched,
                ),
              ),
            ),
            if (touched != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 8),
                      ],
                    ),
                    child: Text(
                      '${widget.formatValue(touched.rate)}  ·  '
                      '${widget.formatTime(touched.time)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.color,
    required this.touchedIndex,
  });

  final List<PricePoint> series;
  final Color color;
  final int? touchedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    const topPad = 34.0; // room for the readout
    const bottomPad = 8.0;
    final chartHeight = size.height - topPad - bottomPad;
    if (chartHeight <= 0) return;

    var minV = series.first.rate;
    var maxV = series.first.rate;
    for (final p in series) {
      if (p.rate < minV) minV = p.rate;
      if (p.rate > maxV) maxV = p.rate;
    }
    // A flat line sits in the middle instead of dividing by zero.
    final range = maxV - minV;
    double yOf(double v) => range == 0
        ? topPad + chartHeight / 2
        : topPad + chartHeight * (1 - (v - minV) / range);
    double xOf(int i) => series.length == 1
        ? size.width / 2
        : size.width * i / (series.length - 1);

    final line = Path();
    for (var i = 0; i < series.length; i++) {
      final x = xOf(i);
      final y = yOf(series[i].rate);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    // Soft fill under the line.
    final fill = Path.from(line)
      ..lineTo(xOf(series.length - 1), size.height)
      ..lineTo(xOf(0), size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // A dot on the latest price, or on the touched one with a guide line.
    final i = touchedIndex != null && touchedIndex! < series.length
        ? touchedIndex!
        : series.length - 1;
    final dot = Offset(xOf(i), yOf(series[i].rate));
    if (touchedIndex != null) {
      canvas.drawLine(
        Offset(dot.dx, topPad - 6),
        Offset(dot.dx, size.height),
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawCircle(dot, 6, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.series != series ||
      old.color != color ||
      old.touchedIndex != touchedIndex;
}
