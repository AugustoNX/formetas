import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/insight_providers.dart';
import '../formetas_card.dart';
import 'insight_style.dart';

/// Resumo compacto no dashboard: o insight mais importante + atalho.
class InsightsPreviewCard extends ConsumerWidget {
  const InsightsPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider).valueOrNull ?? const [];
    final trails = ref.watch(activeTrailsProgressProvider);
    if (insights.isEmpty && trails.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final top = insights.isEmpty ? null : insights.first;
    final color = top == null ? AppColors.secondary : InsightStyle.color(top.severity);
    final extra = [
      if (insights.length > 1) '+${insights.length - 1} insights',
      if (trails.isNotEmpty) '${trails.length} trilha${trails.length > 1 ? 's' : ''} ativa${trails.length > 1 ? 's' : ''}',
    ].join(' · ');

    return FormetasCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/insights'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              top == null ? Icons.route_rounded : InsightStyle.icon(top.type),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  top?.title ?? 'Suas trilhas estão em andamento',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  top?.message ?? 'Toque para ver o progresso da semana.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.gray),
                ),
                if (extra.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    extra,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
        ],
      ),
    );
  }
}
