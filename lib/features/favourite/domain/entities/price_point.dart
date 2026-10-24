import 'package:equatable/equatable.dart';

/// One stored price observation of an asset.
class PricePoint extends Equatable {
  const PricePoint({required this.time, required this.rate});

  final DateTime time;
  final double rate;

  @override
  List<Object?> get props => [time, rate];
}

/// How coarse the chart is: one point per [duration].
enum ChartInterval {
  m10('10m', Duration(minutes: 10)),
  h1('1H', Duration(hours: 1)),
  d1('1D', Duration(days: 1)),
  w1('1W', Duration(days: 7)),
  mo1('1M', Duration(days: 30));

  const ChartInterval(this.label, this.duration);

  final String label;
  final Duration duration;
}

/// The chart always covers this long.
const chartWindow = Duration(days: 30);

/// Keeps the last observation of every [interval]-long bucket, oldest first.
/// [points] may come in any order.
List<PricePoint> bucketPoints(List<PricePoint> points, Duration interval) {
  final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
  final size = interval.inMilliseconds;
  final result = <PricePoint>[];
  int? lastBucket;
  for (final p in sorted) {
    final bucket = p.time.millisecondsSinceEpoch ~/ size;
    if (bucket == lastBucket) {
      result[result.length - 1] = p;
    } else {
      result.add(p);
      lastBucket = bucket;
    }
  }
  return result;
}
