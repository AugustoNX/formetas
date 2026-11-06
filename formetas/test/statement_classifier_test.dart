import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/utils/brazil_business_calendar.dart';
import 'package:formetas/domain/entities/import_rule.dart';
import 'package:formetas/domain/entities/statement_import.dart';
import 'package:formetas/domain/entities/goal_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/entities/reserve_entity.dart';
import 'package:formetas/domain/entities/reserve_movement_entity.dart';
import 'package:formetas/domain/services/goal_outlook.dart';
import 'package:formetas/domain/services/statement_classifier.dart';
import 'package:formetas/domain/services/statement_parser.dart';
import 'package:formetas/domain/services/statement_reserve_plan.dart';

StatementEntry _entry({
  required DateTime date,
  required double amount,
  required TransactionType type,
  required String description,
}) {
  return StatementEntry(
    line: 1,
    date: date,
    amount: amount,
    type: type,
    description: description,
  );
}

void main() {
  test('setembro de 2026 conta o feriado de 7 de setembro', () {
    expect(BrazilBusinessCalendar.businessDayNumber(DateTime(2026, 9, 2)), 2);
    expect(BrazilBusinessCalendar.businessDayNumber(DateTime(2026, 9, 7)), isNull);
    expect(BrazilBusinessCalendar.businessDayNumber(DateTime(2026, 9, 9)), 6);
    expect(BrazilBusinessCalendar.businessDayNumber(DateTime(2026, 9, 10)), 7);
    expect(BrazilBusinessCalendar.isBusinessDay(DateTime(2024, 3, 29)), isFalse);
  });

  test('a escolha salva volta na próxima descrição igual', () {
    final learned = StatementClassifier.classify(
      [
        _entry(
          date: DateTime(2026, 9, 14),
          amount: 80,
          type: TransactionType.expense,
          description: 'Compra no débito via NuPay - iFood',
        ),
      ],
      rules: const [
        ImportRule(
          text: 'compra no debito via nupay ifood',
          role: StatementRole.transaction,
          category: 'Alimentação',
          type: TransactionType.expense,
        ),
      ],
    );
    expect(learned.single.category, 'Alimentação');
  });

  test('fatura, estorno e pix no próprio nome não entram como receita ou despesa', () {
    final rows = StatementClassifier.classify(
      [
        _entry(
          date: DateTime(2026, 9, 2),
          amount: 3645.42,
          type: TransactionType.income,
          description: 'Transferência Recebida - Augusto Negri Xavier - Banco do Brasil',
        ),
        _entry(
          date: DateTime(2026, 9, 13),
          amount: 50,
          type: TransactionType.income,
          description: 'Transferência recebida pelo Pix - Augusto Negri Xavier',
        ),
        _entry(
          date: DateTime(2026, 9, 16),
          amount: 32.76,
          type: TransactionType.expense,
          description: 'Pagamento de fatura - AUGUSTO NEGRI XAVIER',
        ),
        _entry(
          date: DateTime(2026, 9, 20),
          amount: 14,
          type: TransactionType.income,
          description: 'Estorno - Compra no débito',
        ),
      ],
      userName: 'Augusto Negri Xavier',
    );

    expect(rows[0].category, 'Salário');
    expect(rows[0].role, StatementRole.transaction);
    expect(rows[1].role, StatementRole.ownTransfer);
    expect(rows[2].role, StatementRole.ignored);
    expect(rows[3].role, StatementRole.ignored);
  });

  test('recebimento alto até o 6º dia útil vira salário', () {
    final rows = StatementClassifier.classify([
      _entry(
        date: DateTime(2026, 9, 2),
        amount: 3645.42,
        type: TransactionType.income,
        description:
            'Transferência Recebida - AUGUSTO NEGRI XAVIER - BCO DO BRASIL S.A.',
      ),
      _entry(
        date: DateTime(2026, 9, 2),
        amount: 70,
        type: TransactionType.income,
        description: 'Transferência Recebida - João',
      ),
      _entry(
        date: DateTime(2026, 9, 22),
        amount: 2000,
        type: TransactionType.income,
        description: 'Transferência recebida pelo Pix',
      ),
      _entry(
        date: DateTime(2026, 9, 20),
        amount: 500,
        type: TransactionType.income,
        description: 'Salário',
      ),
    ]);

    expect(rows[0].category, 'Salário');
    expect(rows[0].role, StatementRole.transaction);
    expect(rows[1].category, 'Outros');
    expect(rows[2].category, 'Outros');
    expect(rows[3].category, 'Salário');
  });

  test('aplicação e resgate RDB viram movimento de caixinha', () {
    final parsed = StatementParser.parse('''
Data,Valor,Descrição
02/09/2026,-1000.00,Aplicação RDB
19/09/2026,100.00,Resgate RDB
13/09/2026,21.00,Transferência Recebida - João
''');
    final rows = StatementClassifier.classify(parsed.entries);

    expect(rows[0].role, StatementRole.toReserve);
    expect(rows[0].type, TransactionType.expense);
    expect(rows[1].role, StatementRole.fromReserve);
    expect(rows[1].type, TransactionType.income);
    expect(rows[2].role, StatementRole.transaction);
    expect(rows[2].category, 'Outros');
  });

  test('resgate anterior à aplicação pede o saldo que já estava na caixinha', () {
    final shortfall = StatementReservePlan.openingShortfall(
      current: 0,
      entries: [
        _entry(
          date: DateTime(2026, 9, 5),
          amount: 200,
          type: TransactionType.income,
          description: 'Resgate RDB',
        ).copyWith(role: StatementRole.fromReserve),
        _entry(
          date: DateTime(2026, 9, 2),
          amount: 1000,
          type: TransactionType.expense,
          description: 'Aplicação RDB',
        ).copyWith(role: StatementRole.toReserve),
      ],
    );

    expect(shortfall, 0);

    final earlyRescue = StatementReservePlan.openingShortfall(
      current: 0,
      entries: [
        _entry(
          date: DateTime(2026, 9, 2),
          amount: 100,
          type: TransactionType.income,
          description: 'Resgate RDB',
        ).copyWith(role: StatementRole.fromReserve),
      ],
    );
    expect(earlyRescue, 100);
  });

  test('meta ligada à caixinha projeta a chegada pelo ritmo dos aportes', () {
    final goal = GoalEntity(
      id: 'g1',
      userId: 'u1',
      name: 'Viagem',
      targetValue: 1000,
      currentValue: 0,
      targetDate: DateTime(2027, 6, 1),
      createdAt: DateTime(2026, 7, 1),
      reserveId: 'r1',
    );
    final reserve = ReserveWithMovements(
      reserve: ReserveEntity(
        id: 'r1',
        userId: 'u1',
        name: 'Viagem',
        type: ReserveType.caixinha,
        initialValue: 0,
        currentValue: 0,
        startDate: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
      ),
      movements: [
        ReserveMovementEntity(
          id: 'm1',
          reserveId: 'r1',
          userId: 'u1',
          type: ReserveMovementType.deposit,
          amount: 200,
          date: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
      ],
    );

    final outlook = GoalOutlooks.build(
      goal: goal,
      reserve: reserve,
      cdiRate: 0,
      now: DateTime(2026, 9, 1),
    );

    expect(outlook.current, closeTo(200, 0.01));
    expect(outlook.message, contains('No ritmo atual'));
  });
}
