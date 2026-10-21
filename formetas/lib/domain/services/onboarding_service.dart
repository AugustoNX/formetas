import '../entities/onboarding_draft.dart';
import '../entities/settings_entity.dart';
import '../repositories/reserve_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/user_repository.dart';
import 'onboarding_planner.dart';

typedef IdFactory = String Function();

class OnboardingService {
  const OnboardingService({
    required TransactionRepository transactionRepository,
    required ReserveRepository reserveRepository,
    required UserRepository userRepository,
    required this.nextId,
  })  : _transactions = transactionRepository,
        _reserves = reserveRepository,
        _users = userRepository;

  final TransactionRepository _transactions;
  final ReserveRepository _reserves;
  final UserRepository _users;
  final IdFactory nextId;

  Future<void> complete({
    required String userId,
    required OnboardingDraft draft,
    required SettingsEntity settings,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();

    final opening = OnboardingPlanner.openingTransaction(
      id: nextId(),
      userId: userId,
      availableBalance: draft.availableBalance,
      at: now,
    );
    if (opening != null) {
      await _transactions.createTransaction(opening);
    }

    final reserves = OnboardingPlanner.reserves(
      userId: userId,
      draft: draft,
      at: now,
      cdiRate: settings.cdiRate,
      nextId: nextId,
    );
    for (final reserve in reserves) {
      await _reserves.createReserve(reserve);
    }

    await markCompleted(userId: userId, settings: settings);
  }

  Future<void> markCompleted({
    required String userId,
    required SettingsEntity settings,
  }) async {
    if (settings.onboardingCompleted) return;
    await _users.updateSettings(
      userId,
      settings.copyWith(onboardingCompleted: true),
    );
  }
}
