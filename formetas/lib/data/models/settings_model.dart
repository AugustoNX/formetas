import '../../domain/entities/settings_entity.dart';

class SettingsModel extends SettingsEntity {
  const SettingsModel({
    super.currency,
    super.theme,
    super.notificationsEnabled,
    super.firstDayOfMonth,
    super.cdiRate,
  });

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      currency: map['moeda'] as String? ?? map['currency'] as String? ?? 'BRL',
      theme: _parseTheme(map['tema'] ?? map['theme']),
      notificationsEnabled: map['notificações'] as bool? ??
          map['notificacoes'] as bool? ??
          map['notificationsEnabled'] as bool? ??
          true,
      firstDayOfMonth: map['primeiroDiaDoMes'] as int? ??
          map['firstDayOfMonth'] as int? ??
          1,
      cdiRate: (map['cdiRate'] ?? map['taxaCDI'] ?? 13.25).toDouble(),
    );
  }

  factory SettingsModel.fromEntity(SettingsEntity entity) {
    return SettingsModel(
      currency: entity.currency,
      theme: entity.theme,
      notificationsEnabled: entity.notificationsEnabled,
      firstDayOfMonth: entity.firstDayOfMonth,
      cdiRate: entity.cdiRate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moeda': currency,
      'tema': theme.name,
      'notificações': notificationsEnabled,
      'primeiroDiaDoMes': firstDayOfMonth,
      'cdiRate': cdiRate,
    };
  }

  static AppThemeMode _parseTheme(dynamic value) {
    final str = value?.toString() ?? 'system';
    return AppThemeMode.values.firstWhere(
      (e) => e.name == str,
      orElse: () => AppThemeMode.system,
    );
  }
}
