import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/category_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/category_selector.dart';
import '../../widgets/transaction_tile.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.initialType = 'expense',
    this.transactionId,
  });

  final String initialType;
  final String? transactionId;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _observationsController = TextEditingController();
  final _accountController = TextEditingController();

  late TransactionType _type;
  String? _category;
  DateTime _date = DateTime.now();
  RecurrenceType _recurrence = RecurrenceType.none;
  PaymentMethod _paymentMethod = PaymentMethod.pix;
  bool _isPaid = true;
  bool _isInstallment = false;
  int _installmentCount = 2;
  bool _isLoading = false;
  TransactionEntity? _existing;

  @override
  void initState() {
    super.initState();
    _type = _parseInitialType(widget.initialType);
    if (widget.transactionId != null) {
      _loadTransaction();
    }
  }

  TransactionType _parseInitialType(String type) {
    if (type == 'income') return TransactionType.income;
    return TransactionType.expense;
  }

  Future<void> _loadTransaction() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final tx = await ref
        .read(transactionRepositoryProvider)
        .getTransaction(user.id, widget.transactionId!);
    if (tx != null && mounted) {
      if (tx.type == TransactionType.investment) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Investimentos são gerenciados na tela de Investimentos.'),
          ),
        );
        context.go('/investments');
        return;
      }
      setState(() {
        _existing = tx;
        _type = tx.type;
        _category = tx.category;
        _valueController.text = CurrencyFormatter.formatForInput(tx.value);
        _descriptionController.text = tx.description;
        _observationsController.text = tx.observations ?? '';
        _accountController.text = tx.account ?? '';
        _date = tx.date;
        _recurrence = tx.recurrence;
        _paymentMethod = tx.paymentMethod ?? PaymentMethod.pix;
        _isPaid = tx.isPaid;
        _isInstallment = tx.isInstallment;
        _installmentCount = tx.installmentCount;
      });
    }
  }

  Future<void> _createCategory(String name) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final category = await createCategoryForType(
      userId: user.id,
      name: name,
      type: _type,
    );

    await ref.read(categoryRepositoryProvider).createCategory(category);
  }

  List<CategoryEntity> _filteredCategories(List<CategoryEntity> cats) {
    return cats.where((c) => c.type == _type).toList();
  }

  String? _resolveCategory(List<CategoryEntity> cats) {
    final filtered = _filteredCategories(cats);
    if (filtered.isEmpty) return null;

    if (_category != null && filtered.any((c) => c.name == _category)) {
      return _category;
    }
    return filtered.first.name;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _descriptionController.dispose();
    _observationsController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final resolvedCategory = _resolveCategory(categories);

    if (resolvedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ou crie uma categoria')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final value = CurrencyFormatter.parse(_valueController.text) ?? 0;
      final repo = ref.read(transactionRepositoryProvider);

      if (_isInstallment && _existing == null && _type == TransactionType.expense) {
        final parentId = const Uuid().v4();
        final installmentValue = value / _installmentCount;

        for (var i = 0; i < _installmentCount; i++) {
          final tx = TransactionEntity(
            id: i == 0 ? parentId : const Uuid().v4(),
            userId: user.id,
            type: _type,
            category: resolvedCategory,
            value: installmentValue,
            description: '${_descriptionController.text} (${i + 1}/$_installmentCount)',
            date: DateTime(_date.year, _date.month + i, _date.day),
            observations: _observationsController.text.isEmpty
                ? null
                : _observationsController.text,
            recurrence: _recurrence,
            account: _accountController.text.isEmpty ? null : _accountController.text,
            paymentMethod: _paymentMethod,
            isPaid: _isPaid,
            isInstallment: true,
            installmentCount: _installmentCount,
            installmentNumber: i + 1,
            parentId: parentId,
            createdAt: DateTime.now(),
          );
          await repo.createTransaction(tx);
        }
      } else {
        final tx = TransactionEntity(
          id: _existing?.id ?? const Uuid().v4(),
          userId: user.id,
          type: _type,
          category: resolvedCategory,
          value: value,
          description: _descriptionController.text,
          date: _date,
          observations: _observationsController.text.isEmpty
              ? null
              : _observationsController.text,
          recurrence: _recurrence,
          account: _accountController.text.isEmpty ? null : _accountController.text,
          paymentMethod: _paymentMethod,
          isPaid: _isPaid,
          isInstallment: _isInstallment,
          installmentCount: _installmentCount,
          createdAt: _existing?.createdAt ?? DateTime.now(),
        );

        if (_existing != null) {
          await repo.updateTransaction(tx);
        } else {
          await repo.createTransaction(tx);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(transactionSuccessMessage(_type)),
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
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing != null ? 'Editar' : 'Nova movimentação'),
        actions: [
          if (_existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                await ref
                    .read(transactionRepositoryProvider)
                    .deleteTransaction(user.id, _existing!.id);
                if (mounted) context.pop();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Despesa'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = null;
              }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              inputFormatters: CurrencyFormatter.inputFormatters,
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                if (CurrencyFormatter.parse(v) == null) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),
            if (categories.hasError)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Não foi possível carregar categorias personalizadas.',
                    style: TextStyle(color: AppColors.expense),
                  ),
                ],
              )
            else
              CategorySelector(
                categories: categories.value ?? [],
                type: _type,
                selectedName: _resolveCategory(categories.value ?? []),
                onSelected: (name) => setState(() => _category = name),
                onCreateCategory: _createCategory,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Informe a descrição' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text(
                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: 'Conta (opcional)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurrenceType>(
              initialValue: _recurrence,
              decoration: const InputDecoration(labelText: 'Recorrência'),
              items: RecurrenceType.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_recurrenceLabel(r)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _recurrence = v!),
            ),
            if (_type == TransactionType.expense) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Forma de pagamento'),
                items: PaymentMethod.values
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(_paymentLabel(p)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pago'),
                value: _isPaid,
                onChanged: (v) => setState(() => _isPaid = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Parcelada'),
                value: _isInstallment,
                onChanged: (v) => setState(() => _isInstallment = v),
              ),
              if (_isInstallment)
                Row(
                  children: [
                    const Text('Parcelas:'),
                    Expanded(
                      child: Slider(
                        value: _installmentCount.toDouble(),
                        min: 2,
                        max: 24,
                        divisions: 22,
                        label: '$_installmentCount',
                        onChanged: (v) =>
                            setState(() => _installmentCount = v.toInt()),
                      ),
                    ),
                    Text('$_installmentCount'),
                  ],
                ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _observationsController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observações'),
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
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  String _recurrenceLabel(RecurrenceType r) => switch (r) {
        RecurrenceType.none => 'Nenhuma',
        RecurrenceType.daily => 'Diária',
        RecurrenceType.weekly => 'Semanal',
        RecurrenceType.monthly => 'Mensal',
        RecurrenceType.yearly => 'Anual',
      };

  String _paymentLabel(PaymentMethod p) => switch (p) {
        PaymentMethod.cash => 'Dinheiro',
        PaymentMethod.debit => 'Débito',
        PaymentMethod.credit => 'Crédito',
        PaymentMethod.pix => 'PIX',
        PaymentMethod.transfer => 'Transferência',
        PaymentMethod.other => 'Outro',
      };
}
