import '../entities/ant_profile_entity.dart';

/// Acesso aos dados exclusivos da gamificação.
///
/// Vive em um nó próprio do banco e não toca em nenhuma informação financeira.
abstract class AnthillRepository {
  Stream<AntProfileEntity> watchProfile(String userId);

  Future<AntProfileEntity> getProfile(String userId);

  Future<void> updateAntName(String userId, String name);

  Future<void> updateAnimationsEnabled(String userId, bool enabled);

  Future<void> updateCelebratedLevel(String userId, int level);

  /// Registra o momento em que cada conquista foi alcançada pela primeira vez.
  Future<void> unlockAchievements(
    String userId,
    Map<String, DateTime> unlockedAt,
  );

  /// Primeira gravação do perfil.
  ///
  /// Quem já usava o Formetas antes da gamificação entra no Formigueiro com o
  /// histórico reconhecido de uma vez, sem uma enxurrada de comemorações.
  Future<void> initialize(String userId, AntProfileEntity profile);
}
