import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/investment_calculator.dart';
import '../../../core/utils/reserve_calculator.dart';
import '../../../domain/entities/reserve_entity.dart';
import '../../providers/data_providers.dart';

/// Lista de caixinhas. Vive dentro da Carteira, por isso não tem Scaffold.
class ReservesView extends ConsumerWidget {
  const ReservesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reserves = ref.watch(reservesWithMovementsProvider);
    final settings = ref.watch(settingsProvider);

    return reserves.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: 64,
                  color: AppColors.gray.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma caixinha cadastrada',
                  style: TextStyle(color: AppColors.gray),
                ),
                const SizedBox(height: 8),
                Text(
                  'CDB, caixinha, poupança e mais',
                  style: TextStyle(color: AppColors.gray, fontSize: 12),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/reserve/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar caixinha'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                ),
              ],
            ),
          );
        }

        final cdiRate =
            settings.valueOrNull?.cdiRate ?? AppConstants.defaultCdiRate;
        var totalValue = 0.0;
        var totalYield = 0.0;

        for (final item in list) {
          final result = ReserveCalculator.compute(
            reserve: item.reserve,
            movements: item.movements,
            cdiRate: cdiRate,
          );
          totalValue += result.currentValue;
          totalYield += result.totalAccumulated;
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reserva e economia',
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
                  const SizedBox(height: 12),
                  Text(
                    'Rendimento acumulado: ${CurrencyFormatter.format(totalYield)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...list.map((item) {
              final result = ReserveCalculator.compute(
                reserve: item.reserve,
                movements: item.movements,
                cdiRate: cdiRate,
              );
              return _ReserveCard(
                reserve: item.reserve,
                result: result,
                onTap: () => context.push('/reserve/${item.reserve.id}'),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ReserveCard extends StatelessWidget {
  const _ReserveCard({
    required this.reserve,
    required this.result,
    required this.onTap,
  });

  final ReserveEntity reserve;
  final InvestmentYieldResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.savings_outlined,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reserve.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${ReserveTypeLabels.label(reserve.type)}'
                          '${reserve.bank != null ? ' · ${reserve.bank}' : ''}',
                          style: TextStyle(color: AppColors.gray, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(result.currentValue),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _YieldChip(
                    label: 'Diário',
                    value: CurrencyFormatter.format(result.dailyYield),
                  ),
                  _YieldChip(
                    label: 'Mensal',
                    value: CurrencyFormatter.format(result.monthlyYield),
                  ),
                  _YieldChip(
                    label: 'Anual',
                    value: CurrencyFormatter.format(result.annualYield),
                  ),
                ],
              ),
              if (reserve.cdiPercent != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${reserve.cdiPercent!.toStringAsFixed(0)}% do CDI',
                  style: TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ] else if (reserve.fixedRate != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${reserve.fixedRate!.toStringAsFixed(1)}% a.a. fixo',
                  style: TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _YieldChip extends StatelessWidget {
  const _YieldChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: AppColors.gray, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}
