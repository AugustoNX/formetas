import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/') return 0;
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/investments')) return 2;
    if (location.startsWith('/goals')) return 3;
    if (location.startsWith('/reports')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/transactions');
      case 2:
        context.go('/investments');
      case 3:
        context.go('/goals');
      case 4:
        context.go('/reports');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz_rounded),
            label: 'Movimentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up_rounded),
            label: 'Investir',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: 'Metas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nova movimentação',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _AddOption(
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
                label: 'Receita',
                subtitle: 'Salário, freelance, dividendos...',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/transaction/new?type=income');
                },
              ),
              _AddOption(
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
                label: 'Despesa',
                subtitle: 'Registrar seus gastos',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/transaction/new?type=expense');
                },
              ),
              _AddOption(
                icon: Icons.swap_horiz_rounded,
                color: AppColors.primary,
                label: 'Transferir',
                subtitle: 'Mover entre saldo, caixinha e investimentos',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/transfer');
                },
              ),
              _AddOption(
                icon: Icons.savings_outlined,
                color: AppColors.secondary,
                label: 'Caixinha',
                subtitle: 'Reserva, CDB, poupança, CDI...',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/reserves');
                },
              ),
              _AddOption(
                icon: Icons.trending_up_rounded,
                color: AppColors.investment,
                label: 'Investimentos',
                subtitle: 'Ver carteira e transferir',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/investments');
                },
              ),
              _AddOption(
                icon: Icons.flag_rounded,
                color: AppColors.gold,
                label: 'Meta',
                subtitle: 'Definir um objetivo',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/goal/new');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.gray, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
