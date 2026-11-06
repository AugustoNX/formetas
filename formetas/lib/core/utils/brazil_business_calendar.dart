abstract final class BrazilBusinessCalendar {
  static bool isBusinessDay(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      return false;
    }
    return !_holidays(day.year).contains(day);
  }

  /// Número do dia útil no mês. Nulo quando a própria data não é dia útil.
  static int? businessDayNumber(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (!isBusinessDay(day)) return null;

    var count = 0;
    for (var cursor = DateTime(day.year, day.month, 1);
        !cursor.isAfter(day);
        cursor = cursor.add(const Duration(days: 1))) {
      if (isBusinessDay(cursor)) count++;
    }
    return count;
  }

  static Set<DateTime> _holidays(int year) {
    final easter = _easter(year);
    final goodFriday = easter.subtract(const Duration(days: 2));
    return {
      DateTime(year, 1, 1),
      goodFriday,
      DateTime(year, 4, 21),
      DateTime(year, 5, 1),
      DateTime(year, 9, 7),
      DateTime(year, 10, 12),
      DateTime(year, 11, 2),
      DateTime(year, 11, 15),
      DateTime(year, 12, 25),
    };
  }

  static DateTime _easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}
