import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/statement_import.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/ml/classifier_thresholds.dart';
import '../../domain/services/ml/smart_categorizer.dart';

/// Lista de revisão do extrato: selo da origem, confiança e linhas parecidas.
class StatementImportReview extends StatelessWidget {
  const StatementImportReview({
    super.key,
    required this.rejected,
    required this.rows,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.onToggle,
    required this.onCategory,
    required this.onRole,
    required this.onEdit,
    required this.onApplySimilar,
  });

  final List<StatementRejection> rejected;
  final List<CategorizedEntry> rows;
  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final void Function(int index, bool included) onToggle;
  final void Function(int index, String category) onCategory;
  final void Function(int index, StatementRole role) onRole;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onApplySimilar;

  @override
  Widget build(BuildContext context) {
    final review = <int>[];
    final rest = <int>[];
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].needsReview) {
        review.add(i);
      } else {
        rest.add(i);
      }
    }

    final slots = <Object>[
      if (rejected.isNotEmpty) rejected,
      if (review.isNotEmpty && rest.isNotEmpty) 'Para revisar',
      ...review,
      if (review.isNotEmpty && rest.isNotEmpty) 'O restante',
      ...rest,
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        if (slot is List<StatementRejection>) {
          return _RejectedBlock(rejected: slot);
        }
        if (slot is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              slot,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        }
        final rowIndex = slot as int;
        final row = rows[rowIndex];
        return _LineCard(
          line: row,
          categories: row.entry.type == TransactionType.income
              ? incomeCategories
              : expenseCategories,
          onToggle: (included) => onToggle(rowIndex, included),
          onCategory: (category) => onCategory(rowIndex, category),
          onRole: (role) => onRole(rowIndex, role),
          onEdit: () => onEdit(rowIndex),
          onApplySimilar: () => onApplySimilar(rowIndex),
          onWhy: () => _why(context, rowIndex),
        );
      },
    );
  }

  Future<void> _why(BuildContext context, int index) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _WhySheet(line: rows[index]),
    );
    if (picked != null) onCategory(index, picked);
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.categories,
    required this.onToggle,
    required this.onCategory,
    required this.onRole,
    required this.onEdit,
    required this.onApplySimilar,
    required this.onWhy,
  });

  final CategorizedEntry line;
  final List<String> categories;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onCategory;
  final ValueChanged<StatementRole> onRole;
  final VoidCallback onEdit;
  final VoidCallback onApplySimilar;
  final VoidCallback onWhy;

  @override
  Widget build(BuildContext context) {
    final row = line.entry;
    final income = row.type == TransactionType.income;
    final moneyIn = switch (row.role) {
      StatementRole.fromReserve => true,
      StatementRole.toReserve => false,
      StatementRole.ownTransfer || StatementRole.ignored => income,
      StatementRole.transaction => income,
    };
    final color = moneyIn ? AppColors.income : AppColors.expense;
    final kindLabel = switch (row.role) {
      StatementRole.toReserve => 'Para a caixinha',
      StatementRole.fromReserve => 'Da caixinha',
      StatementRole.ownTransfer => 'Entre suas contas',
      StatementRole.ignored => 'Não entra no mês',
      StatementRole.transaction => income ? 'Receita' : 'Despesa',
    };
    final kindColor = switch (row.role) {
      StatementRole.transaction => color,
      StatementRole.ignored || StatementRole.ownTransfer => AppColors.gray,
      StatementRole.toReserve || StatementRole.fromReserve => AppColors.reserve,
    };
    final missing = row.description.trim().isEmpty;
    final options = <String>[
      for (final name in categories)
        if (name.trim().isNotEmpty) name,
    ];
    if (row.category.trim().isNotEmpty && !options.contains(row.category)) {
      options.insert(0, row.category);
    }
    if (!options.contains('Outros')) options.add('Outros');
    final selected = options.contains(row.category) ? row.category : null;
    final changed =
        row.category.trim().isNotEmpty &&
        (line.suggestedCategory == null ||
            row.category.trim() != line.suggestedCategory);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: line.needsReview ? const Color(0xFFFFF1E6) : null,
      shape: line.needsReview
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.85)),
            )
          : null,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                kindLabel,
                                style: TextStyle(
                                  color: kindColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${moneyIn ? '+' : '-'}${CurrencyFormatter.format(row.amount)}',
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _SourceBadge(
                          key: ValueKey('source-badge-${row.line}'),
                          label: _sourceLabel(line.source),
                          onTap: onWhy,
                        ),
                        Text(
                          _confidenceLabel(line.confidence),
                          style: TextStyle(
                            color: _confidenceColor(line.confidence),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<StatementRole>(
                      key: ValueKey('role-${row.line}-${row.role.name}'),
                      initialValue: row.role,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.primary,
                      ),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      decoration: _choiceDecoration('Identificação'),
                      items: const [
                        DropdownMenuItem(
                          value: StatementRole.transaction,
                          child: Text('Lançamento'),
                        ),
                        DropdownMenuItem(
                          value: StatementRole.toReserve,
                          child: Text('Aplicação na caixinha'),
                        ),
                        DropdownMenuItem(
                          value: StatementRole.fromReserve,
                          child: Text('Resgate da caixinha'),
                        ),
                        DropdownMenuItem(
                          value: StatementRole.ownTransfer,
                          child: Text('Entre suas contas'),
                        ),
                        DropdownMenuItem(
                          value: StatementRole.ignored,
                          child: Text('Não lançar'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null || value == row.role) return;
                        onRole(value);
                      },
                    ),
                    if (row.role == StatementRole.transaction) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'category-${row.line}-${row.type.name}-$selected',
                        ),
                        initialValue: selected,
                        isExpanded: true,
                        hint: const Text('Escolher'),
                        icon: const Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.primary,
                        ),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        decoration: _choiceDecoration('Categoria'),
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
                    ],
                    if (changed)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey('apply-similar-${row.line}'),
                          onPressed: onApplySimilar,
                          child: const Text('Aplicar a todas parecidas'),
                        ),
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

