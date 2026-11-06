import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/insight.dart';
import '../formetas_card.dart';
import 'insight_mini_chart.dart';
import 'insight_style.dart';

/// Card de insight: toque para expandir (detalhes + mini gráfico + ações),
/// deslize para dispensar.
class InsightCard extends StatefulWidget {
  const InsightCard({
    super.key,
    required this.insight,
    required this.onDismiss,
    this.onAction,
    this.initiallyExpanded = false,
  });

  final Insight insight;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;
  final bool initiallyExpanded;

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final color = InsightStyle.color(insight.severity);
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('insight-${insight.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.gray.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_rounded, color: AppColors.gray),
            SizedBox(width: 6),
            Text('Dispensar', style: TextStyle(color: AppColors.gray)),
          ],
        ),
      ),
      child: FormetasCard(
        padding: const EdgeInsets.all(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(InsightStyle.icon(insight.type), color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (insight.periodLabel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            insight.periodLabel!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          insight.message,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.gray, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.expand_more_rounded, color: AppColors.gray),
                  ),
                ],
              ),
              if (_expanded) ...[
                if (insight.series.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InsightMiniChart(points: insight.series, color: color),
                ],
                if (insight.details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final line in insight.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                          ),
                          Expanded(child: Text(line, style: theme.textTheme.bodySmall)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('Dispensar'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.gray),
                    ),
                    if (insight.action != null && widget.onAction != null) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: widget.onAction,
                        icon: Icon(
                          insight.action!.type == InsightActionType.createTrail
                              ? Icons.route_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        label: Text(insight.action!.label),
                        style: FilledButton.styleFrom(backgroundColor: color),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
