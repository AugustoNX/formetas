import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/investment_type_groups.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/investment_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

class InvestmentFormScreen extends ConsumerStatefulWidget {
  const InvestmentFormScreen({super.key, this.investmentId});

  final String? investmentId;

  @override
  ConsumerState<InvestmentFormScreen> createState() =>
      _InvestmentFormScreenState();
}

class _InvestmentFormScreenState extends ConsumerState<InvestmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brokerController = TextEditingController();
  final _valueController = TextEditingController();

  InvestmentType _type = InvestmentType.acoes;
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;
  InvestmentEntity? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.investmentId != null) _load();
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final list = await ref.read(investmentRepositoryProvider).getInvestments(user.id);
    final inv = list.where((i) => i.id == widget.investmentId).firstOrNull;
    if (inv != null && mounted) {
      setState(() {
        _existing = inv;
        _nameController.text = inv.name;
        _brokerController.text = inv.bank ?? '';
        _valueController.text = CurrencyFormatter.formatForInput(inv.initialValue);
        _type = InvestmentTypeGroups.isMarket(inv.type)
            ? inv.type
            : InvestmentType.acoes;
        _startDate = inv.startDate;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brokerController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final initialValue = CurrencyFormatter.parse(_valueController.text) ?? 0;

      final inv = InvestmentEntity(
        id: _existing?.id ?? const Uuid().v4(),
        userId: user.id,
        name: _nameController.text,
        type: _type,
        bank: _brokerController.text.isEmpty ? null : _brokerController.text,
        initialValue: initialValue,
        currentValue: initialValue,
        startDate: _startDate,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      final repo = ref.read(investmentRepositoryProvider);
      if (_existing != null) {
        await repo.updateInvestment(inv);
      } else {
        await repo.createInvestment(inv);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.investSuccess),
            backgroundColor: AppColors.secondary,
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing != null ? 'Editar investimento' : 'Novo investimento'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.investment.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.investment, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ações, FIIs, ETFs e outros ativos de mercado. '
                      'Reserva e CDI ficam em Caixinha.',
                      style: TextStyle(color: AppColors.gray, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome / Ativo'),
              validator: (v) => v?.isEmpty == true ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _brokerController,
              decoration: const InputDecoration(labelText: 'Corretora'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<InvestmentType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: InvestmentTypeGroups.marketTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(InvestmentTypeGroups.label(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              inputFormatters: CurrencyFormatter.inputFormatters,
              decoration: const InputDecoration(
                labelText: 'Valor investido',
                prefixText: 'R\$ ',
              ),
              validator: (v) => v?.isEmpty == true ? 'Informe o valor' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data da aplicação'),
              subtitle: Text(
                '${_startDate.day}/${_startDate.month}/${_startDate.year}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2010),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar investimento'),
            ),
          ],
        ),
      ),
    );
  }
}
