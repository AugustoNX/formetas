import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/constants/anthill_catalog.dart';
import 'package:formetas/domain/entities/ant_profile_entity.dart';
import 'package:formetas/domain/entities/anthill_snapshot.dart';
import 'package:formetas/domain/entities/goal_entity.dart';
import 'package:formetas/domain/entities/investment_entity.dart';
import 'package:formetas/domain/entities/reserve_entity.dart';
import 'package:formetas/domain/entities/reserve_movement_entity.dart';
import 'package:formetas/domain/entities/settings_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/entities/transfer_entity.dart';
import 'package:formetas/domain/services/anthill_service.dart';

void main() {
  const service = AnthillService();
  final now = DateTime(2026, 8, 15);

  TransactionEntity transaction({
    required TransactionType type,
    required double value,
    DateTime? date,
    String id = 'tx',
  }) {
    return TransactionEntity(
      id: id,
      userId: 'u1',
      type: type,
      category: 'Geral',
      value: value,
      description: '',
      date: date ?? now,
      createdAt: date ?? now,
    );
  }

  ReserveWithMovements reserve({
    required String id,
    double initialValue = 0,
    List<ReserveMovementEntity> movements = const [],
  }) {
    return ReserveWithMovements(
      reserve: ReserveEntity(
        id: id,
        userId: 'u1',
        name: 'Armazém $id',
        type: ReserveType.caixinha,
        initialValue: initialValue,
        currentValue: initialValue,
        startDate: now,
        createdAt: now,
      ),
      movements: movements,
    );
  }

  AnthillSnapshot build({
    List<TransactionEntity> transactions = const [],
    List<TransferEntity> transfers = const [],
    List<ReserveWithMovements> reserves = const [],
    List<InvestmentEntity> investments = const [],
    List<GoalEntity> goals = const [],
    AntProfileEntity profile = const AntProfileEntity(),
    DateTime? referenceDate,
  }) {
    return service.buildSnapshot(
      profile: profile,
      transactions: transactions,
      transfers: transfers,
      reserves: reserves,
      investments: investments,
      goals: goals,
      settings: const SettingsEntity(),
      referenceDate: referenceDate ?? now,
    );
  }

  TransferEntity toReserve(double amount, DateTime date, {String id = 't1'}) {
    return TransferEntity(
      id: id,
      userId: 'u1',
      amount: amount,
      fromType: WalletType.balance,
      toType: WalletType.reserve,
      toId: 'r1',
      date: date,
      createdAt: date,
    );
  }

  group('formigueiro vazio', () {
    test('não culpa o usuário e começa no primeiro nível', () {
      final snapshot = build();

      expect(snapshot.leaves, 0);
      expect(snapshot.level.level, 1);
      expect(snapshot.winter.readiness, 0);
      expect(snapshot.headline, contains('primeira folhinha'));
      expect(snapshot.unlockedCount, 0);
    });
  });

  group('folhinhas', () {
    test('espelham o patrimônio construído', () {
      final snapshot = build(
        transactions: [
          transaction(type: TransactionType.income, value: 3000, id: 'a'),
          transaction(type: TransactionType.expense, value: 500, id: 'b'),
        ],
        reserves: [reserve(id: 'r1', initialValue: 1000)],
      );

      expect(snapshot.facts.balance, 2500);
      expect(snapshot.leaves, greaterThanOrEqualTo(3500));
      expect(snapshot.netWorth, closeTo(snapshot.leaves.toDouble(), 1));
    });

    test('nunca ficam negativas', () {
      final snapshot = build(
        transactions: [
          transaction(type: TransactionType.expense, value: 800),
        ],
      );

      expect(snapshot.facts.balance, -800);
      expect(snapshot.leaves, 0);
    });
  });

  group('níveis', () {
    test('acompanham as faixas do catálogo', () {
      for (final level in AnthillCatalog.levels) {
        final snapshot = build(
          transactions: [
            transaction(type: TransactionType.income, value: level.threshold + 1),
          ],
        );
        expect(snapshot.level.level, level.level);
      }
    });

    test('progresso mostra o quanto falta para o próximo nível', () {
      final snapshot = build(
        transactions: [
          transaction(type: TransactionType.income, value: 3000),
        ],
      );

      expect(snapshot.level.level, 2);
      expect(snapshot.levelProgress, closeTo(0.5, 0.01));
      expect(snapshot.remainingToNextLevel, 2000);
    });
  });

  group('conquistas', () {
    test('são derivadas dos dados financeiros reais', () {
      final snapshot = build(
        transactions: [
          transaction(type: TransactionType.income, value: 1200),
        ],
        reserves: [reserve(id: 'r1', initialValue: 100)],
      );

      final ids = snapshot.achievements
          .where((a) => a.isEarned)
          .map((a) => a.id)
          .toSet();

      expect(ids, contains('primeira_folhinha'));
      expect(ids, contains('guardia_da_reserva'));
      expect(ids, contains('pequeno_formigueiro'));
      expect(ids, isNot(contains('formigueiro_forte')));
    });

    test('o perfil só guarda quando cada uma aconteceu', () {
      final unlockedAt = DateTime(2026, 1, 1);
      final snapshot = build(
        profile: AntProfileEntity(
          unlockedAchievements: {'primeira_folhinha': unlockedAt},
          createdAt: unlockedAt,
        ),
      );

      final achievement =
          snapshot.achievements.firstWhere((a) => a.id == 'primeira_folhinha');

      expect(achievement.isUnlocked, isTrue);
      expect(achievement.unlockedAt, unlockedAt);
    });
  });

  group('inverno', () {
    test('mede preparo a partir de reservas, armazéns e consistência', () {
      final poor = build(
        transactions: [transaction(type: TransactionType.income, value: 100)],
      );
      final prepared = build(
        transactions: [
          transaction(type: TransactionType.income, value: 30000),
        ],
        reserves: [
          reserve(id: 'r1', initialValue: 5000),
          reserve(id: 'r2', initialValue: 5000),
          reserve(id: 'r3', initialValue: 5000),
        ],
      );

      expect(poor.winter.readiness, lessThan(prepared.winter.readiness));
      expect(prepared.winter.readiness, greaterThan(0.5));
      expect(prepared.winter.daysRemaining, greaterThan(0));
    });

    test('a mensagem é sempre encorajadora', () {
      for (final snapshot in [
        build(),
        build(transactions: [transaction(type: TransactionType.income, value: 50000)]),
      ]) {
        expect(snapshot.winter.message, isNotEmpty);
        expect(snapshot.winter.message.toLowerCase(), isNot(contains('falhou')));
        expect(snapshot.winter.message.toLowerCase(), isNot(contains('perdeu')));
      }
    });
  });

  group('missões', () {
    test('reconhece folhinhas levadas à caixinha nesta semana', () {
      final snapshot = build(
        transactions: [
          transaction(type: TransactionType.income, value: 2000),
        ],
        transfers: [toReserve(300, now)],
        reserves: [reserve(id: 'r1')],
      );

      expect(snapshot.facts.storedThisMonth, 300);
      expect(snapshot.challenge.kind, WeeklyChallengeKind.store);
      expect(snapshot.challenge.isComplete, isTrue);
      expect(snapshot.missions, hasLength(1));
      expect(snapshot.missions.single.isComplete, isTrue);
    });

    test('pede para gastar menos na categoria que mais pesou', () {
      final sunday = DateTime(2026, 8, 16, 23, 59, 59);
      final snapshot = build(
        referenceDate: sunday,
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 200,
            date: DateTime(2026, 8, 5),
            id: 'food-last',
          ).copyWith(category: 'Alimentação'),
          transaction(
            type: TransactionType.expense,
            value: 100,
            date: DateTime(2026, 8, 12),
            id: 'food-now',
          ).copyWith(category: 'Alimentação'),
        ],
      );

      expect(snapshot.challenge.kind, WeeklyChallengeKind.spendLess);
      expect(snapshot.challenge.title, contains('R\$ 40'));
      expect(snapshot.challenge.title, contains('Alimentação'));
      expect(snapshot.challenge.isComplete, isTrue);
      expect(snapshot.winter.trailSteps, greaterThan(0));
    });

    test('não conclui o corte de gasto antes do domingo', () {
      final snapshot = build(
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 200,
            date: DateTime(2026, 8, 5),
            id: 'food-last',
          ).copyWith(category: 'Alimentação'),
        ],
      );

      expect(snapshot.challenge.isComplete, isFalse);
      expect(snapshot.challenge.detail, contains('pode gastar'));
    });

    test('mostra o que faltou quando o combinado estoura', () {
      final sunday = DateTime(2026, 8, 16, 23, 59, 59);
      final snapshot = build(
        referenceDate: sunday,
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 200,
            date: DateTime(2026, 8, 5),
            id: 'food-last',
          ).copyWith(category: 'Alimentação'),
          transaction(
            type: TransactionType.expense,
            value: 190,
            date: DateTime(2026, 8, 12),
            id: 'food-now',
          ).copyWith(category: 'Alimentação'),
        ],
      );

      expect(snapshot.challenge.isComplete, isFalse);
      expect(snapshot.challenge.detail.toLowerCase(), contains('parou'));
      expect(snapshot.level.level, greaterThan(0));
    });

    test('metas concluídas alimentam a conquista de missão cumprida', () {
      final snapshot = build(
        goals: [
          GoalEntity(
            id: 'g1',
            userId: 'u1',
            name: 'Computador',
            targetValue: 5000,
            currentValue: 5000,
            targetDate: now,
            createdAt: now,
          ),
        ],
      );

      final achievement =
          snapshot.achievements.firstWhere((a) => a.id == 'missao_cumprida');
      expect(achievement.isEarned, isTrue);
    });
  });

  group('energia', () {
    test('salário gasto por inteiro não alimenta a formiga', () {
      final spent = build(
        transactions: [
          transaction(type: TransactionType.income, value: 5000, id: 'in'),
          transaction(type: TransactionType.expense, value: 5000, id: 'out'),
        ],
      );
      final fed = build(
        transactions: [
          transaction(type: TransactionType.income, value: 5000, id: 'in'),
          transaction(type: TransactionType.expense, value: 1000, id: 'out'),
        ],
        transfers: [toReserve(400, now)],
        reserves: [reserve(id: 'r1')],
      );

      expect(spent.energy.level, 1);
      expect(fed.energy.level, 5);
      expect(fed.energy.level, greaterThan(spent.energy.level));
    });

    test('anotar despesa ou ter caixinha antiga não enche a energia', () {
      final logged = build(
        transactions: [
          for (var i = 0; i < 5; i++)
            transaction(
              type: TransactionType.expense,
              value: 20,
              id: 'e$i',
            ),
        ],
      );
      final quietReserve = build(
        reserves: [reserve(id: 'r1', initialValue: 5000)],
      );

      expect(logged.energy.level, 0);
      expect(quietReserve.energy.level, 2);
    });

    test('saldo parado no mês deixa a caixinha com fome', () {
      final kept = build(
        transactions: [
          transaction(type: TransactionType.income, value: 5000),
        ],
      );

      expect(kept.energy.level, 3);
      expect(kept.energy.message, contains('caixinha'));
    });
  });

  group('trilha e recado', () {
    test('sete dias sem a categoria levam ao armazém', () {
      final start = DateTime(2026, 8, 9);
      final snapshot = build(
        profile: AntProfileEntity(trailCategory: 'Lazer', trailStartedOn: start),
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 30,
            date: DateTime(2026, 8, 8),
            id: 'before',
          ).copyWith(category: 'Lazer'),
        ],
      );

      expect(snapshot.trail.steps, 7);
      expect(snapshot.trail.arrived, isTrue);
    });

    test('um gasto no meio da trilha não apaga os outros passos', () {
      final snapshot = build(
        profile: AntProfileEntity(
          trailCategory: 'Lazer',
          trailStartedOn: DateTime(2026, 8, 9),
        ),
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 30,
            date: DateTime(2026, 8, 12),
            id: 'slip',
          ).copyWith(category: 'Lazer'),
        ],
      );

      expect(snapshot.trail.arrived, isFalse);
      expect(snapshot.trail.steps, 6);
    });

    test('o recado junta o gasto da categoria e o que foi ao armazém', () {
      final snapshot = build(
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 86,
            id: 'food',
          ).copyWith(category: 'Alimentação'),
        ],
        transfers: [toReserve(100, now)],
        reserves: [reserve(id: 'r1')],
      );

      expect(
        snapshot.weeklyNote,
        'Você deixou R\$ 86 no caminho, a maior parte em Alimentação, '
        'e guardou R\$ 100 no armazém.',
      );
    });
  });

  group('inverno como temporada', () {
    test('a despensa diz quantos meses de gasto cobre', () {
      final snapshot = build(
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 1000,
            date: DateTime(2026, 5, 10),
            id: 'may',
          ),
        ],
        reserves: [reserve(id: 'r1', initialValue: 2500)],
      );

      expect(snapshot.winter.showScene, isFalse);
      expect(snapshot.winter.monthsCovered, closeTo(2.5, 0.05));
      expect(snapshot.winter.pantry, contains('2,5'));
      expect(snapshot.winter.pantry, contains('meses de gasto'));
    });

    test('no dia do inverno a cena aquece sem apagar o que já existe', () {
      final warm = build(
        referenceDate: DateTime(2026, 6, 21, 10),
        transactions: [
          transaction(
            type: TransactionType.income,
            value: 8000,
            date: DateTime(2026, 5, 2),
            id: 'in',
          ),
          transaction(
            type: TransactionType.expense,
            value: 1000,
            date: DateTime(2026, 5, 10),
            id: 'out',
          ),
        ],
        reserves: [reserve(id: 'r1', initialValue: 6000)],
      );
      final thin = build(
        referenceDate: DateTime(2026, 6, 21, 10),
        transactions: [
          transaction(
            type: TransactionType.expense,
            value: 1000,
            date: DateTime(2026, 5, 10),
            id: 'out',
          ),
        ],
        reserves: [reserve(id: 'r1', initialValue: 100)],
      );

      expect(warm.winter.showScene, isTrue);
      expect(warm.winter.shelterReady, isTrue);
      expect(warm.winter.headline, contains('aquecida'));
      expect(warm.ground, AnthillGround.warm);
      expect(warm.antMood, AntMood.asleep);
      expect(warm.facts.reserves, 6000);
      expect(
        warm.achievements.firstWhere((a) => a.id == 'chegou_ao_inverno').isEarned,
        isTrue,
      );

      expect(thin.winter.shelterReady, isFalse);
      expect(thin.winter.headline, contains('magro'));
      expect(thin.ground, AnthillGround.thin);
      expect(
        thin.achievements.firstWhere((a) => a.id == 'chegou_ao_inverno').isEarned,
        isFalse,
      );
      expect(thin.facts.reserves, 100);
    });
  });
}
