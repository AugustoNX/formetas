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
  }) {
    return service.buildSnapshot(
      profile: profile,
      transactions: transactions,
      transfers: transfers,
      reserves: reserves,
      investments: investments,
      goals: goals,
      settings: const SettingsEntity(),
      referenceDate: now,
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
    test('reconhecem folhinhas levadas ao armazém no mês', () {
      final snapshot = build(
        transactions: [
          transaction(type: TransactionType.income, value: 2000),
        ],
        transfers: [
          TransferEntity(
            id: 't1',
            userId: 'u1',
            amount: 300,
            fromType: WalletType.balance,
            toType: WalletType.reserve,
            toId: 'r1',
            date: now,
            createdAt: now,
          ),
        ],
        reserves: [reserve(id: 'r1')],
      );

      final mission =
          snapshot.missions.firstWhere((m) => m.id == 'guardar_no_mes');

      expect(snapshot.facts.storedThisMonth, 300);
      expect(mission.isComplete, isTrue);
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
    test('é apenas um indicador visual entre 0 e o máximo', () {
      final snapshot = build(
        transactions: [
          transaction(type: TransactionType.income, value: 4000),
        ],
        reserves: [reserve(id: 'r1', initialValue: 500)],
      );

      expect(snapshot.energy.level, inInclusiveRange(0, AntEnergy.maxLevel));
      expect(snapshot.energy.message, isNotEmpty);
    });
  });
}
