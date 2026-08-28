import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/settings_local_datasource.dart';
import '../../domain/entities/settings_entity.dart';
import 'core_providers.dart';

/// Guarda em qual experiência o usuário está: o Formetas financeiro ou o
/// Formigueiro. A escolha fica salva no aparelho e decide apenas onde o
/// aplicativo abre e qual navegação aparece.
class AppModeController extends StateNotifier<AppMode> {
  AppModeController(this._local) : super(_local.getAppMode());

  final SettingsLocalDataSource _local;

  Future<void> enterAnthill() => _set(AppMode.anthill);

  Future<void> backToFinances() => _set(AppMode.financial);

  Future<void> _set(AppMode mode) async {
    if (state == mode) return;
    state = mode;
    await _local.setAppMode(mode);
  }
}

final appModeProvider = StateNotifierProvider<AppModeController, AppMode>((ref) {
  return AppModeController(ref.watch(settingsLocalDataSourceProvider));
});

/// Rota inicial de cada experiência, usada pela splash e pelos botões de troca.
extension AppModeRoute on AppMode {
  String get homeRoute => switch (this) {
        AppMode.financial => '/',
        AppMode.anthill => '/formigueiro',
      };
}
