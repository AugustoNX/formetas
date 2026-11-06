import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/utils/balance_cutoff.dart';
import 'package:formetas/core/utils/reserve_calculator.dart';
import 'package:formetas/data/models/settings_model.dart';
import 'package:formetas/domain/entities/reserve_entity.dart';
import 'package:formetas/domain/entities/reserve_movement_entity.dart';
import 'package:formetas/domain/entities/settings_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/dashboard_service.dart';

void main() {
  final cutoff = DateTime(2026, 11, 5);
  const settings = SettingsEntity();

  TransactionEntity tx({
    required String id,
    required TransactionType type,
    required double value,
    required DateTime date,
  }) {
    return TransactionEntity(
      id: id,
      userId: 'u',
      type: type,
      category: 'Geral',
      value: value,
      description: '',
      date: date,
      createdAt: date,
    );
  }

  test('lançamento anterior ao saldo informado não mexe no saldo atual', () {
    final opening = tx(
      id: 'o',
      type: TransactionType.opening,
      value: 100,
      date: cutoff,
    );
    final before = tx(
      id: 'old',
      type: TransactionType.expense,
      value: 40,
      date: DateTime(2026, 11, 4),
    );
    final after = tx(
      id: 'new',
      type: TransactionType.income,
      value: 10,
      date: DateTime(2026, 11, 6),
    );
    final sameDay = tx(
      id: 'today',
      type: TransactionType.expense,
      value: 5,
      date: cutoff,
    );

    final stats = DashboardService().compute(
      transactions: [opening, before, after, sameDay],
      investments: const [],
      reservesWithMovements: const [],
      transfers: const [],
      settings: settings.copyWith(balanceAsOf: cutoff),
      selectedMonth: DateTime(2026, 11, 1),
    );

    expect(stats.totalBalance, closeTo(105, 0.01));
    expect(stats.monthlyIncome, 10);
    expect(stats.monthlyExpense, 5);
  });

  test('sem data salva, a abertura da conta serve de corte', () {
    final opening = tx(
      id: 'o',
      type: TransactionType.opening,
      value: 100,
      date: cutoff,
    );
    final before = tx(
      id: 'old',
      type: TransactionType.expense,
      value: 40,
      date: DateTime(2026, 11, 4),
    );

    expect(BalanceCutoff.resolve(transactions: [opening, before]), cutoff);

    final stats = DashboardService().compute(
      transactions: [opening, before],
      investments: const [],
      reservesWithMovements: const [],
      transfers: const [],
      settings: settings,
      selectedMonth: DateTime(2026, 11, 1),
    );
    expect(stats.totalBalance, closeTo(100, 0.01));
  });

  test('saldo zero ainda impede que o passado altere a conta', () {
    final stats = DashboardService().compute(
      transactions: [
        tx(
          id: 'old',
          type: TransactionType.expense,
          value: 40,
          date: DateTime(2026, 11, 4),
        ),
        tx(
          id: 'new',
          type: TransactionType.income,
          value: 15,
          date: DateTime(2026, 11, 6),
        ),
      ],
      investments: const [],
      reservesWithMovements: const [],
      transfers: const [],
      settings: settings.copyWith(balanceAsOf: cutoff),
      selectedMonth: DateTime(2026, 11, 1),
    );

    expect(stats.totalBalance, closeTo(15, 0.01));
  });

  test('saque anterior ao início da caixinha não reduz o valor de hoje', () {
    final reserve = ReserveEntity(
      id: 'r',
      userId: 'u',
      name: 'Emergência',
      type: ReserveType.caixinha,
      initialValue: 100,
      currentValue: 100,
      startDate: cutoff,
      createdAt: cutoff,
    );
    final result = ReserveCalculator.compute(
      reserve: reserve,
      movements: [
        ReserveMovementEntity(
          id: 'm1',
          reserveId: 'r',
          userId: 'u',
          type: ReserveMovementType.withdrawal,
          amount: 30,
          date: DateTime(2026, 11, 4),
          createdAt: DateTime(2026, 11, 4),
        ),
        ReserveMovementEntity(
          id: 'm2',
          reserveId: 'r',
          userId: 'u',
          type: ReserveMovementType.deposit,
          amount: 20,
          date: DateTime(2026, 11, 6),
          createdAt: DateTime(2026, 11, 6),
        ),
      ],
      cdiRate: 0,
      referenceDate: DateTime(2026, 11, 6),
    );

    expect(result.currentValue, closeTo(120, 0.01));
  });

  test('a data do saldo vai e volta nas configurações', () {
    final saved = SettingsModel.fromEntity(
      const SettingsEntity().copyWith(balanceAsOf: DateTime(2026, 11, 5)),
    ).toMap();
    final loaded = SettingsModel.fromMap(saved);

    expect(loaded.balanceAsOf, isNotNull);
    expect(BalanceCutoff.day(loaded.balanceAsOf!), DateTime(2026, 11, 5));
    expect(saved.containsKey('saldoEm'), isTrue);
  });
}
