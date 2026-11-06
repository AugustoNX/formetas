import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/dashboard_entity.dart';

class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({
    super.key,
    required this.data,
    this.size = 180,
  });

  final Map<String, double> data;
  final double size;

  static const chartColors = [
    AppColors.expense,
    AppColors.accent,
    AppColors.secondary,
    AppColors.investment,
    AppColors.gold,
    AppColors.reserve,
    AppColors.primary,
    AppColors.gray,
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            'Sem dados para exibir',
            style: TextStyle(color: AppColors.gray),
          ),
        ),
      );
    }

    final entries = data.entries.toList();
    final total = entries.fold(0.0, (s, e) => s + e.value);

    return SizedBox(
      width: size,
      height: size,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: size * 0.28,
          sections: List.generate(entries.length, (i) {
            final entry = entries[i];
            final percent = total > 0 ? (entry.value / total * 100) : 0.0;
            return PieChartSectionData(
              value: entry.value,
              title: '${percent.toStringAsFixed(0)}%',
              color: chartColors[i % chartColors.length],
              radius: size * 0.22,
              titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.trend,
    this.height = 200,
  });

  final List<MonthlyTrendPoint> trend;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Sem histórico', style: TextStyle(color: AppColors.gray))),
      );
    }

    final maxY = trend
        .map((t) => [t.income, t.expense, t.balance.abs()])
        .expand((e) => e)
        .fold(0.0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.2;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMaxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 200,
              tooltipRoundedRadius: 10,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              getTooltipColor: (_) => AppColors.primary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex < 0 || groupIndex >= trend.length) return null;
                final point = trend[groupIndex];
                final isIncome = rodIndex == 0;
                final label = isIncome ? 'Receitas' : 'Despesas';
                final amount = isIncome ? point.income : point.expense;
                final month =
                    '${AppDateUtils.formatMonthShort(point.month)} ${point.month.year}';
                return BarTooltipItem(
                  '$month\n',
                  TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                  children: [
                    TextSpan(
                      text: '$label\n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    TextSpan(
                      text: CurrencyFormatter.format(amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppDateUtils.formatMonthShort(trend[index].month),
                      style: const TextStyle(fontSize: 10, color: AppColors.gray),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(trend.length, (i) {
            final point = trend[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: point.income,
                  color: AppColors.income,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: point.expense,
                  color: AppColors.expense,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class BalanceLineChart extends StatelessWidget {
  const BalanceLineChart({
    super.key,
    required this.trend,
    this.height = 200,
  });

  final List<MonthlyTrendPoint> trend;
  final double height;

  static String _compactAxisValue(double value) {
    return NumberFormat.compact(locale: 'pt_BR').format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (trend.length < 2) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Dados insuficientes', style: TextStyle(color: AppColors.gray))),
      );
    }

    final spots = trend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.balance);
    }).toList();

    final values = spots.map((s) => s.y);
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    var range = maxY - minY;

    if (range.abs() < 0.01) {
      final pad = minY.abs() < 0.01 ? 10.0 : minY.abs() * 0.1;
      minY -= pad;
      maxY += pad;
      range = maxY - minY;
    } else {
      final pad = range * 0.1;
      minY -= pad;
      maxY += pad;
      range = maxY - minY;
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          clipData: const FlClipData.none(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.gray.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 16,
                getTitlesWidget: (value, meta) => const SizedBox.shrink(),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: range / 4,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _compactAxisValue(value),
                      style: const TextStyle(fontSize: 10, color: AppColors.gray),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 || index >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  if ((value - index).abs() > 0.01) {
                    return const SizedBox.shrink();
                  }
                  final dense = trend.length > 8;
                  if (dense &&
                      index != 0 &&
                      index != trend.length - 1 &&
                      index % 2 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppDateUtils.formatMonthShort(trend[index].month),
                      style: const TextStyle(fontSize: 10, color: AppColors.gray),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchSpotThreshold: 24,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 200,
              tooltipRoundedRadius: 10,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              tooltipMargin: 10,
              getTooltipColor: (_) => AppColors.primary,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.round().clamp(0, trend.length - 1);
                  final point = trend[index];
                  final monthLabel =
                      '${AppDateUtils.formatMonthShort(point.month)} ${point.month.year}';
                  return LineTooltipItem(
                    monthLabel,
                    TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                    children: [
                      TextSpan(
                        text: '\n${CurrencyFormatter.format(point.balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((_) {
                return TouchedSpotIndicatorData(
                  const FlLine(
                    color: AppColors.primary,
                    strokeWidth: 1.5,
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 5,
                      color: AppColors.primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                );
              }).toList();
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({
    super.key,
    required this.data,
  });

  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Nenhuma despesa neste mês',
          style: TextStyle(color: AppColors.gray, fontSize: 13),
        ),
      );
    }

    final colors = ExpensePieChart.chartColors;
    final entries = data.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(entries.length.clamp(0, 6), (i) {
        final entry = entries[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CurrencyFormatter.format(entry.value),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        );
      }),
    );
  }
}
