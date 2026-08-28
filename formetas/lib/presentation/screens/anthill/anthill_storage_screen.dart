import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/anthill_snapshot.dart';
import '../../widgets/anthill/anthill_palette.dart';
import '../../widgets/anthill/anthill_room.dart';
import '../../widgets/anthill/anthill_sections.dart';
import '../../widgets/anthill/anthill_widgets.dart';
import '../../widgets/formetas_card.dart';

/// Sala dos armazéns: as caixinhas e os investimentos vistos como o estoque do
/// formigueiro para o inverno.
class AnthillStorageScreen extends StatelessWidget {
  const AnthillStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnthillRoom(
      icon: Icons.inventory_2_rounded,
      title: 'Armazéns',
      subtitle: 'Tudo que sua formiga já guardou para o inverno.',
      body: (context, snapshot) => [
        _StockCard(facts: snapshot.facts),
        const SizedBox(height: 16),
        const StorageSection(),
        const SizedBox(height: 16),
      ],
      aside: (context, snapshot) => [
        WorkingLeavesCard(
          facts: snapshot.facts,
          onTap: () => context.push('/transfer?from=balance&to=investment'),
        ),
        const SizedBox(height: 16),
        const _StorageActions(),
      ],
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.facts});

  final AnthillFacts facts;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final stored = facts.reserves + facts.investments;

    return FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnthillSectionHeader(
            title: 'Estoque do formigueiro',
            subtitle: 'Armazéns e folhinhas trabalhando, somados.',
          ),
          LeafCounter(amount: stored, label: 'Folhinhas estocadas'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LeafCounter(
                  amount: facts.reserves,
                  label: 'Nos armazéns',
                  compact: true,
                ),
              ),
              Expanded(
                child: LeafCounter(
                  amount: facts.investments,
                  label: 'Trabalhando',
                  compact: true,
                ),
              ),
            ],
          ),
          if (facts.totalYield > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Suas folhinhas já renderam sozinhas. Isso é o formigueiro '
              'trabalhando por você.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StorageActions extends StatelessWidget {
  const _StorageActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/transfer?from=balance&to=reserve'),
          icon: const Icon(Icons.eco_rounded, size: 18),
          label: const Text('Guardar folhinhas'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.push('/reserve/new'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Novo armazém'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
