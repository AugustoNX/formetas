import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/category_entity.dart';
import '../../../domain/entities/statement_import.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../../domain/services/statement_importer.dart';
import '../../../domain/services/statement_parser.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

class StatementImportScreen extends ConsumerStatefulWidget {
  const StatementImportScreen({super.key});

  @override
  ConsumerState<StatementImportScreen> createState() =>
      _StatementImportScreenState();
}

class _StatementImportScreenState extends ConsumerState<StatementImportScreen> {
  static const _csvTypes = XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
    mimeTypes: [
      'text/csv',
      'text/comma-separated-values',
      'application/csv',
      'text/plain',
      'application/vnd.ms-excel',
    ],
  );

  StatementParseResult? _result;
  List<StatementEntry> _rows = const [];
  String? _fileName;
  bool _reading = false;
  bool _saving = false;

  List<CategoryEntity> get _categories =>
      ref.read(categoriesProvider).valueOrNull ?? const [];

  Future<void> _pick() async {
    final file = await openFile(acceptedTypeGroups: const [_csvTypes]);
    if (file == null || !mounted) return;
    if (!file.name.toLowerCase().endsWith('.csv')) {
      _snack('Envie apenas um arquivo CSV.');
      return;
    }

    setState(() {
      _reading = true;
      _result = null;
      _rows = const [];
      _fileName = file.name;
    });

    try {
      final bytes = await file.readAsBytes();
      final parsed = StatementParser.parse(StatementParser.decode(bytes));
      final existing = await _existingTransactions();
      if (!mounted) return;
      setState(() {
        _result = parsed;
        _rows = StatementParser.markDuplicates(parsed.entries, existing);
      });
    } catch (_) {
      if (mounted) _snack('Não foi possível ler o arquivo.');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<List<TransactionEntity>> _existingTransactions() async {
    try {
      return await ref.read(transactionsProvider.future);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _edit(int index) async {
    final updated = await showModalBottomSheet<StatementEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EditSheet(
        entry: _rows[index],
        incomeCategories: _names(TransactionType.income),
        expenseCategories: _names(TransactionType.expense),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _rows[index] = updated);
  }

  List<String> _names(TransactionType type) {
    final names = [
      for (final category in _categories)
        if (category.type == type) category.name,
    ];
    if (!names.contains('Outros')) names.add('Outros');
    return names;
  }

  String _categoryFor(TransactionType type, String current) {
    final names = _names(type);
    if (names.contains(current)) return current;
    return 'Outros';
  }

  void _setIncluded(bool included) {
    setState(() {
      _rows = [
        for (final row in _rows) row.copyWith(included: included),
      ];
    });
  }

  void _invertTypes() {
    setState(() {
      _rows = [
        for (final row in _rows)
          if (row.type != TransactionType.income &&
              row.type != TransactionType.expense)
            row
          else
            row.copyWith(
              type: row.type == TransactionType.income
                  ? TransactionType.expense
                  : TransactionType.income,
              category: _categoryFor(
                row.type == TransactionType.income
                    ? TransactionType.expense
                    : TransactionType.income,
                row.category,
              ),
            ),
      ];
    });
  }

  Future<void> _confirm() async {
    final selected = _rows.where((row) => row.included).toList();
    if (selected.isEmpty) {
      _snack('Selecione ao menos um lançamento.');
      return;
    }
    if (selected.any((row) => row.description.trim().isEmpty || row.amount <= 0)) {
      _snack('Preencha descrição e valor dos lançamentos marcados.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final transactions = StatementImporter.build(
        userId: user.id,
        entries: [
          for (final row in selected)
            row.copyWith(category: _categoryFor(row.type, row.category)),
        ],
        nextId: const Uuid().v4,
      );
      await ref.read(transactionRepositoryProvider).createTransactions(transactions);
      if (!mounted) return;

      final latest = selected.map((row) => row.date).reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
      ref.read(selectedMonthProvider.notifier).state =
          DateTime(latest.year, latest.month);

      final count = transactions.length;
      _snack(
        count == 1 ? '1 lançamento importado.' : '$count lançamentos importados.',
      );
      context.pop();
    } catch (_) {
      if (mounted) _snack('Não foi possível salvar o extrato.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(categoriesProvider);
    final result = _result;
    final ready = result != null &&
        !result.failed &&
        (_rows.isNotEmpty || result.rejected.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(ready ? 'Conferir extrato' : 'Importar CSV'),
        actions: [
          if (ready)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'file':
                    _pick();
                  case 'all':
                    _setIncluded(true);
                  case 'none':
                    _setIncluded(false);
                  case 'invert':
                    _invertTypes();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'file', child: Text('Escolher outro CSV')),
                PopupMenuItem(value: 'all', child: Text('Marcar todos')),
                PopupMenuItem(value: 'none', child: Text('Desmarcar todos')),
                PopupMenuItem(
                  value: 'invert',
                  child: Text('Inverter receitas e despesas'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _reading
                ? const Center(child: CircularProgressIndicator())
                : ready
                    ? _ReviewBody(
                        result: result,
                        rows: _rows,
                        fileName: _fileName,
                        incomeCategories: _names(TransactionType.income),
                        expenseCategories: _names(TransactionType.expense),
                        onToggle: (index, included) => setState(() {
                          _rows[index] = _rows[index].copyWith(included: included);
                        }),
                        onCategory: (index, category) => setState(() {
                          _rows[index] = _rows[index].copyWith(category: category);
                        }),
                        onEdit: _edit,
                      )
                    : _EmptyState(
                        message: result?.message,
                        fileName: _fileName,
                        onPick: _pick,
                      ),
          ),
        ),
      ),
      bottomNavigationBar: ready && _rows.isNotEmpty
          ? _ConfirmBar(
              rows: _rows,
              saving: _saving,
              onConfirm: _confirm,
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onPick,
    this.message,
    this.fileName,
  });

  final VoidCallback onPick;
  final String? message;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file_rounded,
            size: 56,
            color: AppColors.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 16),
          Text(
            'Extrato do banco',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Envie o CSV exportado pela conta. O app separa data, valor e descrição e só grava depois da sua conferência.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray, height: 1.4),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              fileName == null ? message! : '$fileName\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.expense, height: 1.35),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.folder_open_rounded),
            label: Text(message == null ? 'Escolher CSV' : 'Escolher outro CSV'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(220, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.result,
    required this.rows,
    required this.fileName,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.onToggle,
    required this.onCategory,
    required this.onEdit,
  });

  final StatementParseResult result;
  final List<StatementEntry> rows;
  final String? fileName;
  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final void Function(int index, bool included) onToggle;
  final void Function(int index, String category) onCategory;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final rejected = result.rejected;
    final header = rejected.isNotEmpty ? 1 : 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _MappingBanner(result: result, fileName: fileName),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: rows.length + header,
            itemBuilder: (context, index) {
              if (header == 1 && index == 0) {
                return _RejectedBlock(rejected: rejected);
              }
              final rowIndex = index - header;
              final row = rows[rowIndex];
              return _RowCard(
                row: row,
                categories: row.type == TransactionType.income
                    ? incomeCategories
                    : expenseCategories,
                onToggle: (included) => onToggle(rowIndex, included),
                onCategory: (category) => onCategory(rowIndex, category),
                onEdit: () => onEdit(rowIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MappingBanner extends StatelessWidget {
  const _MappingBanner({required this.result, required this.fileName});

  final StatementParseResult result;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final columns = [
      if (result.dateColumn != null) result.dateColumn!,
      if (result.descriptionColumn != null) result.descriptionColumn!,
      if (result.amountColumn != null) result.amountColumn!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileName != null)
            Text(
              fileName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (columns.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Colunas lidas: ${columns.join(' · ')}',
              style: TextStyle(color: AppColors.gray, fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Valor positivo entra como receita. Valor negativo entra como despesa.',
            style: TextStyle(color: AppColors.gray, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.row,
    required this.categories,
    required this.onToggle,
    required this.onCategory,
    required this.onEdit,
  });

  final StatementEntry row;
  final List<String> categories;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onCategory;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final income = row.type == TransactionType.income;
    final color = income ? AppColors.income : AppColors.expense;
    final missing = row.description.trim().isEmpty;
    final options = [
      ...categories.where((name) => name.trim().isNotEmpty),
      if (!categories.contains('Outros')) 'Outros',
    ];
    final selected = options.contains(row.category) ? row.category : 'Outros';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: row.included,
              onChanged: (value) => onToggle(value ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8, right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onEdit,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppDateUtils.formatDate(row.date),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                income ? 'Receita' : 'Despesa',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${income ? '+' : '-'}${CurrencyFormatter.format(row.amount)}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            missing ? 'Sem descrição' : row.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: missing ? AppColors.expense : null,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('${row.line}-${row.type.name}-$selected'),
                      initialValue: selected,
                      isExpanded: true,
                      icon: const Icon(Icons.expand_more_rounded),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Categoria',
                        filled: true,
                        fillColor: AppColors.primary.withValues(alpha: 0.08),
                        prefixIcon: const Icon(
                          Icons.sell_outlined,
                          color: AppColors.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.45),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.6,
                          ),
                        ),
                      ),
                      items: [
                        for (final name in options)
                          DropdownMenuItem(
                            value: name,
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null || value == selected) return;
                        onCategory(value);
                      },
                    ),
                    if (row.duplicate) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Já lançado',
                        style: TextStyle(
                          color: AppColors.gray,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedBlock extends StatelessWidget {
  const _RejectedBlock({required this.rejected});

  final List<StatementRejection> rejected;

  @override
  Widget build(BuildContext context) {
    final shown = rejected.take(30).toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text('${rejected.length} linhas ignoradas'),
        subtitle: const Text('Data ou valor não puderam ser lidos'),
        children: [
          for (final item in shown)
            ListTile(
              dense: true,
              title: Text('Linha ${item.line} · ${item.reason}'),
              subtitle: Text(
                item.raw,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (rejected.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'e mais ${rejected.length - shown.length}',
                style: TextStyle(color: AppColors.gray),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.rows,
    required this.saving,
    required this.onConfirm,
  });

  final List<StatementEntry> rows;
  final bool saving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final selected = rows.where((row) => row.included).toList();
    final income = selected
        .where((row) => row.type == TransactionType.income)
        .fold(0.0, (sum, row) => sum + row.amount);
    final expense = selected
        .where((row) => row.type == TransactionType.expense)
        .fold(0.0, (sum, row) => sum + row.amount);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${selected.length} de ${rows.length} selecionados · '
              'receitas ${CurrencyFormatter.format(income)} · '
              'despesas ${CurrencyFormatter.format(expense)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray, fontSize: 13),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: saving || selected.isEmpty ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      selected.length == 1
                          ? 'Importar 1 lançamento'
                          : 'Importar ${selected.length} lançamentos',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.entry,
    required this.incomeCategories,
    required this.expenseCategories,
  });

  final StatementEntry entry;
  final List<String> incomeCategories;
  final List<String> expenseCategories;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late DateTime _date;
  late TransactionType _type;
  late String _category;
  late bool _included;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.entry.description);
    _amount = TextEditingController(
      text: CurrencyFormatter.formatForInput(widget.entry.amount),
    );
    _date = widget.entry.date;
    _type = widget.entry.type == TransactionType.income
        ? TransactionType.income
        : TransactionType.expense;
    _category = _keptCategory(_type, widget.entry.category);
    _included = widget.entry.included;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<String> _options(TransactionType type) {
    final source = type == TransactionType.income
        ? widget.incomeCategories
        : widget.expenseCategories;
    return source.isEmpty ? const ['Outros'] : source;
  }

  String _keptCategory(TransactionType type, String current) {
    final options = _options(type);
    if (options.contains(current)) return current;
    return options.contains('Outros') ? 'Outros' : options.first;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final amount = CurrencyFormatter.parse(_amount.text) ?? 0;
    if (amount <= 0 || _description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe descrição e valor.')),
      );
      return;
    }
    Navigator.pop(
      context,
      widget.entry.copyWith(
        date: _date,
        amount: amount,
        type: _type,
        description: _description.text.trim(),
        category: _category,
        included: _included,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _options(_type);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lançamento',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(value: TransactionType.income, label: Text('Receita')),
              ButtonSegment(value: TransactionType.expense, label: Text('Despesa')),
            ],
            selected: {_type},
            onSelectionChanged: (value) {
              final type = value.first;
              setState(() {
                _type = type;
                _category = _keptCategory(type, _category);
              });
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(AppDateUtils.formatDate(_date)),
            trailing: const Icon(Icons.calendar_today_rounded, size: 18),
            onTap: _pickDate,
          ),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: CurrencyFormatter.inputFormatters,
            decoration: const InputDecoration(
              labelText: 'Valor',
              prefixText: 'R\$ ',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('${_type.name}-$_category'),
            initialValue: options.contains(_category) ? _category : options.first,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              for (final name in options)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) {
              if (value == null || value == _category) return;
              setState(() => _category = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Importar este lançamento'),
            value: _included,
            onChanged: (value) => setState(() => _included = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }
}
