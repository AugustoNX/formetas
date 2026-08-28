import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/anthill_snapshot.dart';
import '../../widgets/anthill/anthill_palette.dart';
import '../../widgets/anthill/anthill_room.dart';
import '../../widgets/anthill/anthill_sections.dart';
import '../../widgets/anthill/anthill_widgets.dart';
import '../../widgets/formetas_card.dart';

/// Sala dos dados do mês: quanto entrou, quanto foi usado e quanto ficou
/// guardado — sempre em folhinhas e em reais, lado a lado.
class AnthillMonthScreen extends StatelessWidget {
  const AnthillMonthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnthillRoom(
      icon: Icons.calendar_month_rounded,
      title: 'O mês',
      subtitle: 'O caminho que suas folhinhas fizeram neste mês.',
      body: (context, snapshot) => [
        LeafFlowCard(facts: snapshot.facts),
        const SizedBox(height: 16),
        _StoredThisMonthCard(facts: snapshot.facts),
        const SizedBox(height: 16),
      ],
      aside: (context, snapshot) => [
        _RhythmCard(snapshot: snapshot),
        const SizedBox(height: 16),
        const _MonthActionsCard(),
      ],
    );
  }
}

class _StoredThisMonthCard extends StatelessWidget {
  const _StoredThisMonthCard({required this.facts});

  final AnthillFacts facts;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final stored = facts.storedThisMonth;

    return FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnthillSectionHeader(
            title: 'Levado para os armazéns',
            subtitle: 'Folhinhas que saíram do saldo e foram guardadas.',
          ),
          LeafCounter(
            amount: stored,
            label: 'Guardado neste mês',
          ),
          const SizedBox(height: 14),
          Text(
            stored > 0
                ? 'Sua formiga já fez a parte dela neste mês. '
                    'Qualquer folhinha a mais é lucro para o inverno.'
                : 'Ainda dá tempo de levar folhinhas para o armazém neste mês.',
            style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.snapshot});

  final AnthillSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final facts = snapshot.facts;

    return FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnthillSectionHeader(
            title: 'Ritmo da formiga',
            subtitle: 'Constância vale mais do que valor.',
          ),
          AntEnergyBar(energy: snapshot.energy),
          const SizedBox(height: 18),
          Divider(color: palette.muted.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 14),
          _RhythmLine(
            icon: Icons.edit_note_rounded,
            label: 'Registros neste mês',
            value: '${facts.transactionsThisMonth}',
          ),
          _RhythmLine(
            icon: Icons.local_fire_department_rounded,
            label: 'Meses seguidos guardando',
            value: '${facts.savingStreak}',
          ),
          _RhythmLine(
            icon: Icons.inventory_2_outlined,
            label: 'Meses com folhinhas guardadas',
            value: '${facts.monthsWithSavings}',
          ),
        ],
      ),
    );
  }
}

class _RhythmLine extends StatelessWidget {
  const _RhythmLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.leaf),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: palette.muted, fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _MonthActionsCard extends StatelessWidget {
  const _MonthActionsCard();

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return FormetasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnthillSectionHeader(
            title: 'Movimentar folhinhas',
            subtitle: 'Os mesmos registros do Formetas, com outro nome.',
          ),
          _ActionLine(
            icon: Icons.south_west_rounded,
            color: AppColors.income,
            title: 'Folhinhas coletadas',
            subtitle: 'Registrar uma receita',
            onTap: () => context.push('/transaction/new?type=income'),
          ),
          _ActionLine(
            icon: Icons.north_east_rounded,
            color: AppColors.accent,
            title: 'Folhinhas utilizadas',
            subtitle: 'Registrar uma despesa',
            onTap: () => context.push('/transaction/new?type=expense'),
          ),
          _ActionLine(
            icon: Icons.inventory_2_outlined,
            color: palette.leaf,
            title: 'Guardar folhinhas',
            subtitle: 'Levar do saldo para um armazém',
            onTap: () => context.push('/transfer?from=balance&to=reserve'),
          ),
        ],
      ),
    );
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: palette.muted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
