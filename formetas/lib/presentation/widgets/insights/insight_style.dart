import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/insight.dart';

/// Cor e ícone de cada insight, num lugar só.
abstract final class InsightStyle {
  static Color color(InsightSeverity severity) => switch (severity) {
        InsightSeverity.alert => AppColors.expense,
        InsightSeverity.warning => AppColors.accent,
        InsightSeverity.info => AppColors.investment,
        InsightSeverity.positive => AppColors.income,
      };

  static IconData icon(InsightType type) => switch (type) {
        InsightType.monthForecast => Icons.query_stats_rounded,
        InsightType.categorySpike => Icons.trending_up_rounded,
        InsightType.categoryDrop => Icons.trending_down_rounded,
        InsightType.categoryTrend => Icons.show_chart_rounded,
        InsightType.unusualExpense => Icons.priority_high_rounded,
        InsightType.smallPurchases => Icons.grain_rounded,
        InsightType.subscriptions => Icons.autorenew_rounded,
        InsightType.savingsRate => Icons.savings_rounded,
        InsightType.incomeArrival => Icons.payments_rounded,
        InsightType.goalPace => Icons.flag_rounded,
      };
}
