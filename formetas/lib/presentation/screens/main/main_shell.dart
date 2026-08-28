import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/layout/adaptive_layout.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Início'),
    (
      icon: Icons.swap_horiz_outlined,
      selected: Icons.swap_horiz_rounded,
      label: 'Movimentos',
    ),
    (
      icon: Icons.trending_up_outlined,
      selected: Icons.trending_up_rounded,
      label: 'Investir',
    ),
    (icon: Icons.flag_outlined, selected: Icons.flag_rounded, label: 'Metas'),
    (
      icon: Icons.bar_chart_outlined,
      selected: Icons.bar_chart_rounded,
      label: 'Relatórios',
    ),
  ];

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
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

    if (isDesktop) {
      return _DesktopShell(
        currentIndex: _currentIndex(context),
        onDestinationSelected: (i) => _onTap(context, i),
        onAdd: () => _showAddMenu(context, desktop: true),
        child: child,
      );
    }

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenu(context, desktop: false),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: [
          for (final item in _destinations)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selected),
              label: item.label,
            ),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context, {required bool desktop}) {
    void open(String route) {
      Navigator.pop(context);
      context.push(route);
    }

    final content = _AddMenuContent(onSelect: open);

    if (desktop) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: content,
            ),
          ),
        ),
      );
      return;
    }

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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: content,
        ),
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onAdd,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final extended =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.desktopExtended;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railColor = isDark ? AppColors.darkSurface : AppColors.white;

    return Scaffold(
      body: Row(
        children: [
          ColoredBox(
            color: railColor,
            child: SafeArea(
              right: false,
              child: NavigationRail(
                extended: extended,
                minWidth: 88,
                minExtendedWidth: 232,
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                backgroundColor: railColor,
                leading: Padding(
                  padding: EdgeInsets.fromLTRB(
                    extended ? 12 : 0,
                    12,
                    extended ? 12 : 0,
                    24,
                  ),
                  child: Column(
                    children: [
                      if (extended)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.eco_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppStrings.appName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: extended ? 208 : 48,
                        child: extended
                            ? FilledButton.icon(
                                onPressed: onAdd,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Novo'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              )
                            : FloatingActionButton(
                                onPressed: onAdd,
                                mini: true,
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                child: const Icon(Icons.add_rounded),
                              ),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  for (final item in MainShell._destinations)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selected),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.gray.withValues(alpha: 0.2),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AddMenuContent extends StatelessWidget {
  const _AddMenuContent({required this.onSelect});

  final void Function(String route) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nova movimentação',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _AddOption(
          icon: Icons.arrow_downward_rounded,
          color: AppColors.income,
          label: 'Receita',
          subtitle: 'Salário, freelance, dividendos...',
          onTap: () => onSelect('/transaction/new?type=income'),
        ),
        _AddOption(
          icon: Icons.arrow_upward_rounded,
          color: AppColors.expense,
          label: 'Despesa',
          subtitle: 'Registrar seus gastos',
          onTap: () => onSelect('/transaction/new?type=expense'),
        ),
        _AddOption(
          icon: Icons.swap_horiz_rounded,
          color: AppColors.primary,
          label: 'Transferir',
          subtitle: 'Mover entre saldo, caixinha e investimentos',
          onTap: () => onSelect('/transfer'),
        ),
        _AddOption(
          icon: Icons.savings_outlined,
          color: AppColors.secondary,
          label: 'Caixinha',
          subtitle: 'Reserva, CDB, poupança, CDI...',
          onTap: () => onSelect('/reserves'),
        ),
        _AddOption(
          icon: Icons.trending_up_rounded,
          color: AppColors.investment,
          label: 'Investimentos',
          subtitle: 'Ver carteira e transferir',
          onTap: () => onSelect('/investments'),
        ),
        _AddOption(
          icon: Icons.flag_rounded,
          color: AppColors.gold,
          label: 'Meta',
          subtitle: 'Definir um objetivo',
          onTap: () => onSelect('/goal/new'),
        ),
      ],
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
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
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
