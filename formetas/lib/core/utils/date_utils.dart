import 'package:intl/intl.dart';

abstract final class AppDateUtils {
  static final _monthYear = DateFormat('MMMM yyyy', 'pt_BR');
  static final _dayMonth = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _monthShort = DateFormat('MMM', 'pt_BR');

  static String formatMonthYear(DateTime date) => _monthYear.format(date);

  static String formatDate(DateTime date) => _dayMonth.format(date);

  static String formatMonthShort(DateTime date) => _monthShort.format(date);

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59);

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static DateTime parseMonthKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  static List<DateTime> last12Months([DateTime? from]) {
    final base = from ?? DateTime.now();
    return List.generate(
      12,
      (i) => DateTime(base.year, base.month - i),
    ).reversed.toList();
  }
}
