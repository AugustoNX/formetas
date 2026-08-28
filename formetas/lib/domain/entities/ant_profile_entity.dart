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
  });

  static const defaultAntName = 'Formiguinha';

  final String antName;

  /// id da conquista -> momento em que foi desbloqueada pela primeira vez.
  final Map<String, DateTime> unlockedAchievements;

  final bool animationsEnabled;

  /// Último nível já comemorado, para não repetir a animação de evolução.
  final int celebratedLevel;

  final DateTime? createdAt;

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
  }) {
    return AntProfileEntity(
      antName: antName ?? this.antName,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      celebratedLevel: celebratedLevel ?? this.celebratedLevel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        antName,
        unlockedAchievements,
        animationsEnabled,
        celebratedLevel,
      ];
}
