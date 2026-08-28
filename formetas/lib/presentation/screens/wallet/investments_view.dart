import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/investment_entity.dart';
import '../../providers/data_providers.dart';

/// Carteira de investimentos. Vive dentro da Carteira, por isso não tem Scaffold.
class InvestmentsView extends ConsumerWidget {
  const InvestmentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments = ref.watch(investmentsProvider);

    return investments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (list) {
        final totalValue =
            list.fold(0.0, (sum, inv) => sum + inv.currentValue);
        final mainInvestment = list.isNotEmpty ? list.first : null;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.investment, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total investido',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(totalValue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (mainInvestment != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      mainInvestment.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Transfira do seu saldo para investir. Não conta como despesa.',
              style: TextStyle(color: AppColors.gray, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final params = mainInvestment != null
                          ? '?from=balance&to=investment&toId=${mainInvestment.id}'
                          : '?from=balance&to=investment';
                      context.push('/transfer$params');
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Investir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.investment,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: totalValue <= 0 || mainInvestment == null
                        ? null
                        : () => context.push(
                              '/transfer?from=investment'
                              '&fromId=${mainInvestment.id}&to=balance',
                            ),
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('Resgatar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.investment,
                      side: const BorderSide(color: AppColors.investment),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            if (list.isEmpty) ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 64,
                      color: AppColors.gray.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum valor investido ainda',
                      style: TextStyle(color: AppColors.gray),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use "Investir" para transferir do saldo',
                      style: TextStyle(color: AppColors.gray, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 28),
              Text(
                'Seus investimentos',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...list.map((inv) => _InvestmentCard(investment: inv)),
            ],
          ],
        );
      },
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({required this.investment});

  final InvestmentEntity investment;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/investment/edit/${investment.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.investment.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.investment,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investment.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Carteira de investimentos',
                      style: TextStyle(color: AppColors.gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format(investment.currentValue),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.investment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
