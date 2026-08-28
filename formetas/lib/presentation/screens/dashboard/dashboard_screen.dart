import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/anthill/anthill_entry_banner.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/charts.dart';
import '../../widgets/formetas_card.dart';
import '../../widgets/movement_tile.dart';
import '../../widgets/transaction_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final user = ref.watch(currentUserProvider);
    final movements = ref.watch(movementsProvider).valueOrNull ?? [];
    final recentMovements = movements.take(10).toList();

    return Scaffold(
      body: SafeArea(
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _DataLoadError(
            error: e,
            onRetry: () {
              ref.invalidate(transactionsProvider);
              ref.invalidate(investmentsProvider);
              ref.invalidate(reservesWithMovementsProvider);
              ref.invalidate(transfersProvider);
              ref.invalidate(settingsProvider);
            },
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(investmentsProvider);
              ref.invalidate(reservesWithMovementsProvider);
              ref.invalidate(transfersProvider);
              ref.invalidate(settingsProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Olá, ${user?.name.split(' ').first ?? 'Formigueiro'}!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppStrings.tagline,
                                    style: TextStyle(
                                      color: AppColors.gray,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => context.push('/profile'),
                              icon: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  (user?.name.isNotEmpty == true
                                          ? user!.name[0]
                                          : 'F')
                                      .toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const AnthillEntryBanner(),
                        const SizedBox(height: 20),
                        _MonthSelector(
                          selectedMonth: selectedMonth,
                          onChanged: (month) =>
                              ref.read(selectedMonthProvider.notifier).state = month,
                        ),
                        const SizedBox(height: 20),
                        FormetasCard(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo disponível',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                CurrencyFormatter.format(data.totalBalance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _MiniStat(
                                    label: 'Saldo inicial',
                                    value: CurrencyFormatter.format(data.openingBalance),
                                  ),
                                  const SizedBox(width: 24),
                                  _MiniStat(
                                    label: 'Patrimônio',
                                    value: CurrencyFormatter.format(data.netWorth),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1),
                        if (data.totalBalance < 0) ...[
                          const SizedBox(height: 16),
                          const BrandMessageBanner(
                            message: AppStrings.negativeBalance,
                            positive: false,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _StatsGrid(
                          children: [
                            BalanceCard(
                              title: 'Receitas',
                              value: data.monthlyIncome,
                              color: AppColors.income,
                              icon: Icons.arrow_downward_rounded,
                              compact: true,
                            ),
                            BalanceCard(
                              title: 'Despesas',
                              value: data.monthlyExpense,
                              color: AppColors.expense,
                              icon: Icons.arrow_upward_rounded,
                              compact: true,
                            ),
                            GestureDetector(
                              onTap: () => context.go('/carteira'),
                              child: BalanceCard(
                                title: 'Economia',
                                value: data.totalReserves,
                                color: AppColors.accent,
                                icon: Icons.savings_outlined,
                                compact: true,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  context.go('/carteira?aba=investimentos'),
                              child: BalanceCard(
                                title: 'Investimentos',
                                value: data.totalInvestments,
                                color: AppColors.investment,
                                icon: Icons.trending_up_rounded,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Despesas por categoria',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        FormetasCard(
                          child: data.expensesByCategory.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Nenhuma despesa neste mês',
                                      style: TextStyle(color: AppColors.gray),
                                    ),
                                  ),
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ExpensePieChart(
                                      data: data.expensesByCategory,
                                      size: 140,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ChartLegend(
                                        data: data.expensesByCategory,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Evolução mensal',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        FormetasCard(
                          child: MonthlyBarChart(trend: data.monthlyTrend),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Saldo acumulado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        FormetasCard(
                          child: BalanceLineChart(trend: data.monthlyTrend),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Últimas movimentações',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/transactions'),
                              child: const Text('Ver todas'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (recentMovements.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Nenhuma movimentação ainda.\nComece registrando sua primeira!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.gray),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = recentMovements[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: MovementTile(
                            entry: item,
                            onTap: () {
                              final tx = item.transaction;
                              if (tx != null) {
                                context.push('/transaction/edit/${tx.id}');
                              }
                            },
                          ),
                        );
                      },
                      childCount: recentMovements.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossCount = width >= AppBreakpoints.desktop ? 4 : 2;
    final rows = <Widget>[];

    for (var i = 0; i < children.length; i += crossCount) {
      final slice = children.sublist(
        i,
        i + crossCount > children.length ? children.length : i + crossCount,
      );
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < slice.length; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(child: slice[j]),
              ],
              for (var j = slice.length; j < crossCount; j++) ...[
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
      if (i + crossCount < children.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onChanged,
  });

  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            onChanged(DateTime(selectedMonth.year, selectedMonth.month - 1));
          },
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          AppDateUtils.formatMonthYear(selectedMonth),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        IconButton(
          onPressed: selectedMonth.isBefore(DateTime.now())
              ? () {
                  onChanged(DateTime(selectedMonth.year, selectedMonth.month + 1));
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _DataLoadError extends StatelessWidget {
  const _DataLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final raw = error.toString().toLowerCase();
    final isPermission = raw.contains('permission-denied') ||
        raw.contains('permission denied') ||
        raw.contains("doesn't have permission") ||
        raw.contains('does not have permission');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.gray.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              isPermission
                  ? 'Ainda estamos liberando o acesso da sua conta.'
                  : 'Não foi possível carregar seus dados.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isPermission
                  ? 'Toque em tentar de novo daqui a alguns segundos.'
                  : 'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar de novo'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
