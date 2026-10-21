import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/settings_entity.dart';
import '../../domain/services/onboarding_service.dart';
import 'app_mode_provider.dart';
import 'core_providers.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    reserveRepository: ref.watch(reserveRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
    nextId: () => const Uuid().v4(),
  );
});

/// Rota depois do login: onboarding na primeira vez, senão a home do modo.
String resolveLandingRoute({
  required String? userId,
  required bool onboardingComplete,
  required AppMode appMode,
}) {
  if (userId == null) return '/auth/login';
  if (!onboardingComplete) return '/onboarding';
  return appMode.homeRoute;
}

String landingRoute(Ref ref) {
  final user = ref.read(authRepositoryProvider).currentUser;
  return resolveLandingRoute(
    userId: user?.id,
    onboardingComplete: user == null
        ? true
        : ref.read(settingsLocalDataSourceProvider).isOnboardingComplete(user.id),
    appMode: ref.read(appModeProvider),
  );
}
