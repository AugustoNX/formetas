import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../widgets/anthill/ant_character.dart';
import '../../widgets/anthill/anthill_celebration_host.dart';
import '../../widgets/anthill/anthill_palette.dart';
import '../../widgets/anthill/anthill_room.dart';

/// Navegação do Formigueiro.
///
/// É a mesma estrutura do [MainShell] financeiro, mas com as salas no lugar das
/// abas: entrar no formigueiro troca a navegação inteira, não só a tela.
class AnthillShell extends StatelessWidget {
  const AnthillShell({super.key, required this.child});

  final Widget child;

  static const _rooms = [
    (
      icon: Icons.terrain_outlined,
      selected: Icons.terrain_rounded,
      label: 'Entrada',
      route: '/formigueiro',
    ),
    (
      icon: Icons.calendar_month_outlined,
      selected: Icons.calendar_month_rounded,
      label: 'O mês',
      route: '/formigueiro/mes',
    ),
    (
      icon: Icons.inventory_2_outlined,
      selected: Icons.inventory_2_rounded,
      label: 'Armazéns',
      route: '/formigueiro/armazens',
    ),
    (
      icon: Icons.flag_outlined,
      selected: Icons.flag_rounded,
      label: 'Missões',
      route: '/formigueiro/missoes',
    ),
    (
      icon: Icons.emoji_events_outlined,
      selected: Icons.emoji_events_rounded,
      label: 'Conquistas',
      route: '/formigueiro/conquistas',
    ),
  ];

  static const _entranceRoute = '/formigueiro';

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == _entranceRoute) return 0;

    final index = _rooms.indexWhere(
      (room) =>
          room.route != _entranceRoute && location.startsWith(room.route),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

    void goToRoom(int index) => context.go(_rooms[index].route);

    if (isDesktop) {
      return AnthillCelebrationHost(
        child: _DesktopRooms(
          currentIndex: _currentIndex(context),
          onRoomSelected: goToRoom,
          child: child,
        ),
      );
    }

    return AnthillCelebrationHost(
      child: Scaffold(
        backgroundColor: palette.roomBackground,
        body: child,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              context.push('/transfer?from=balance&to=reserve'),
          backgroundColor: palette.leaf,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.eco_rounded),
          label: const Text('Guardar'),
        ),
        bottomNavigationBar: _RoomsNavigation(
          currentIndex: _currentIndex(context),
          onRoomSelected: goToRoom,
        ),
      ),
    );
  }
}

class _RoomsNavigation extends StatelessWidget {
  const _RoomsNavigation({
    required this.currentIndex,
    required this.onRoomSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onRoomSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final media = MediaQuery.of(context);

    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: 1.1),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 22)),
        ),
        child: NavigationBar(
          height: 74,
          backgroundColor: palette.surface,
          indicatorColor: palette.leaf.withValues(alpha: 0.18),
          selectedIndex: currentIndex,
          onDestinationSelected: onRoomSelected,
          destinations: [
            for (final room in AnthillShell._rooms)
              NavigationDestination(
                icon: Icon(room.icon),
                selectedIcon: Icon(room.selected, color: palette.leaf),
                label: room.label,
                tooltip: room.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopRooms extends StatelessWidget {
  const _DesktopRooms({
    required this.currentIndex,
    required this.onRoomSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onRoomSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AnthillPalette.of(context);
    final extended =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.desktopExtended;

    return Scaffold(
      backgroundColor: palette.roomBackground,
      body: Row(
        children: [
          ColoredBox(
            color: palette.surface,
            child: SafeArea(
              right: false,
              child: NavigationRail(
                extended: extended,
                scrollable: true,
                minWidth: 88,
                minExtendedWidth: 232,
                selectedIndex: currentIndex,
                onDestinationSelected: onRoomSelected,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                backgroundColor: palette.surface,
                indicatorColor: palette.leaf.withValues(alpha: 0.18),
                leading: Padding(
                  padding: EdgeInsets.fromLTRB(
                    extended ? 12 : 0,
                    12,
                    extended ? 12 : 0,
                    24,
                  ),
                  child: Column(
                    children: [
                      AntCharacter(
                        level: 1,
                        size: extended ? 64 : 48,
                        animated: false,
                      ),
                      if (extended) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Formigueiro',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: extended ? 208 : 56,
                        child: extended
                            ? const LeaveAnthillButton()
                            : const LeaveAnthillButton.icon(),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  for (final room in AnthillShell._rooms)
                    NavigationRailDestination(
                      icon: Icon(room.icon),
                      selectedIcon: Icon(room.selected, color: palette.leaf),
                      label: Text(room.label),
                    ),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: palette.muted.withValues(alpha: 0.2),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
