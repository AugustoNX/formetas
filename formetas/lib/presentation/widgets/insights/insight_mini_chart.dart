import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/insight.dart';
import '../../../domain/services/ant_voice.dart';

/// Barras compactas para o card expandido de um insight.
class InsightMiniChart extends StatelessWidget {
  const InsightMiniChart({
    super.key,
    required this.points,
    required this.color,
    this.height = 110,
  });

  final List<InsightPoint> points;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxAbs = points.fold(0.0, (m, p) => p.value.abs() > m ? p.value.abs() : m);
    final hasNegative = points.any((p) => p.value < 0);
    final top = maxAbs <= 0 ? 1.0 : maxAbs * 1.15;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: top,
          minY: hasNegative ? -top : 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                AntVoice.money(rod.toY),
                const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[i].label,
                      style: const TextStyle(fontSize: 10, color: AppColors.gray),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: points[i].value,
                  width: 14,
                  color: points[i].highlight || (points.length <= 2 && i == points.length - 1)
                      ? color
                      : color.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
