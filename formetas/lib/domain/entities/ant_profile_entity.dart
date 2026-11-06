import 'package:equatable/equatable.dart';

/// Dados exclusivos da gamificação.
///
/// Nada aqui participa de cálculo financeiro: guarda apenas personalização,
/// quando cada conquista foi desbloqueada e preferências de animação.
class AntProfileEntity extends Equatable {
  const AntProfileEntity({
    this.antName = defaultAntName,
    this.unlockedAchievements = const {},
    this.animationsEnabled = true,
    this.celebratedLevel = 0,
    this.createdAt,
    this.trailCategory,
    this.trailStartedOn,
    this.trailCelebrated = false,
    this.celebratedMissionId,
  });

  static const defaultAntName = 'Formiguinha';

  final String antName;

  /// id da conquista -> momento em que foi desbloqueada pela primeira vez.
  final Map<String, DateTime> unlockedAchievements;

  final bool animationsEnabled;

  /// Último nível já comemorado, para não repetir a animação de evolução.
  final int celebratedLevel;

  final DateTime? createdAt;

  /// Categoria da trilha de 7 dias. Nula quando não há trilha em andamento.
  final String? trailCategory;
  final DateTime? trailStartedOn;
  final bool trailCelebrated;

  /// Semana cuja missão já foi comemorada.
  final String? celebratedMissionId;

  bool isUnlocked(String achievementId) =>
      unlockedAchievements.containsKey(achievementId);

  DateTime? unlockedAt(String achievementId) =>
      unlockedAchievements[achievementId];

  int get unlockedCount => unlockedAchievements.length;

  AntProfileEntity copyWith({
    String? antName,
    Map<String, DateTime>? unlockedAchievements,
    bool? animationsEnabled,
    int? celebratedLevel,
    DateTime? createdAt,
    String? trailCategory,
    DateTime? trailStartedOn,
    bool? trailCelebrated,
    String? celebratedMissionId,
  }) {
    return AntProfileEntity(
      antName: antName ?? this.antName,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      celebratedLevel: celebratedLevel ?? this.celebratedLevel,
      createdAt: createdAt ?? this.createdAt,
      trailCategory: trailCategory ?? this.trailCategory,
      trailStartedOn: trailStartedOn ?? this.trailStartedOn,
      trailCelebrated: trailCelebrated ?? this.trailCelebrated,
      celebratedMissionId: celebratedMissionId ?? this.celebratedMissionId,
    );
  }

  @override
  List<Object?> get props => [
        antName,
        unlockedAchievements,
        animationsEnabled,
        celebratedLevel,
        trailCategory,
        trailStartedOn,
        trailCelebrated,
        celebratedMissionId,
      ];
}
