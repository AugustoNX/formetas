import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.color,
    this.icon,
    this.compact = false,
  });

  final String title;
  final double value;
  final String? subtitle;
  final Color? color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? AppColors.primary;
    final isNegative = value < 0;

    return Container(
      width: double.infinity,
      alignment: Alignment.topLeft,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: displayColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: displayColor, size: compact ? 18 : 22),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            CurrencyFormatter.format(value),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isNegative ? AppColors.expense : displayColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.gray,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
