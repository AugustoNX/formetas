import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/anthill_remote_datasource.dart';
import '../../data/repositories/anthill_repository_impl.dart';
import '../../domain/entities/ant_profile_entity.dart';
import '../../domain/entities/anthill_snapshot.dart';
import '../../domain/repositories/anthill_repository.dart';
import '../../domain/services/anthill_service.dart';
import 'auth_provider.dart';
import 'data_providers.dart';

/// Toda a injeção de dependências da gamificação vive aqui.
///
/// Se um dia o Formigueiro for removido, basta apagar este arquivo, a pasta de
/// telas e o item de navegação: nada do sistema financeiro depende daqui.

final anthillRemoteDataSourceProvider =
    Provider<AnthillRemoteDataSource>((ref) => AnthillRemoteDataSource());

final anthillRepositoryProvider = Provider<AnthillRepository>((ref) {
  return AnthillRepositoryImpl(ref.watch(anthillRemoteDataSourceProvider));
});

final anthillServiceProvider =
    Provider<AnthillService>((ref) => const AnthillService());

final antProfileProvider = StreamProvider<AntProfileEntity>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const AntProfileEntity());
  return ref.watch(anthillRepositoryProvider).watchProfile(user.id);
});

/// Estado do Formigueiro derivado dos dados financeiros reais.
final anthillSnapshotProvider = Provider<AsyncValue<AnthillSnapshot>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading || auth.valueOrNull == null) {
    return const AsyncValue.loading();
  }

  final profile = ref.watch(antProfileProvider);
  final transactions = ref.watch(transactionsProvider);
  final transfers = ref.watch(transfersProvider);
  final reserves = ref.watch(reservesWithMovementsProvider);
  final investments = ref.watch(investmentsProvider);
  final goals = ref.watch(goalsProvider);
  final settings = ref.watch(settingsProvider);

  final sources = [
    profile,
    transactions,
    transfers,
    reserves,
    investments,
    goals,
    settings,
  ];

  for (final source in sources) {
    if (source.hasError) {
      return AsyncValue.error(source.error!, source.stackTrace!);
    }
  }
  if (sources.any((source) => source.isLoading)) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    ref.watch(anthillServiceProvider).buildSnapshot(
          profile: profile.requireValue,
          transactions: transactions.requireValue,
          transfers: transfers.requireValue,
          reserves: reserves.requireValue,
          investments: investments.requireValue,
          goals: goals.requireValue,
          settings: settings.requireValue,
        ),
  );
});

enum CelebrationKind { achievement, levelUp, mission }

class AnthillCelebration {
  const AnthillCelebration({
    required this.kind,
    required this.title,
    required this.message,
    required this.icon,
  });

  final CelebrationKind kind;
  final String title;
  final String message;
  final AntIcon icon;
}

/// Persiste conquistas recém-alcançadas e enfileira as comemorações.
///
/// O que define se uma conquista foi alcançada continua sendo o dado
/// financeiro; aqui só guardamos *quando* isso aconteceu pela primeira vez.
class AnthillSyncController extends StateNotifier<List<AnthillCelebration>> {
  AnthillSyncController(this._ref) : super(const []);

  final Ref _ref;
  bool _busy = false;

  Future<void> sync(AnthillSnapshot snapshot) async {
    if (_busy) return;

    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final profile = snapshot.profile;
    final repository = _ref.read(anthillRepositoryProvider);
    final now = DateTime.now();

    final earned = snapshot.achievements.where((a) => a.isEarned);
    final pending = {
      for (final achievement in earned)
        if (!profile.isUnlocked(achievement.id)) achievement.id: now,
    };

    _busy = true;
    try {
      if (profile.createdAt == null) {
        await repository.initialize(
          user.id,
          profile.copyWith(
            unlockedAchievements: {...profile.unlockedAchievements, ...pending},
            celebratedLevel: snapshot.level.level,
            createdAt: now,
          ),
        );
        return;
      }

      if (pending.isNotEmpty) {
        await repository.unlockAchievements(user.id, pending);
        _enqueue([
          for (final achievement in snapshot.achievements)
            if (pending.containsKey(achievement.id))
              AnthillCelebration(
                kind: CelebrationKind.achievement,
                title: 'Conquista desbloqueada',
                message: achievement.definition.title,
                icon: achievement.definition.icon,
              ),
        ]);
      }

      if (snapshot.level.level > profile.celebratedLevel) {
        await repository.updateCelebratedLevel(user.id, snapshot.level.level);
        _enqueue([
          AnthillCelebration(
            kind: CelebrationKind.levelUp,
            title: 'Sua formiga evoluiu!',
            message: snapshot.level.title,
            icon: AntIcon.star,
          ),
        ]);
      }
    } finally {
      _busy = false;
    }
  }

  void _enqueue(List<AnthillCelebration> celebrations) {
    if (celebrations.isEmpty) return;
    if (!mounted) return;
    // Evita transformar a experiência em uma fila cansativa de pop-ups.
    state = [...state, ...celebrations].take(3).toList();
  }

  void dismissCurrent() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }
}

final anthillSyncProvider =
    StateNotifierProvider<AnthillSyncController, List<AnthillCelebration>>(
  (ref) => AnthillSyncController(ref),
);

/// Frase curta usada como reforço positivo após guardar folhinhas.
final anthillPositiveFeedbackProvider = Provider<String Function(double)>((ref) {
  return (double amount) {
    final leaves = amount.round();
    if (leaves <= 0) return 'Sua formiga agradece.';
    return 'Mais $leaves folhinhas para o formigueiro.';
  };
});
