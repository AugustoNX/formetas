import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/ant_brain.dart';
import '../providers/ant_brain_providers.dart';

/// Taxa de acerto, exemplos e os botões de reaprender ou zerar.
class AntBrainSection extends ConsumerStatefulWidget {
  const AntBrainSection({super.key});

  @override
  ConsumerState<AntBrainSection> createState() => _AntBrainSectionState();
}

class _AntBrainSectionState extends ConsumerState<AntBrainSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final brain = ref.watch(antBrainProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cérebro da formiga',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'A formiga lembra, neste aparelho, como você categoriza. '
          'Isso fica só na sua conta.',
          style: TextStyle(color: AppColors.gray, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 12),
        brain.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Não consegui abrir o aprendizado agora.'),
              TextButton(
                onPressed: () => ref.invalidate(antBrainProvider),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
          data: (snapshot) => _Body(
            snapshot: snapshot,
            busy: _busy,
            onRelearn: _relearn,
            onReset: _reset,
          ),
        ),
      ],
    );
  }

  Future<void> _relearn() async {
    setState(() => _busy = true);
    try {
      final count = await ref
          .read(antBrainProvider.notifier)
          .relearnFromHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaprendi com $count exemplos do histórico.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui reaprender agora.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zerar aprendizado'),
        content: const Text(
          'A formiga esquece os exemplos que aprendeu. '
          'As regras do extrato continuam valendo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Zerar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(antBrainProvider.notifier).reset();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aprendizado zerado.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui zerar agora.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.snapshot,
    required this.busy,
    required this.onRelearn,
    required this.onReset,
  });

  final AntBrainSnapshot snapshot;
  final bool busy;
  final VoidCallback onRelearn;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final rate = snapshot.recentRate;
    final examples = snapshot.model.exampleCount;
    final history = snapshot.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          examples == 1
              ? '1 exemplo aprendido'
              : '$examples exemplos aprendidos',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          rate == null
              ? 'Ainda não há importações para medir.'
              : 'Acertou ${(rate * 100).round()}% nas últimas importações.',
          style: TextStyle(color: AppColors.gray, height: 1.35),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 1,
                barTouchData: BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                barGroups: [
                  for (var i = 0; i < history.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: history[i].rate ?? 0,
                          width: 12,
                          color: AppColors.secondary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Text(
            'Cada barra é uma importação.',
            style: TextStyle(color: AppColors.gray, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy ? null : onRelearn,
          child: const Text('Reaprender do histórico'),
        ),
        TextButton(
          onPressed: busy ? null : onReset,
          style: TextButton.styleFrom(foregroundColor: AppColors.expense),
          child: const Text('Zerar aprendizado'),
        ),
      ],
    );
  }
}
