import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/utils/patrimony_calculator.dart';
import 'package:formetas/domain/entities/onboarding_draft.dart';
import 'package:formetas/domain/entities/reserve_entity.dart';
import 'package:formetas/domain/entities/reserve_movement_entity.dart';
import 'package:formetas/domain/entities/settings_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/dashboard_service.dart';
import 'package:formetas/domain/services/onboarding_planner.dart';

void main() {
  final at = DateTime.now();
  const settings = SettingsEntity();

  test('saldo inicial vira lançamento de abertura, não receita', () {
    final opening = OnboardingPlanner.openingTransaction(
      id: 'o1',
      userId: 'u1',
      availableBalance: 2500,
      at: at,
    );

    expect(opening, isNotNull);
    expect(opening!.type, TransactionType.opening);
    expect(opening.value, 2500);
    expect(OnboardingPlanner.openingTransaction(
      id: 'o2',
      userId: 'u1',
      availableBalance: 0,
      at: at,
    ), isNull);
  });

  test('caixinhas entram no patrimônio sem descontar o saldo', () {
    var n = 0;
    final reserves = OnboardingPlanner.reserves(
      userId: 'u1',
      draft: const OnboardingDraft(
        availableBalance: 4000,
        reserves: [
          OnboardingReserveDraft(name: 'Emergência', amount: 1500),
          OnboardingReserveDraft(name: '  ', amount: 80),
          OnboardingReserveDraft(name: 'Viagem', amount: 0),
        ],
      ),
      at: at,
      cdiRate: settings.cdiRate,
      nextId: () => 'r${n++}',
    );

    expect(reserves, hasLength(1));
    expect(reserves.first.name, 'Emergência');
    expect(reserves.first.type, ReserveType.caixinha);
    expect(reserves.first.initialValue, 1500);
    expect(reserves.first.currentValue, closeTo(1500, 0.01));

    final opening = OnboardingPlanner.openingTransaction(
      id: 'o1',
      userId: 'u1',
      availableBalance: 4000,
      at: at,
    )!;

    final stats = DashboardService().compute(
      transactions: [opening],
      investments: const [],
      reservesWithMovements: [
        ReserveWithMovements(reserve: reserves.first, movements: const []),
      ],
      transfers: const [],
      settings: settings,
      selectedMonth: at,
    );

    expect(stats.totalBalance, closeTo(4000, 0.01));
    expect(stats.monthlyIncome, 0);
    expect(stats.monthlySavings, 0);
    expect(stats.totalReserves, closeTo(1500, 0.01));
    expect(stats.netWorth, closeTo(5500, 0.01));

    expect(
      PatrimonyCalculator.balance(transactions: [opening], transfers: const []),
      closeTo(4000, 0.01),
    );
  });

  test('patrimônio inicial soma saldo livre e caixinhas', () {
    const draft = OnboardingDraft(
      availableBalance: 800,
      reserves: [
        OnboardingReserveDraft(name: 'Reserva', amount: 200),
      ],
    );
    expect(draft.startingNetWorth, 1000);
  });
}
