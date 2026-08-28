import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/ant_profile_entity.dart';
import 'package:formetas/domain/entities/goal_entity.dart';
import 'package:formetas/domain/entities/investment_entity.dart';
import 'package:formetas/domain/entities/reserve_entity.dart';
import 'package:formetas/domain/entities/reserve_movement_entity.dart';
import 'package:formetas/domain/entities/settings_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/entities/transfer_entity.dart';
import 'package:formetas/domain/services/anthill_service.dart';
import 'package:formetas/presentation/providers/anthill_providers.dart';
import 'package:formetas/presentation/providers/data_providers.dart';
import 'package:formetas/presentation/screens/anthill/achievements_screen.dart';
import 'package:formetas/presentation/screens/anthill/anthill_entrance_screen.dart';
import 'package:formetas/presentation/screens/anthill/anthill_missions_screen.dart';
import 'package:formetas/presentation/screens/anthill/anthill_month_screen.dart';
import 'package:formetas/presentation/screens/anthill/anthill_storage_screen.dart';

void main() {
  final now = DateTime(2026, 8, 15);

  final transactions = [
    TransactionEntity(
      id: 'a',
      userId: 'u1',
      type: TransactionType.income,
      category: 'Salário',
      value: 9000,
      description: 'Salário do mês',
      date: DateTime(2026, 8, 5),
      createdAt: DateTime(2026, 8, 5),
    ),
    TransactionEntity(
      id: 'b',
      userId: 'u1',
      type: TransactionType.expense,
      category: 'Mercado',
      value: 2400,
      description: 'Compras',
      date: DateTime(2026, 8, 9),
      createdAt: DateTime(2026, 8, 9),
    ),
  ];

  final reserves = [
    ReserveWithMovements(
      reserve: ReserveEntity(
        id: 'r1',
        userId: 'u1',
        name: 'Reserva de emergência da família inteira',
        type: ReserveType.caixinha,
        initialValue: 3200,
        currentValue: 3200,
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      movements: const [],
    ),
  ];

  final investments = [
    InvestmentEntity(
      id: 'i1',
      userId: 'u1',
      name: 'CDB Liquidez Diária',
      type: InvestmentType.cdb,
      initialValue: 2500,
      currentValue: 2500,
      startDate: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  final goals = [
    GoalEntity(
      id: 'g1',
      userId: 'u1',
      name: 'Computador novo para trabalhar melhor',
      targetValue: 5000,
      currentValue: 3250,
      targetDate: DateTime(2026, 12, 1),
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  final transfers = [
    TransferEntity(
      id: 't1',
      userId: 'u1',
      amount: 450,
      fromType: WalletType.balance,
      toType: WalletType.reserve,
      toId: 'r1',
      date: DateTime(2026, 8, 12),
      createdAt: DateTime(2026, 8, 12),
    ),
  ];

  final snapshot = const AnthillService().buildSnapshot(
    profile: const AntProfileEntity(antName: 'Nina', createdAt: null),
    transactions: transactions,
    transfers: transfers,
    reserves: reserves,
    investments: investments,
    goals: goals,
    settings: const SettingsEntity(),
    referenceDate: now,
  );

  Future<void> pumpRoom(
    WidgetTester tester,
    Widget room, {
    Size size = const Size(360, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anthillSnapshotProvider.overrideWithValue(AsyncValue.data(snapshot)),
          antProfileProvider.overrideWith(
            (ref) => Stream.value(snapshot.profile),
          ),
          goalsProvider.overrideWith((ref) => Stream.value(goals)),
          reservesWithMovementsProvider.overrideWith(
            (ref) => Stream.value(reserves),
          ),
          settingsProvider.overrideWith(
            (ref) => Stream.value(const SettingsEntity()),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: room)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('entrada apresenta a formiga e o inverno', (tester) async {
    await pumpRoom(tester, const AnthillEntranceScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('Folhinhas coletadas'), findsWidgets);
  });

  testWidgets('sala do mês mostra o fluxo de folhinhas', (tester) async {
    await pumpRoom(tester, const AnthillMonthScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Folhinhas do mês'), findsOneWidget);
    expect(find.text('Ritmo da formiga'), findsOneWidget);
  });

  testWidgets('sala dos armazéns lista as caixinhas', (tester) async {
    await pumpRoom(tester, const AnthillStorageScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Armazéns do formigueiro'), findsOneWidget);
    expect(find.text('Folhinhas trabalhando'), findsOneWidget);
  });

  testWidgets('sala das missões traz o mês e as metas', (tester) async {
    await pumpRoom(tester, const AnthillMissionsScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('Missões do mês'), findsOneWidget);
    expect(find.text('Grandes objetivos'), findsOneWidget);
  });

  testWidgets('sala das conquistas mostra o progresso', (tester) async {
    await pumpRoom(tester, const AchievementsScreen());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('desbloqueadas'), findsWidgets);
  });

  testWidgets('salas cabem em tela estreita', (tester) async {
    for (final room in const [
      AnthillEntranceScreen(),
      AnthillMonthScreen(),
      AnthillStorageScreen(),
      AnthillMissionsScreen(),
    ]) {
      await pumpRoom(tester, room, size: const Size(320, 800));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('no desktop as salas usam duas colunas', (tester) async {
    await pumpRoom(
      tester,
      const AnthillMissionsScreen(),
      size: const Size(1280, 1000),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Missões do mês'), findsOneWidget);
    expect(find.text('Grandes objetivos'), findsOneWidget);
  });

  testWidgets('o valor real acompanha as folhinhas', (tester) async {
    await pumpRoom(tester, const AnthillStorageScreen(),
        size: const Size(420, 900));

    expect(find.textContaining('R\$'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
