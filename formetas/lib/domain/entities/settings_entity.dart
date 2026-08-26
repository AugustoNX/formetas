import 'package:equatable/equatable.dart';

enum AppThemeMode { light, dark, system }

class SettingsEntity extends Equatable {
  const SettingsEntity({
    this.currency = 'BRL',
    this.theme = AppThemeMode.system,
    this.notificationsEnabled = true,
    this.firstDayOfMonth = 1,
    this.cdiRate = 13.25,
  });

  final String currency;
  final AppThemeMode theme;
  final bool notificationsEnabled;
  final int firstDayOfMonth;
  final double cdiRate;

  SettingsEntity copyWith({
    String? currency,
    AppThemeMode? theme,
    bool? notificationsEnabled,
    int? firstDayOfMonth,
    double? cdiRate,
  }) {
    return SettingsEntity(
      currency: currency ?? this.currency,
      theme: theme ?? this.theme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      firstDayOfMonth: firstDayOfMonth ?? this.firstDayOfMonth,
      cdiRate: cdiRate ?? this.cdiRate,
    );
  }

  @override
  List<Object?> get props => [currency, theme, cdiRate];
}
