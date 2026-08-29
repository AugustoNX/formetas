import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/asset_trade_entity.dart';
import '../../presentation/providers/app_mode_provider.dart';
import '../../presentation/providers/auth_controller.dart';
import '../../presentation/providers/core_providers.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/anthill/achievements_screen.dart';
import '../../presentation/screens/anthill/ant_care_screen.dart';
import '../../presentation/screens/anthill/anthill_entrance_screen.dart';
import '../../presentation/screens/anthill/anthill_missions_screen.dart';
import '../../presentation/screens/anthill/anthill_month_screen.dart';
import '../../presentation/screens/anthill/anthill_shell.dart';
import '../../presentation/screens/anthill/anthill_storage_screen.dart';
import '../../presentation/screens/assets/asset_detail_screen.dart';
import '../../presentation/screens/assets/asset_trade_form_screen.dart';
import '../../presentation/screens/categories/categories_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/goals/goal_form_screen.dart';
import '../../presentation/screens/goals/goals_screen.dart';
import '../../presentation/screens/investments/investment_form_screen.dart';
import '../../presentation/screens/reserves/reserve_detail_screen.dart';
import '../../presentation/screens/reserves/reserve_form_screen.dart';
import '../../presentation/screens/main/main_shell.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/transfer/transfer_screen.dart';
import '../../presentation/screens/transactions/transaction_form_screen.dart';
import '../../presentation/screens/transactions/transactions_screen.dart';
import '../../presentation/screens/wallet/wallet_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(
    ref.read(authRepositoryProvider).authStateChanges,
  );
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';
      if (isSplash) return null;

      // Durante login/cadastro o Firebase já cria a sessão; esperamos o
      // controller terminar para não pular a tela no meio do envio.
      if (ref.read(authControllerProvider).isLoading) return null;

      // currentUser do Firebase atualiza no mesmo instante do signOut.
      // O StreamProvider atrasa um tick e, se o redirect usar esse atraso,
      // a pessoa cai na Home como se ainda estivesse logada.
      final signedIn = ref.read(authRepositoryProvider).currentUser != null;

      if (!signedIn && !isAuthRoute) return '/auth/login';
      if (signedIn && isAuthRoute) {
        return ref.read(appModeProvider).homeRoute;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      // Experiência financeira: as cinco áreas do controle do dinheiro.
      ShellRoute(
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: TransactionsScreen(),
            ),
          ),
          GoRoute(
            path: '/carteira',
            pageBuilder: (_, state) => NoTransitionPage(
              child: WalletScreen(
                initialTab: WalletTab.fromQuery(
                  state.uri.queryParameters['aba'],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/goals',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: GoalsScreen(),
            ),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: ReportsScreen(),
            ),
          ),
        ],
      ),
      // Experiência do Formigueiro: os mesmos dados, lidos como salas.
      ShellRoute(
        builder: (_, _, child) => AnthillShell(child: child),
        routes: [
          GoRoute(
            path: '/formigueiro',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: AnthillEntranceScreen(),
            ),
          ),
          GoRoute(
            path: '/formigueiro/mes',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: AnthillMonthScreen(),
            ),
          ),
          GoRoute(
            path: '/formigueiro/armazens',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: AnthillStorageScreen(),
            ),
          ),
          GoRoute(
            path: '/formigueiro/missoes',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: AnthillMissionsScreen(),
            ),
          ),
          GoRoute(
            path: '/formigueiro/conquistas',
            pageBuilder: (_, _) => const NoTransitionPage(
              child: AchievementsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/transaction/new',
        builder: (_, state) {
          final type = state.uri.queryParameters['type'] ?? 'expense';
          return TransactionFormScreen(initialType: type);
        },
      ),
      GoRoute(
        path: '/transaction/edit/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return TransactionFormScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/ativo/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return AssetDetailScreen(assetId: id);
        },
      ),
      GoRoute(
        path: '/lancamento/novo',
        builder: (_, state) {
          final params = state.uri.queryParameters;
          return AssetTradeFormScreen(
            assetId: params['ativo'],
            initialType: switch (params['tipo']) {
              'venda' => AssetTradeType.sell,
              'provento' => AssetTradeType.dividend,
              _ => AssetTradeType.buy,
            },
          );
        },
      ),
      GoRoute(
        path: '/investment/new',
        builder: (_, _) => const InvestmentFormScreen(),
      ),
      GoRoute(
        path: '/investment/edit/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return InvestmentFormScreen(investmentId: id);
        },
      ),
      GoRoute(
        path: '/reserve/new',
        builder: (_, _) => const ReserveFormScreen(),
      ),
      GoRoute(
        path: '/reserve/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return ReserveDetailScreen(reserveId: id);
        },
      ),
      GoRoute(
        path: '/reserve/edit/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return ReserveFormScreen(reserveId: id);
        },
      ),
      GoRoute(
        path: '/goal/new',
        builder: (_, _) => const GoalFormScreen(),
      ),
      GoRoute(
        path: '/goal/edit/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return GoalFormScreen(goalId: id);
        },
      ),
      GoRoute(
        path: '/transfer',
        builder: (_, state) {
          final params = state.uri.queryParameters;
          return TransferScreen(
            initialFrom: params['from'],
            initialTo: params['to'],
            initialFromId: params['fromId'],
            initialToId: params['toId'],
          );
        },
      ),
      GoRoute(
        path: '/formigueiro/formiga',
        builder: (_, _) => const AntCareScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (_, _) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );

  ref.listen(authControllerProvider, (_, _) => router.refresh());
  return router;
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
