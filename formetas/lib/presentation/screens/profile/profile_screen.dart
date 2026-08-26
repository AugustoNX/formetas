import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_controller.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (user?.name.isNotEmpty == true ? user!.name[0] : 'F')
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(user?.email ?? '', style: TextStyle(color: AppColors.gray)),
                if (user?.emailVerified == false) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).sendEmailVerification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('E-mail de verificação enviado!'),
                          ),
                        );
                      }
                    },
                    child: const Text('Verificar e-mail'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco_rounded, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.tagline,
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configurações'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorias'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/categories'),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.expense),
            title: const Text(
              'Sair',
              style: TextStyle(color: AppColors.expense),
            ),
            onTap: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
        ],
      ),
    );
  }
}
