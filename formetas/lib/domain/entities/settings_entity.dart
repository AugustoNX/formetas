import 'package:equatable/equatable.dart';

enum AppThemeMode { light, dark, system }

/// Qual experiência o usuário escolheu abrir: o controle financeiro direto ou
/// o Formigueiro. É só uma preferência de navegação — os dados são os mesmos.
enum AppMode { financial, anthill }

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
