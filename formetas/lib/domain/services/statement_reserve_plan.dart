import '../entities/statement_import.dart';

abstract final class StatementReservePlan {
  static double openingShortfall({
    required double current,
    required List<StatementEntry> entries,
  }) {
    final ordered = [...entries]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.line.compareTo(b.line);
      });

    var running = current;
    var lowest = current;
    for (final entry in ordered) {
      if (!entry.included) continue;
      running += switch (entry.role) {
        StatementRole.toReserve => entry.amount,
        StatementRole.fromReserve => -entry.amount,
        StatementRole.transaction ||
        StatementRole.ownTransfer ||
        StatementRole.ignored =>
          0,
      };
      if (running < lowest) lowest = running;
    }
    return lowest < 0 ? -lowest : 0;
  }
}
