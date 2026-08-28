import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/leaf_formatter.dart';
import '../../providers/anthill_providers.dart';
import 'ant_character.dart';

/// Reforço positivo pontual depois de guardar folhinhas.
///
/// Devolve apenas o conteúdo da mensagem: quem decide como e quando exibir
/// continua sendo a tela financeira, que segue funcionando igual se este
/// arquivo desaparecer.
abstract final class AnthillFeedback {
  static const _phrases = [
    'Sua formiga levou tudo para o formigueiro.',
    'Pequenos passos, grande patrimônio.',
    'O formigueiro está crescendo.',
    'Mais perto do seu objetivo.',
    'Trabalho de formiguinha, do jeitinho certo.',
  ];

  /// Mensagem para exibir quando folhinhas entram em um armazém ou nos
  /// investimentos. Retorna `null` quando o usuário desativou a experiência.
  static Widget? stored(WidgetRef ref, double amount) {
    final enabled =
        ref.read(antProfileProvider).valueOrNull?.animationsEnabled ?? true;
    if (!enabled || amount <= 0) return null;

    final phrase = _phrases[amount.round() % _phrases.length];

    return Builder(
      builder: (context) => Row(
        children: [
          const LeafGlyph(size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mais ${LeafFormatter.label(amount)} para o formigueiro.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  phrase,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
