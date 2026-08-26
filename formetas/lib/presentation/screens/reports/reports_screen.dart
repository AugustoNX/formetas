import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/data_providers.dart';
import '../../widgets/charts.dart';
import '../../widgets/formetas_card.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final statistics = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (dashboard) {
          return statistics.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (summary) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Fluxo de caixa',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                FormetasCard(
                  child: Column(
                    children: [
                      _FlowRow(
                        label: 'Receitas',
                        value: dashboard.monthlyIncome,
                        color: AppColors.income,
                      ),
                      const Divider(height: 24),
                      _FlowRow(
                        label: 'Despesas',
                        value: dashboard.monthlyExpense,
                        color: AppColors.expense,
                      ),
                      const Divider(height: 24),
                      _FlowRow(
                        label: 'Economia',
                        value: dashboard.monthlySavings,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Comparativo anual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                FormetasCard(
                  child: MonthlyBarChart(trend: dashboard.monthlyTrend, height: 220),
                ),
                const SizedBox(height: 24),
                Text(
                  'Evolução patrimonial',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                FormetasCard(
                  child: BalanceLineChart(trend: dashboard.monthlyTrend, height: 200),
                ),
                const SizedBox(height: 24),
                Text(
                  'Receitas por categoria',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                FormetasCard(
                  child: ChartLegend(data: dashboard.incomeByCategory),
                ),
                const SizedBox(height: 24),
                Text(
                  'Estatísticas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                FormetasCard(
                  child: Column(
                    children: [
                      _StatTile(
                        label: 'Maior gasto',
                        value: summary.largestExpense != null
                            ? CurrencyFormatter.format(summary.largestExpense!.value)
                            : '-',
                      ),
                      _StatTile(
                        label: 'Maior receita',
                        value: summary.largestIncome != null
                            ? CurrencyFormatter.format(summary.largestIncome!.value)
                            : '-',
                      ),
                      _StatTile(
                        label: 'Média mensal de gastos',
                        value: CurrencyFormatter.format(summary.averageMonthlyExpense),
                      ),
                      _StatTile(
                        label: 'Economia média',
                        value: CurrencyFormatter.format(summary.averageMonthlySavings),
                      ),
                      _StatTile(
                        label: 'Categoria que mais gastou',
                        value: summary.topExpenseCategory,
                      ),
                      _StatTile(
                        label: 'Categoria que mais recebeu',
                        value: summary.topIncomeCategory,
                      ),
                      _StatTile(
                        label: 'Total investido',
                        value: CurrencyFormatter.format(summary.totalInvested),
                      ),
                      _StatTile(
                        label: 'Total rendido',
                        value: CurrencyFormatter.format(summary.totalYield),
                      ),
                      _StatTile(
                        label: 'Patrimônio',
                        value: CurrencyFormatter.format(summary.netWorth),
                      ),
                      _StatTile(
                        label: 'Saldo atual',
                        value: CurrencyFormatter.format(summary.currentBalance),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.gray)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
