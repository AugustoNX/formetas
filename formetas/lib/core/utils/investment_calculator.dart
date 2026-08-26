import '../constants/app_constants.dart';

class InvestmentYieldResult {
  const InvestmentYieldResult({
    required this.currentValue,
    required this.dailyYield,
    required this.monthlyYield,
    required this.annualYield,
    required this.totalAccumulated,
  });

  final double currentValue;
  final double dailyYield;
  final double monthlyYield;
  final double annualYield;
  final double totalAccumulated;
}

abstract final class InvestmentCalculator {
  static InvestmentYieldResult calculate({
    required double initialValue,
    required DateTime startDate,
    required double cdiRate,
    double? cdiPercent,
    double? fixedRate,
    double monthlyContribution = 0,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final days = now.difference(startDate).inDays.clamp(0, 36500);

    final annualRate = fixedRate != null
        ? fixedRate / 100
        : (cdiRate / 100) * ((cdiPercent ?? 100) / 100);

    final dailyRate = _compoundDailyRate(annualRate);
    var current = initialValue;
    var totalContributions = initialValue;

    for (var d = 0; d < days; d++) {
      current *= (1 + dailyRate);
      if (d > 0 && d % AppConstants.daysInMonth == 0 && monthlyContribution > 0) {
        current += monthlyContribution;
        totalContributions += monthlyContribution;
      }
    }

    final totalAccumulated = current - totalContributions;
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
