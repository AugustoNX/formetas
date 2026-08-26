import '../constants/app_constants.dart';
import '../../domain/entities/reserve_entity.dart';
import '../../domain/entities/reserve_movement_entity.dart';
import 'investment_calculator.dart';

abstract final class ReserveCalculator {
  static InvestmentYieldResult compute({
    required ReserveEntity reserve,
    required List<ReserveMovementEntity> movements,
    required double cdiRate,
    DateTime? referenceDate,
  }) {
    final events = <DateTime, double>{};

    void addEvent(DateTime date, double amount) {
      if (amount == 0) return;
      final key = DateTime(date.year, date.month, date.day);
      events[key] = (events[key] ?? 0) + amount;
    }

    if (reserve.initialValue > 0) {
      addEvent(reserve.startDate, reserve.initialValue);
    }

    for (final movement in movements) {
      final signed = movement.type == ReserveMovementType.deposit
          ? movement.amount
          : -movement.amount;
      addEvent(movement.date, signed);
    }

    if (events.isEmpty) {
      return const InvestmentYieldResult(
        currentValue: 0,
        dailyYield: 0,
        monthlyYield: 0,
        annualYield: 0,
        totalAccumulated: 0,
      );
    }

    final startDate = events.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final now = referenceDate ?? DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final days = endDate.difference(startDate).inDays.clamp(0, 36500);

    final annualRate = reserve.fixedRate != null
        ? reserve.fixedRate! / 100
        : (cdiRate / 100) * ((reserve.cdiPercent ?? 100) / 100);

    final dailyRate = _compoundDailyRate(annualRate);
    var current = 0.0;
    var netPrincipal = 0.0;

    for (var d = 0; d <= days; d++) {
      final day = startDate.add(Duration(days: d));
      final dayKey = DateTime(day.year, day.month, day.day);
      final eventAmount = events[dayKey];
      if (eventAmount != null) {
        current += eventAmount;
        netPrincipal += eventAmount;
      }
      if (d < days) {
        current *= (1 + dailyRate);
      }
    }

    current = current.clamp(0, double.infinity);
    final totalAccumulated = current - netPrincipal;
    final dailyYield = current * dailyRate;
    final monthlyRate = _compoundMonthlyRate(annualRate);
    final monthlyYield = current * monthlyRate;
    final annualYield = current * annualRate;

    return InvestmentYieldResult(
      currentValue: current,
      dailyYield: dailyYield,
      monthlyYield: monthlyYield,
      annualYield: annualYield,
      totalAccumulated: totalAccumulated,
    );
  }

  static double maxWithdrawal({
    required ReserveEntity reserve,
    required List<ReserveMovementEntity> movements,
    required double cdiRate,
    DateTime? referenceDate,
  }) {
    return compute(
      reserve: reserve,
      movements: movements,
      cdiRate: cdiRate,
      referenceDate: referenceDate,
    ).currentValue;
  }

  static double _compoundDailyRate(double annualRate) =>
      (1 + annualRate).pow(1 / AppConstants.daysInYear) - 1;

  static double _compoundMonthlyRate(double annualRate) =>
      (1 + annualRate).pow(1 / 12) - 1;
}

extension on double {
  double pow(double exponent) {
    if (this <= 0) return 0;
    return _pow(this, exponent);
  }
}

double _pow(double base, double exponent) {
  if (base == 0) return 0;
  return base == 1 ? 1 : _exp(exponent * _ln(base));
}

double _ln(double x) {
  if (x <= 0) return double.negativeInfinity;
  var y = 0.0;
  var z = (x - 1) / (x + 1);
  var z2 = z * z;
  var term = z;
  for (var i = 1; i < 100; i += 2) {
    y += term / i;
    term *= z2;
  }
  return 2 * y;
}

double _exp(double x) {
  var sum = 1.0;
  var term = 1.0;
  for (var i = 1; i < 50; i++) {
    term *= x / i;
    sum += term;
  }
  return sum;
}
