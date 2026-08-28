import 'package:flutter/material.dart';

import '../../widgets/anthill/anthill_room.dart';
import '../../widgets/anthill/anthill_sections.dart';

/// Sala das missões: o que dá para conquistar neste mês e os grandes objetivos
/// de longo prazo — as metas do Formetas, contadas como missões.
class AnthillMissionsScreen extends StatelessWidget {
  const AnthillMissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnthillRoom(
      icon: Icons.flag_rounded,
      title: 'Missões',
      subtitle: 'Pequenos passos deste mês e os objetivos maiores.',
      body: (context, snapshot) => [
        MissionsSection(missions: snapshot.missions),
        const SizedBox(height: 16),
      ],
      aside: (context, snapshot) => const [
        GoalsSection(),
        SizedBox(height: 16),
      ],
    );
  }
}
