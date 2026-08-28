import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/investment_calculator.dart';
import '../../../core/utils/reserve_calculator.dart';
import '../../../domain/entities/reserve_entity.dart';
import '../../../domain/entities/reserve_movement_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/anthill/anthill_feedback.dart';

class ReserveDetailScreen extends ConsumerWidget {
  const ReserveDetailScreen({super.key, required this.reserveId});

  final String reserveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reserves = ref.watch(reservesWithMovementsProvider);
    final settings = ref.watch(settingsProvider);
    final cdiRate = settings.valueOrNull?.cdiRate ?? AppConstants.defaultCdiRate;

    return reserves.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $e')),
      ),
      data: (list) {
        final item = list.where((r) => r.reserve.id == reserveId).firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Caixinha não encontrada')),
          );
        }

        final result = ReserveCalculator.compute(
          reserve: item.reserve,
          movements: item.movements,
          cdiRate: cdiRate,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(item.reserve.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/reserve/edit/${item.reserve.id}'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _BalanceHeader(reserve: item.reserve, result: result, cdiRate: cdiRate),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        '/transfer?from=balance&to=reserve&toId=${item.reserve.id}',
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Do saldo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.income,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/transfer?from=reserve&fromId=${item.reserve.id}&to=balance',
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Para saldo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                        side: const BorderSide(color: AppColors.expense),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showMovementSheet(
                        context,
                        ref,
                        item: item,
                        type: ReserveMovementType.deposit,
                        cdiRate: cdiRate,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Aporte externo'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showMovementSheet(
                        context,
                        ref,
                        item: item,
                        type: ReserveMovementType.withdrawal,
                        cdiRate: cdiRate,
                      ),
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      label: const Text('Resgate externo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Movimentações',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              if (item.reserve.initialValue > 0)
                _MovementTile(
                  title: 'Valor inicial',
                  subtitle: AppDateUtils.formatDate(item.reserve.startDate),
                  amount: item.reserve.initialValue,
                  isDeposit: true,
                  isInitial: true,
                ),
              ...item.movements.map(
                (movement) => _MovementTile(
                  title: movement.description ??
                      (movement.type == ReserveMovementType.deposit
                          ? 'Aporte'
                          : 'Resgate'),
                  subtitle: AppDateUtils.formatDate(movement.date),
                  amount: movement.amount,
                  isDeposit: movement.type == ReserveMovementType.deposit,
                  onDelete: () => _deleteMovement(
                    context,
                    ref,
                    item: item,
                    movement: movement,
                    cdiRate: cdiRate,
                  ),
                ),
              ),
              if (item.reserve.initialValue <= 0 && item.movements.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Nenhuma movimentação ainda.\nFaça seu primeiro aporte!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gray),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteMovement(
    BuildContext context,
    WidgetRef ref, {
    required ReserveWithMovements item,
    required ReserveMovementEntity movement,
    required double cdiRate,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir movimentação'),
        content: const Text('Deseja excluir esta movimentação?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await ref.read(reserveRepositoryProvider).deleteMovement(
          user.id,
          movement.reserveId,
          movement.id,
        );

    final remaining = item.movements.where((m) => m.id != movement.id).toList();
    await _syncReserveTotals(
      ref,
      reserve: item.reserve,
      movements: remaining,
      cdiRate: cdiRate,
    );
  }

  Future<void> _showMovementSheet(
    BuildContext context,
    WidgetRef ref, {
    required ReserveWithMovements item,
    required ReserveMovementType type,
    required double cdiRate,
  }) async {
    final valueController = TextEditingController();
    final descriptionController = TextEditingController();
    var date = DateTime.now();
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      type == ReserveMovementType.deposit ? 'Novo aporte' : 'Novo resgate',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      inputFormatters: CurrencyFormatter.inputFormatters,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R\$ ',
                        hintText: type == ReserveMovementType.deposit ? 'Ex: 1.000,00' : null,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe o valor';
                        final parsed = CurrencyFormatter.parse(v);
                        if (parsed == null || parsed <= 0) return 'Valor inválido';
                        if (type == ReserveMovementType.withdrawal) {
                          final max = ReserveCalculator.maxWithdrawal(
                            reserve: item.reserve,
                            movements: item.movements,
                            cdiRate: cdiRate,
                          );
                          if (CurrencyFormatter.exceeds(parsed, max)) {
                            return 'Saldo disponível: ${CurrencyFormatter.format(max)}';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                        hintText: 'Ex: Aporte do mês',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data'),
                      subtitle: Text(AppDateUtils.formatDate(date)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() => date = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: type == ReserveMovementType.deposit
                            ? AppColors.income
                            : AppColors.expense,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        type == ReserveMovementType.deposit
                            ? 'Confirmar aporte'
                            : 'Confirmar resgate',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final amount = CurrencyFormatter.parse(valueController.text) ?? 0;
    final movement = ReserveMovementEntity(
      id: const Uuid().v4(),
      reserveId: item.reserve.id,
      userId: user.id,
      type: type,
      amount: amount,
      date: date,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      createdAt: DateTime.now(),
    );

    await ref.read(reserveRepositoryProvider).createMovement(movement);
    await _syncReserveTotals(
      ref,
      reserve: item.reserve,
      movements: [...item.movements, movement],
      cdiRate: cdiRate,
    );

    if (context.mounted) {
      final isDeposit = type == ReserveMovementType.deposit;
      final gamified = isDeposit ? AnthillFeedback.stored(ref, amount) : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: gamified ??
              Text(
                isDeposit
                    ? AppStrings.reserveDepositSuccess
                    : AppStrings.reserveWithdrawSuccess,
              ),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  Future<void> _syncReserveTotals(
    WidgetRef ref, {
    required ReserveEntity reserve,
    required List<ReserveMovementEntity> movements,
    required double cdiRate,
  }) async {
    final result = ReserveCalculator.compute(
      reserve: reserve,
      movements: movements,
      cdiRate: cdiRate,
    );
    await ref.read(reserveRepositoryProvider).updateReserve(
          reserve.copyWith(
            currentValue: result.currentValue,
            accumulatedYield: result.totalAccumulated,
          ),
        );
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.reserve,
    required this.result,
    required this.cdiRate,
  });

  final ReserveEntity reserve;
  final InvestmentYieldResult result;
  final double cdiRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ReserveTypeLabels.label(reserve.type),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(result.currentValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rendimento: ${CurrencyFormatter.format(result.totalAccumulated)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          if (reserve.cdiPercent != null) ...[
            const SizedBox(height: 4),
            Text(
              '${reserve.cdiPercent!.toStringAsFixed(0)}% do CDI · taxa ${cdiRate.toStringAsFixed(2)}% a.a.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
            ),
          ] else if (reserve.fixedRate != null) ...[
            const SizedBox(height: 4),
            Text(
              '${reserve.fixedRate!.toStringAsFixed(1)}% a.a. fixo',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isDeposit,
    this.isInitial = false,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final double amount;
  final bool isDeposit;
  final bool isInitial;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = isDeposit ? AppColors.income : AppColors.expense;
    final prefix = isDeposit ? '+' : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: color,
            size: 20,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.gray, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$prefix${CurrencyFormatter.format(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (!isInitial && onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.gray, size: 20),
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
