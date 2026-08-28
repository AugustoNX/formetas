import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/settings_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _cdiRate = AppConstants.defaultCdiRate;
  AppThemeMode _theme = AppThemeMode.system;
  bool _notifications = true;
  int _firstDayOfMonth = 1;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    settings.whenData((s) {
      if (!_loaded) {
        _cdiRate = s.cdiRate;
        _theme = s.theme;
        _notifications = s.notificationsEnabled;
        _firstDayOfMonth = s.firstDayOfMonth;
        _loaded = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Preferências',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tema'),
            subtitle: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.light, label: Text('Claro')),
                ButtonSegment(value: AppThemeMode.dark, label: Text('Escuro')),
                ButtonSegment(value: AppThemeMode.system, label: Text('Auto')),
              ],
              selected: {_theme},
              onSelectionChanged: (s) => setState(() => _theme = s.first),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notificações'),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Primeiro dia do mês'),
            subtitle: Slider(
              value: _firstDayOfMonth.toDouble(),
              min: 1,
              max: 28,
              divisions: 27,
              label: '$_firstDayOfMonth',
              onChanged: (v) => setState(() => _firstDayOfMonth = v.toInt()),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Taxa CDI',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajuste a taxa CDI para simulações de rendimento.',
            style: TextStyle(color: AppColors.gray, fontSize: 13),
          ),
          Slider(
            value: _cdiRate,
            min: 5,
            max: 20,
            divisions: 30,
            label: '${_cdiRate.toStringAsFixed(2)}% a.a.',
            onChanged: (v) => setState(() => _cdiRate = v),
          ),
          Text(
            'CDI atual: ${_cdiRate.toStringAsFixed(2)}% ao ano',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Salvar configurações'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final settings = SettingsEntity(
      theme: _theme,
      notificationsEnabled: _notifications,
      firstDayOfMonth: _firstDayOfMonth,
      cdiRate: _cdiRate,
    );

    await ref.read(userRepositoryProvider).updateSettings(user.id, settings);
    await ref.read(settingsLocalDataSourceProvider).setThemeMode(_theme);
    ref.read(themeModeProvider.notifier).state = _theme;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }
}
