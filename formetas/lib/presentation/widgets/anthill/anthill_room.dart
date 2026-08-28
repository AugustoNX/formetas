import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../domain/entities/anthill_snapshot.dart';
import '../../providers/anthill_providers.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/data_providers.dart';
import 'anthill_palette.dart';
import 'anthill_sections.dart';

typedef AnthillRoomBuilder = List<Widget> Function(
  BuildContext context,
  AnthillSnapshot snapshot,
);

/// Moldura comum das salas do formigueiro.
///
/// Cuida do que toda sala precisa — carregar o retrato do formigueiro, o gesto
/// de puxar para atualizar, a largura máxima em telas grandes e o cabeçalho —
/// para que cada sala se preocupe apenas com o próprio conteúdo.
class AnthillRoom extends ConsumerWidget {
  const AnthillRoom({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    this.aside,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AnthillRoomBuilder body;

  /// Conteúdo que ganha uma coluna própria em telas largas e é empilhado
  /// abaixo do principal em telas estreitas.
  final AnthillRoomBuilder? aside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(anthillSnapshotProvider);

    return SafeArea(
      bottom: false,
      child: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AnthillErrorView(
          onRetry: () {
            _refreshFinancialData(ref);
            ref.invalidate(antProfileProvider);
          },
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => _refreshFinancialData(ref),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppBreakpoints.desktop;
              final primary = body(context, data);
              final secondary = aside?.call(context, data) ?? const <Widget>[];

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RoomHeader(
                          icon: icon,
                          title: title,
                          subtitle: subtitle,
                        ),
                        const SizedBox(height: 20),
                        if (wide && secondary.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: primary,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: secondary,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          ...primary,
                          ...secondary,
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _refreshFinancialData(WidgetRef ref) {
    ref.invalidate(transactionsProvider);
    ref.invalidate(transfersProvider);
    ref.invalidate(reservesWithMovementsProvider);
    ref.invalidate(investmentsProvider);
    ref.invalidate(goalsProvider);
  }
}

class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AnthillPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.soil.withValues(alpha: palette.isDark ? 0.5 : 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: palette.leaf),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12.5,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const LeaveAnthillButton.icon(),
      ],
    );
  }
}

/// Saída do formigueiro. Devolve o usuário ao Formetas financeiro e guarda a
/// escolha, para o aplicativo abrir onde ele estava.
class LeaveAnthillButton extends ConsumerWidget {
  const LeaveAnthillButton({super.key}) : _compact = false;

  const LeaveAnthillButton.icon({super.key}) : _compact = true;

  final bool _compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> leave() async {
      await ref.read(appModeProvider.notifier).backToFinances();
      if (context.mounted) context.go('/');
    }

    if (_compact) {
      return IconButton(
        tooltip: 'Voltar ao Formetas',
        onPressed: leave,
        icon: const Icon(Icons.exit_to_app_rounded),
      );
    }

    return OutlinedButton.icon(
      onPressed: leave,
      icon: const Icon(Icons.exit_to_app_rounded, size: 18),
      label: const Text('Voltar ao Formetas'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
