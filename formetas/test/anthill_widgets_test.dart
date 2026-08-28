import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/ant_profile_entity.dart';
import 'package:formetas/domain/entities/anthill_snapshot.dart';
import 'package:formetas/domain/entities/reserve_entity.dart';
import 'package:formetas/domain/entities/reserve_movement_entity.dart';
import 'package:formetas/domain/entities/settings_entity.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/anthill_service.dart';
import 'package:formetas/presentation/widgets/anthill/ant_character.dart';
import 'package:formetas/presentation/widgets/anthill/anthill_scene.dart';
import 'package:formetas/presentation/widgets/anthill/anthill_widgets.dart';

void main() {
  final now = DateTime(2026, 8, 15);

  AnthillSnapshot snapshotFor(double income) {
    return const AnthillService().buildSnapshot(
      profile: const AntProfileEntity(),
      transactions: [
        TransactionEntity(
          id: 'a',
          userId: 'u1',
          type: TransactionType.income,
          category: 'Salário',
          value: 0,
          description: '',
          date: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 8, 10),
        ),
      ].map((t) => t.copyWith(value: income)).toList(),
      transfers: const [],
      reserves: [
        ReserveWithMovements(
          reserve: ReserveEntity(
            id: 'r1',
            userId: 'u1',
            name: 'Reserva de emergência para o inverno inteiro',
            type: ReserveType.caixinha,
            initialValue: 1200,
            currentValue: 1200,
            startDate: now,
            createdAt: now,
          ),
          movements: const [],
        ),
      ],
      investments: const [],
      goals: const [],
      settings: const SettingsEntity(),
      referenceDate: now,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required Brightness brightness,
    Size size = const Size(360, 760),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
  }

  for (final brightness in Brightness.values) {
    group('tema ${brightness.name}', () {
      testWidgets('formiga e formigueiro renderizam em todos os níveis',
          (tester) async {
        for (var level = 1; level <= 5; level++) {
          await pump(
            tester,
            Column(
              children: [
                AntCharacter(level: level, size: 140, animated: false),
                AnthillScene(
                  level: level,
                  levelProgress: 0.45,
                  storageCount: level,
                  animated: false,
                ),
              ],
            ),
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('cartões do formigueiro cabem em tela estreita',
          (tester) async {
        final snapshot = snapshotFor(7850);

        await pump(
          tester,
          Column(
            children: [
              LeafCounter(amount: snapshot.netWorth),
              const SizedBox(height: 12),
              AntEnergyBar(energy: snapshot.energy),
              const SizedBox(height: 12),
              LeafFlowRow(facts: snapshot.facts),
              const SizedBox(height: 12),
              WinterCard(winter: snapshot.winter),
              const SizedBox(height: 12),
              for (final task in snapshot.winter.tasks)
                WinterTaskTile(task: task),
              for (final mission in snapshot.missions)
                MissionTile(mission: mission),
              AchievementGrid(
                achievements: snapshot.achievements.take(4).toList(),
              ),
            ],
          ),
          brightness: brightness,
          size: const Size(320, 900),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Folhinhas coletadas'), findsOneWidget);
      });
    });
  }
}
