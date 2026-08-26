import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  final TransactionEntity transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  Color get _typeColor {
    switch (transaction.type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.investment:
        return AppColors.investment;
    }
  }

  IconData get _typeIcon {
    switch (transaction.type) {
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.investment:
        return Icons.trending_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefix = transaction.type == TransactionType.income ? '+' : '-';

    return Dismissible(
      key: Key(transaction.id),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description.isNotEmpty
                            ? transaction.description
                            : transaction.category,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${transaction.category} · ${AppDateUtils.formatDate(transaction.date)}',
                        style: TextStyle(
                          color: AppColors.gray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix${CurrencyFormatter.format(transaction.value)}',
                  style: TextStyle(
                    color: _typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMessageBanner extends StatelessWidget {
  const BrandMessageBanner({
    super.key,
    required this.message,
    this.positive = true,
  });

  final String message;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: positive
            ? AppColors.secondary.withValues(alpha: 0.12)
            : AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: positive
              ? AppColors.secondary.withValues(alpha: 0.3)
              : AppColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            positive ? Icons.eco_rounded : Icons.lightbulb_outline_rounded,
            color: positive ? AppColors.secondary : AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String transactionSuccessMessage(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return AppStrings.incomeSuccess;
    case TransactionType.expense:
      return AppStrings.expenseSuccess;
    case TransactionType.investment:
      return AppStrings.investSuccess;
  }
}
