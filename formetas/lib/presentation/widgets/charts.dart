import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(enabled: true),
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
    this.height = 180,
  });

  final List<MonthlyTrendPoint> trend;
  final double height;

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

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY * 1.1,
          maxY: maxY * 1.1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.gray.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
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
