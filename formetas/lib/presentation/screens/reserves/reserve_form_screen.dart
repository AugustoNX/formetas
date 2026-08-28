import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/reserve_calculator.dart';
import '../../../domain/entities/investment_entity.dart';
import '../../../domain/entities/reserve_entity.dart';
import '../../../domain/entities/reserve_movement_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

class ReserveFormScreen extends ConsumerStatefulWidget {
  const ReserveFormScreen({super.key, this.reserveId});

  final String? reserveId;

  @override
  ConsumerState<ReserveFormScreen> createState() => _ReserveFormScreenState();
}

class _ReserveFormScreenState extends ConsumerState<ReserveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankController = TextEditingController();
  final _valueController = TextEditingController();

  ReserveType _type = ReserveType.caixinha;
  LiquidityType _liquidity = LiquidityType.daily;
  DateTime _startDate = DateTime.now();
  DateTime? _maturityDate;
  double? _cdiPercent = 115;
  double? _fixedRate;
  bool _useFixedRate = false;
  bool _isLoading = false;
  ReserveEntity? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.reserveId != null) _load();
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final list = await ref.read(reserveRepositoryProvider).getReserves(user.id);
    final reserve = list.where((r) => r.id == widget.reserveId).firstOrNull;
    if (reserve != null && mounted) {
      setState(() {
        _existing = reserve;
        _nameController.text = reserve.name;
        _bankController.text = reserve.bank ?? '';
        _valueController.text =
            CurrencyFormatter.formatForInput(reserve.initialValue);
        _type = reserve.type;
        _liquidity = reserve.liquidity;
        _startDate = reserve.startDate;
        _maturityDate = reserve.maturityDate;
        _cdiPercent = reserve.cdiPercent;
        _fixedRate = reserve.fixedRate;
        _useFixedRate = reserve.fixedRate != null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final initialValue = _existing != null
          ? _existing!.initialValue
          : (CurrencyFormatter.parse(_valueController.text) ?? 0);

      final movements = _existing != null
          ? (await ref.read(reserveRepositoryProvider).getReservesWithMovements(user.id))
              .where((r) => r.reserve.id == _existing!.id)
              .firstOrNull
              ?.movements ??
              []
          : <ReserveMovementEntity>[];

      final settings = ref.read(settingsProvider).valueOrNull;
      final cdiRate = settings?.cdiRate ?? AppConstants.defaultCdiRate;

      final result = ReserveCalculator.compute(
        reserve: ReserveEntity(
          id: _existing?.id ?? const Uuid().v4(),
          userId: user.id,
          name: _nameController.text,
          type: _type,
          bank: _bankController.text.isEmpty ? null : _bankController.text,
          initialValue: initialValue,
          currentValue: 0,
          cdiPercent: _useFixedRate ? null : _cdiPercent,
          fixedRate: _useFixedRate ? _fixedRate : null,
          startDate: _startDate,
          liquidity: _liquidity,
          maturityDate: _maturityDate,
          createdAt: _existing?.createdAt ?? DateTime.now(),
        ),
        movements: movements,
        cdiRate: cdiRate,
      );

      final reserve = ReserveEntity(
        id: _existing?.id ?? const Uuid().v4(),
        userId: user.id,
        name: _nameController.text,
        type: _type,
        bank: _bankController.text.isEmpty ? null : _bankController.text,
        initialValue: initialValue,
        currentValue: result.currentValue,
        cdiPercent: _useFixedRate ? null : _cdiPercent,
        fixedRate: _useFixedRate ? _fixedRate : null,
        startDate: _startDate,
        liquidity: _liquidity,
        maturityDate: _maturityDate,
        accumulatedYield: result.totalAccumulated,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      final repo = ref.read(reserveRepositoryProvider);
      if (_existing != null) {
        await repo.updateReserve(reserve);
      } else {
        await repo.createReserve(reserve);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.reserveSuccess),
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
    final settings = ref.watch(settingsProvider);
    final cdiRate = settings.valueOrNull?.cdiRate ?? AppConstants.defaultCdiRate;
    final previewValue = CurrencyFormatter.parse(_valueController.text) ?? 0;

    final preview = previewValue > 0 && _existing == null
        ? ReserveCalculator.compute(
            reserve: ReserveEntity(
              id: '',
              userId: '',
              name: '',
              type: _type,
              initialValue: previewValue,
              currentValue: 0,
              cdiPercent: _useFixedRate ? null : _cdiPercent,
              fixedRate: _useFixedRate ? _fixedRate : null,
              startDate: _startDate,
              createdAt: DateTime.now(),
            ),
            movements: const [],
            cdiRate: cdiRate,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing != null ? 'Editar caixinha' : 'Nova caixinha'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) => v?.isEmpty == true ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankController,
              decoration: const InputDecoration(labelText: 'Banco/Instituição'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ReserveType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo de reserva'),
              items: ReserveType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(ReserveTypeLabels.label(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            if (_existing == null) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                inputFormatters: CurrencyFormatter.inputFormatters,
                decoration: const InputDecoration(
                  labelText: 'Valor inicial',
                  prefixText: 'R\$ ',
                  helperText: 'Depois você pode aportar ou resgatar na caixinha',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => v?.isEmpty == true ? 'Informe o valor' : null,
              ),
            ] else ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Valor inicial'),
                subtitle: Text(CurrencyFormatter.format(_existing!.initialValue)),
                trailing: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Movimentar'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Taxa fixa'),
              subtitle: const Text('Ao invés de % do CDI'),
              value: _useFixedRate,
              onChanged: (v) => setState(() => _useFixedRate = v),
            ),
            if (_useFixedRate)
              Slider(
                value: _fixedRate ?? 10,
                min: 1,
                max: 30,
                divisions: 29,
                label: '${(_fixedRate ?? 10).toStringAsFixed(1)}% a.a.',
                onChanged: (v) => setState(() => _fixedRate = v),
              )
            else
              Wrap(
                spacing: 8,
                children: AppConstants.cdiPercentOptions.map((p) {
                  return ChoiceChip(
                    label: Text('$p% CDI'),
                    selected: _cdiPercent == p.toDouble(),
                    onSelected: (_) => setState(() => _cdiPercent = p.toDouble()),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data inicial'),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<LiquidityType>(
              value: _liquidity,
              decoration: const InputDecoration(labelText: 'Liquidez'),
              items: LiquidityType.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.name)))
                  .toList(),
              onChanged: (v) => setState(() => _liquidity = v!),
            ),
            if (preview != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Simulação de rendimento',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _PreviewRow('Valor atualizado', CurrencyFormatter.format(preview.currentValue)),
                    _PreviewRow('Rendimento diário', CurrencyFormatter.format(preview.dailyYield)),
                    _PreviewRow('Rendimento mensal', CurrencyFormatter.format(preview.monthlyYield)),
                    _PreviewRow('Rendimento anual', CurrencyFormatter.format(preview.annualYield)),
                    _PreviewRow('Total acumulado', CurrencyFormatter.format(preview.totalAccumulated)),
                    Text(
                      'Taxa CDI: ${cdiRate.toStringAsFixed(2)}% a.a.',
                      style: TextStyle(color: AppColors.gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar caixinha'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
