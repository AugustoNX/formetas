import 'package:flutter/material.dart';

import '../../widgets/anthill/anthill_rhythm_cards.dart';
import '../../widgets/anthill/anthill_room.dart';
import '../../widgets/anthill/anthill_sections.dart';
import '../../widgets/anthill/anthill_widgets.dart';

/// Sala das missões: um desafio da semana e a trilha curta de 7 dias.
class AnthillMissionsScreen extends StatelessWidget {
  const AnthillMissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnthillRoom(
      icon: Icons.flag_rounded,
      title: 'Missões',
      subtitle: 'Um número real nesta semana, e uma trilha de sete dias.',
      body: (context, snapshot) => [
        const AnthillSectionHeader(
          title: 'Missão da semana',
          subtitle: 'Cumprir dá um passo. Não cumprir não tira nível.',
        ),
        WeeklyChallengeCard(
          challenge: snapshot.challenge,
          trailSteps: snapshot.winter.trailSteps,
          animated: snapshot.profile.animationsEnabled,
        ),
        const SizedBox(height: 16),
        SpendingTrailCard(
          trail: snapshot.trail,
          animated: snapshot.profile.animationsEnabled,
        ),
        const SizedBox(height: 16),
      ],
      aside: (context, snapshot) => const [
        GoalsSection(),
        SizedBox(height: 16),
      ],
    );
  }
}
