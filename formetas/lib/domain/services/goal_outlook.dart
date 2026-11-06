import '../../core/utils/currency_formatter.dart';
import '../../core/utils/reserve_calculator.dart';
import '../entities/goal_entity.dart';
import '../entities/reserve_movement_entity.dart';

class GoalOutlook {
  const GoalOutlook({required this.current, this.message});

  final double current;
  final String? message;
}

abstract final class GoalOutlooks {
  static GoalOutlook build({
    required GoalEntity goal,
    ReserveWithMovements? reserve,
    required double cdiRate,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final current = reserve == null
        ? goal.currentValue
        : ReserveCalculator.compute(
            reserve: reserve.reserve,
            movements: reserve.movements,
            cdiRate: cdiRate,
            referenceDate: today,
          ).currentValue;
    final remaining = goal.targetValue - current;
    if (remaining <= 0) {
      return GoalOutlook(current: current);
    }

    final pace = reserve == null
        ? 0.0
        : _monthlyPace(reserve.movements, goal.createdAt, today);
    if (pace > 0) {
      final months = (remaining / pace).ceil();
      final arrival = DateTime(today.year, today.month + months, 1);
      final label = '${_monthName(arrival.month)} de ${arrival.year}';
      return GoalOutlook(
        current: current,
        message: 'No ritmo atual, você chega em $label.',
      );
    }

    final monthsLeft = _monthsUntil(today, goal.targetDate);
    final needed = remaining / monthsLeft;
    return GoalOutlook(
      current: current,
      message: 'Faltam ${CurrencyFormatter.format(needed)} por mês.',
    );
  }

  static double _monthlyPace(
    List<ReserveMovementEntity> movements,
    DateTime since,
    DateTime now,
  ) {
    final months = _monthsUntil(since, now);
    final net = movements.where((movement) => !movement.date.isBefore(since)).fold(
          0.0,
          (sum, movement) =>
              sum +
              (movement.type == ReserveMovementType.deposit
                  ? movement.amount
                  : -movement.amount),
        );
    return net / months;
  }

  static int _monthsUntil(DateTime from, DateTime to) {
    final months = (to.year - from.year) * 12 + to.month - from.month;
    return months < 1 ? 1 : months;
  }

  static String _monthName(int month) {
    return const [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ][month - 1];
  }
}
