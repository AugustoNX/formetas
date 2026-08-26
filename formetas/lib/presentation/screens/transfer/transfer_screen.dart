import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/investment_entity.dart';
import '../../../domain/entities/reserve_movement_entity.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/services/transfer_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.initialFromId,
    this.initialToId,
  });

  final String? initialFrom;
  final String? initialTo;
  final String? initialFromId;
  final String? initialToId;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();

  late WalletType _fromType;
  late WalletType _toType;
  String? _fromId;
  String? _toId;
  DateTime _date = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fromType = _parseWallet(widget.initialFrom) ?? WalletType.balance;
    _toType = _parseWallet(widget.initialTo) ?? WalletType.reserve;
    _fromId = widget.initialFromId;
    _toId = widget.initialToId;
  }

  WalletType? _parseWallet(String? value) {
    if (value == null) return null;
    for (final wallet in WalletType.values) {
      if (wallet.name == value) return wallet;
    }
    return null;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final amount = CurrencyFormatter.parse(_valueController.text) ?? 0;
      final transactions = ref.read(transactionsProvider).valueOrNull ?? [];
      final transfers = ref.read(transfersProvider).valueOrNull ?? [];
      final reserves = ref.read(reservesWithMovementsProvider).valueOrNull ?? [];
      final investments = ref.read(investmentsProvider).valueOrNull ?? [];
      final settings = ref.read(settingsProvider).valueOrNull;
      final cdiRate = settings?.cdiRate ?? AppConstants.defaultCdiRate;

      var toId = _toId;
      if (_toType == WalletType.investment && (toId == null || toId.isEmpty)) {
        toId = await ref.read(transferServiceProvider).ensureDefaultInvestment(user.id);
      }

      await ref.read(transferServiceProvider).execute(
            userId: user.id,
            fromType: _fromType,
            toType: _toType,
            fromId: _fromId,
            toId: toId,
            amount: amount,
            date: _date,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            transactions: transactions,
            transfers: transfers,
            reserves: reserves,
            investments: investments,
            cdiRate: cdiRate,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.transferSuccess),
            backgroundColor: AppColors.secondary,
          ),
        );
        context.pop();
      }
    } on TransferException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.expense),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reserves = ref.watch(reservesWithMovementsProvider).valueOrNull ?? [];
    final investments = ref.watch(investmentsProvider).valueOrNull ?? [];
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? [];
    final transfers = ref.watch(transfersProvider).valueOrNull ?? [];
    final settings = ref.watch(settingsProvider).valueOrNull;
    final cdiRate = settings?.cdiRate ?? AppConstants.defaultCdiRate;
    final transferService = ref.read(transferServiceProvider);

    final availableFrom = transferService.availableFrom(
      fromType: _fromType,
      fromId: _fromId,
      transactions: transactions,
      transfers: transfers,
      reserves: reserves,
      investments: investments,
      cdiRate: cdiRate,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Transferir')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mova dinheiro entre saldo, caixinha e investimentos '
                      'sem registrar como despesa.',
                      style: TextStyle(color: AppColors.gray, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('De', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _WalletSelector(
              selectedType: _fromType,
              selectedId: _fromId,
              reserves: reserves,
              investments: investments,
              excludeType: _toType,
              excludeId: _toId,
              onChanged: (type, id) => setState(() {
                _fromType = type;
                _fromId = id;
                _formKey.currentState?.validate();
              }),
            ),
            if (_fromType == WalletType.balance ||
                _fromType == WalletType.reserve ||
                _fromType == WalletType.investment) ...[
              const SizedBox(height: 8),
              Text(
                'Disponível: ${CurrencyFormatter.format(availableFrom)}',
                style: TextStyle(
                  color: availableFrom > 0 ? AppColors.gray : AppColors.expense,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Para', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _WalletSelector(
              selectedType: _toType,
              selectedId: _toId,
              reserves: reserves,
              investments: investments,
              excludeType: _fromType,
              excludeId: _fromId,
              onChanged: (type, id) => setState(() {
                _toType = type;
                _toId = id;
              }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              inputFormatters: CurrencyFormatter.inputFormatters,
              decoration: InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
                helperText: availableFrom > 0
                    ? 'Máximo: ${CurrencyFormatter.format(availableFrom)}'
                    : 'Sem saldo disponível na origem',
              ),
              onChanged: (_) => _formKey.currentState?.validate(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                final parsed = CurrencyFormatter.parse(v);
                if (parsed == null || parsed <= 0) return 'Valor inválido';
                if (CurrencyFormatter.exceeds(parsed, availableFrom)) {
                  return 'Disponível: ${CurrencyFormatter.format(availableFrom)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Ex: Reserva de emergência',
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text(AppDateUtils.formatDate(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading || availableFrom <= 0 ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmar transferência'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSelector extends StatelessWidget {
  const _WalletSelector({
    required this.selectedType,
    required this.selectedId,
    required this.reserves,
    required this.investments,
    required this.onChanged,
    this.excludeType,
    this.excludeId,
  });

  final WalletType selectedType;
  final String? selectedId;
  final List<ReserveWithMovements> reserves;
  final List<InvestmentEntity> investments;
  final void Function(WalletType type, String? id) onChanged;
  final WalletType? excludeType;
  final String? excludeId;

  @override
  Widget build(BuildContext context) {
    final options = <_WalletOption>[
      if (!(excludeType == WalletType.balance))
        const _WalletOption(type: WalletType.balance, label: 'Saldo disponível'),
      ...reserves.map(
        (r) => _WalletOption(
          type: WalletType.reserve,
          id: r.reserve.id,
          label: r.reserve.name,
        ),
      ),
      if (investments.isEmpty)
        const _WalletOption(
          type: WalletType.investment,
          label: TransferService.defaultInvestmentName,
        )
      else
        ...investments.map(
          (i) => _WalletOption(
            type: WalletType.investment,
            id: i.id,
            label: i.name,
          ),
        ),
    ].where((o) {
      if (excludeType == null) return true;
      if (o.type != excludeType) return true;
      if (o.type == WalletType.balance) return false;
      return o.id != excludeId;
    }).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected =
            selectedType == option.type && selectedId == option.id;
        return ChoiceChip(
          label: Text(option.label),
          selected: isSelected,
          onSelected: (_) => onChanged(option.type, option.id),
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
        );
      }).toList(),
    );
  }
}

class _WalletOption {
  const _WalletOption({
    required this.type,
    required this.label,
    this.id,
  });

  final WalletType type;
  final String? id;
  final String label;
}