class _WhySheet extends StatelessWidget {
  const _WhySheet({required this.line});

  final CategorizedEntry line;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final current = line.entry.category.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Por que essa categoria?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            current.isEmpty ? 'Sem categoria ainda' : current,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (line.reasons.isEmpty)
            Text(
              'Sem um motivo forte ainda.',
              style: TextStyle(color: AppColors.gray, height: 1.35),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in line.reasons)
                  Chip(
                    label: Text(reason),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          if (line.alternatives.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Outras possibilidades',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final alternative in line.alternatives)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(alternative.category),
                trailing: Text('${(alternative.confidence * 100).round()}%'),
                onTap: () => Navigator.pop(context, alternative.category),
              ),
          ],
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
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

InputDecoration _choiceDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
    floatingLabelStyle: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: const Color(0xFFD7E8DC),
    prefixIcon: const Icon(Icons.sell_outlined, color: AppColors.primary),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.secondary, width: 1.4),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
    ),
  );
}

String _sourceLabel(SuggestionSource source) {
  return switch (source) {
    SuggestionSource.regra => 'Regra',
    SuggestionSource.recorrente => 'Recorrente',
    SuggestionSource.aprendido => 'Aprendi',
    SuggestionSource.heuristica => 'Sugestão',
    SuggestionSource.nenhuma => 'Escolher',
  };
}

String _confidenceLabel(double value) {
  if (value >= ClassifierThresholds.highConfidence) return 'Alta';
  if (value >= ClassifierThresholds.mediumConfidence) return 'Média';
  return 'Baixa';
}

Color _confidenceColor(double value) {
  if (value >= ClassifierThresholds.highConfidence) return AppColors.income;
  if (value >= ClassifierThresholds.mediumConfidence) return AppColors.gold;
  return AppColors.expense;
}
