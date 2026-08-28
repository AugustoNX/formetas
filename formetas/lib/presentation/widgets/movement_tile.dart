import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/movement_entry.dart';

class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
  });

  final MovementEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  Color get _color => switch (entry.kind) {
        MovementKind.income => AppColors.income,
        MovementKind.expense => AppColors.expense,
        MovementKind.investment => AppColors.investment,
        MovementKind.transfer => AppColors.primary,
      };

  IconData get _icon => switch (entry.kind) {
        MovementKind.income => Icons.arrow_downward_rounded,
        MovementKind.expense => Icons.arrow_upward_rounded,
        MovementKind.investment => Icons.trending_up_rounded,
        MovementKind.transfer => Icons.swap_horiz_rounded,
      };

  String get _amountLabel {
    final formatted = CurrencyFormatter.format(entry.amount);
    return switch (entry.kind) {
      MovementKind.income => '+$formatted',
      MovementKind.expense => '-$formatted',
      MovementKind.investment => '-$formatted',
      MovementKind.transfer => formatted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction:
          onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
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
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon, color: _color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.subtitle} · ${AppDateUtils.formatDate(entry.date)}',
                        style: TextStyle(
                          color: AppColors.gray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _amountLabel,
                  style: TextStyle(
                    color: _color,
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
