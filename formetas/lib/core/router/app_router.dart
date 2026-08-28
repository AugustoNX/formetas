import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_controller.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/core_providers.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/categories/categories_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/goals/goal_form_screen.dart';
import '../../presentation/screens/goals/goals_screen.dart';
import '../../presentation/screens/investments/investment_form_screen.dart';
import '../../presentation/screens/investments/investments_screen.dart';
import '../../presentation/screens/reserves/reserve_detail_screen.dart';
import '../../presentation/screens/reserves/reserve_form_screen.dart';
import '../../presentation/screens/reserves/reserves_screen.dart';
import '../../presentation/screens/main/main_shell.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/transfer/transfer_screen.dart';
import '../../presentation/screens/transactions/transaction_form_screen.dart';
import '../../presentation/screens/transactions/transactions_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshStream(
    ref.read(authRepositoryProvider).authStateChanges,
  );
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isBusy = ref.read(authControllerProvider).isLoading;
      final user = authState.valueOrNull;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;
      if (isBusy) return null;
      if (authState.isLoading) return null;

      if (user == null && !isAuthRoute) return '/auth/login';
      if (user != null && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: TransactionsScreen(),
            ),
          ),
          GoRoute(
            path: '/investments',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: InvestmentsScreen(),
            ),
          ),
          GoRoute(
            path: '/goals',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: GoalsScreen(),
            ),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (_, __) => const NoTransitionPage(
              child: ReportsScreen(),
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
        path: '/investment/new',
        builder: (_, __) => const InvestmentFormScreen(),
      ),
      GoRoute(
        path: '/investment/edit/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return InvestmentFormScreen(investmentId: id);
        },
      ),
      GoRoute(
        path: '/reserves',
        builder: (_, __) => const ReservesScreen(),
      ),
      GoRoute(
        path: '/reserve/new',
        builder: (_, __) => const ReserveFormScreen(),
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
        builder: (_, __) => const GoalFormScreen(),
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
        path: '/categories',
        builder: (_, __) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );

  ref.listen(authControllerProvider, (_, __) => router.refresh());
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
