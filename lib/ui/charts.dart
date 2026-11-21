import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../core/units.dart';

typedef TimePoint = ({DateTime at, double value});
typedef DayValue = ({DateTime day, double value});

final _short = DateFormat('d MMM');

/// A line over time, with the first and last dates captioned underneath.
/// An optional shaded band marks a reference range (lab results).
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    this.height = 160,
    this.color,
    this.decimals = 1,
    this.bandLow,
    this.bandHigh,
  });

  final List<TimePoint> points;
  final double height;
  final Color? color;
  final int decimals;
  final double? bandLow;
  final double? bandHigh;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final line = color ?? c.accent;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data yet', style: TextStyle(color: c.fgMuted)),
        ),
      );
    }

    double x(DateTime t) => t.millisecondsSinceEpoch / 86400000.0;
    final spots = [for (final p in points) FlSpot(x(p.at), p.value)];
    var minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    var maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    if (bandLow != null && bandLow! < minY) minY = bandLow!;
    if (bandHigh != null && bandHigh! > maxY) maxY = bandHigh!;
    final pad = (maxY - minY).abs() < 1e-9 ? 1.0 : (maxY - minY) * 0.15;
    minY -= pad;
    maxY += pad;
    final single = spots.length == 1;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: single ? spots.first.x - 1 : null,
              maxX: single ? spots.first.x + 1 : null,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: c.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        formatNumber(value, decimals: decimals),
                        style: TextStyle(fontSize: 11, color: c.fgTertiary),
                      );
                    },
                  ),
                ),
              ),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  if (bandLow != null || bandHigh != null)
                    HorizontalRangeAnnotation(
                      y1: bandLow ?? minY,
                      y2: bandHigh ?? maxY,
                      color: c.success.withValues(alpha: 0.10),
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => c.fg,
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        '${formatNumber(t.y, decimals: decimals)}\n'
                        '${_short.format(DateTime.fromMillisecondsSinceEpoch((t.x * 86400000).round()))}',
                        TextStyle(color: c.bg, fontSize: 12),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: line,
                  barWidth: 2,
                  isCurved: spots.length > 2,
                  preventCurveOverShooting: true,
                  dotData: FlDotData(show: spots.length <= 30),
                  belowBarData: BarAreaData(
                    show: true,
                    color: line.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _short.format(points.first.at),
                style: TextStyle(fontSize: 11, color: c.fgTertiary),
              ),
              if (!single)
                Text(
                  _short.format(points.last.at),
                  style: TextStyle(fontSize: 11, color: c.fgTertiary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One bar per day, with an optional dashed target line.
class DayBarChart extends StatelessWidget {
  const DayBarChart({
    super.key,
    required this.days,
    this.height = 140,
    this.color,
    this.target,
    this.decimals = 0,
  });

  final List<DayValue> days;
  final double height;
  final Color? color;
  final double? target;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = color ?? c.accent;
    var maxY = days.fold(0.0, (m, d) => d.value > m ? d.value : m);
    if (target != null && target! > maxY) maxY = target!;
    if (maxY <= 0) maxY = 1;
    final labelEvery = days.length <= 14 ? 1 : (days.length / 7).ceil();

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (target != null)
                HorizontalLine(
                  y: target!,
                  color: c.fgMuted,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  final d = days[i].day;
                  final label = days.length <= 14
                      ? DateFormat.E().format(d).substring(0, 1)
                      : '${d.day}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 11, color: c.fgTertiary),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.fg,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${formatNumber(rod.toY, decimals: decimals)}\n'
                '${_short.format(days[group.x].day)}',
                TextStyle(color: c.bg, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: days[i].value,
                    color: days[i].value > 0 ? bar : c.bgTertiary,
                    width: days.length <= 14 ? 14 : 6,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The last [count] calendar days ending today, oldest first, each with
/// the value [valueFor] returns for it.
List<DayValue> lastDays(int count, double Function(DateTime day) valueFor) {
  final today = dateOnly(DateTime.now());
  return [
    for (var i = count - 1; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        return (day: d, value: valueFor(d));
      }(),
  ];
}
