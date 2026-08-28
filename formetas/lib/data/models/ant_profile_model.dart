import '../../domain/entities/ant_profile_entity.dart';

class AntProfileModel extends AntProfileEntity {
  const AntProfileModel({
    super.antName,
    super.unlockedAchievements,
    super.animationsEnabled,
    super.celebratedLevel,
    super.createdAt,
  });

  factory AntProfileModel.fromMap(Map<String, dynamic> map) {
    final name = (map['nomeFormiga'] ?? map['antName'])?.toString().trim();
    final level = map['nivelCelebrado'] ?? map['celebratedLevel'];

    return AntProfileModel(
      antName: name == null || name.isEmpty
          ? AntProfileEntity.defaultAntName
          : name,
      unlockedAchievements:
          _parseAchievements(map['conquistas'] ?? map['achievements']),
      animationsEnabled:
          map['animacoes'] as bool? ?? map['animationsEnabled'] as bool? ?? true,
      celebratedLevel: level is num ? level.toInt() : 0,
      createdAt: _parseDate(map['criadoEm'] ?? map['createdAt']),
    );
  }

  factory AntProfileModel.fromEntity(AntProfileEntity entity) {
    return AntProfileModel(
      antName: entity.antName,
      unlockedAchievements: entity.unlockedAchievements,
      animationsEnabled: entity.animationsEnabled,
      celebratedLevel: entity.celebratedLevel,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nomeFormiga': antName,
      'animacoes': animationsEnabled,
      'nivelCelebrado': celebratedLevel,
      'criadoEm': (createdAt ?? DateTime.now()).toIso8601String(),
      'conquistas': {
        for (final entry in unlockedAchievements.entries)
          entry.key: entry.value.toIso8601String(),
      },
    };
  }

  static Map<String, DateTime> _parseAchievements(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, DateTime>{};
    value.forEach((key, raw) {
      final date = _parseDate(raw);
      if (date != null) result[key.toString()] = date;
    });
    return result;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.tryParse(value.toString());
  }
}
