import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/default_categories.dart';
import '../../../domain/entities/category_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  TransactionType _filterType = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Despesas'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Receitas'),
                ),
              ],
              selected: {_filterType},
              onSelectionChanged: (s) => setState(() => _filterType = s.first),
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (list) {
                final filtered =
                    list.where((c) => c.type == _filterType).toList();
                final defaults =
                    filtered.where(DefaultCategories.isDefault).toList();
                final custom =
                    filtered.where((c) => !DefaultCategories.isDefault(c)).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _SectionHeader(
                      title: 'Padrões do app',
                      subtitle: 'Disponíveis para todos, não ocupam seu banco',
                    ),
                    ...defaults.map((cat) => _CategoryTile(
                          category: cat,
                          isDefault: true,
                        )),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Suas categorias',
                      subtitle: custom.isEmpty
                          ? 'Crie categorias personalizadas'
                          : '${custom.length} personalizada(s)',
                    ),
                    if (custom.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Nenhuma categoria personalizada ainda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.gray),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: custom.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex--;
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;

                          final reordered = List<CategoryEntity>.from(custom);
                          final item = reordered.removeAt(oldIndex);
                          reordered.insert(newIndex, item);

                          for (var i = 0; i < reordered.length; i++) {
                            await ref
                                .read(categoryRepositoryProvider)
                                .updateCategory(reordered[i].copyWith(order: i));
                          }
                        },
                        itemBuilder: (context, index) {
                          final cat = custom[index];
                          return _CategoryTile(
                            key: ValueKey(cat.id),
                            category: cat,
                            isDefault: false,
                            onEdit: () =>
                                _showCategoryDialog(context, category: cat),
                            onDelete: () async {
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;
                              await ref
                                  .read(categoryRepositoryProvider)
                                  .deleteCategory(user.id, cat.id);
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context, {
    CategoryEntity? category,
  }) async {
    if (category != null && DefaultCategories.isDefault(category)) return;

    final nameController = TextEditingController(text: category?.name ?? '');
    var selectedColor = category?.color ?? '#2F4F3F';
    const selectedIcon = 'category';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category != null ? 'Editar categoria' : 'Nova categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                '#EF4444',
                '#F97316',
                '#2F4F3F',
                '#4F7942',
                '#3B82F6',
                '#D4A017',
              ].map((c) {
                return GestureDetector(
                  onTap: () => selectedColor = c,
                  child: CircleAvatar(
                    backgroundColor: _parseColor(c),
                    radius: 16,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              final name = nameController.text.trim();
              if (user == null || name.isEmpty) return;

              final cat = CategoryEntity(
                id: category?.id ?? const Uuid().v4(),
                userId: user.id,
                name: name,
                color: selectedColor,
                icon: selectedIcon,
                type: _filterType,
                order: category?.order ?? 999,
              );

              if (category != null) {
                await ref.read(categoryRepositoryProvider).updateCategory(cat);
              } else {
                await ref.read(categoryRepositoryProvider).createCategory(cat);
              }

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.gray, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.category,
    required this.isDefault,
    this.onEdit,
    this.onDelete,
  });

  final CategoryEntity category;
  final bool isDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: _parseColor(category.color).withValues(alpha: 0.15),
        child: Icon(
          _parseIcon(category.icon),
          color: _parseColor(category.color),
        ),
      ),
      title: Text(category.name),
      subtitle: isDefault
          ? Text('Padrão', style: TextStyle(color: AppColors.gray, fontSize: 11))
          : null,
      trailing: isDefault
          ? Icon(Icons.lock_outline, size: 18, color: AppColors.gray)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.expense),
                  onPressed: onDelete,
                ),
                const Icon(Icons.drag_handle),
              ],
            ),
    );
  }

  Color _parseColor(String hex) {
    final value = hex.replaceAll('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  IconData _parseIcon(String name) {
    const icons = {
      'restaurant': Icons.restaurant_rounded,
      'shopping_cart': Icons.shopping_cart_rounded,
      'home': Icons.home_rounded,
      'directions_car': Icons.directions_car_rounded,
      'health_and_safety': Icons.health_and_safety_rounded,
      'payments': Icons.payments_rounded,
      'work': Icons.work_rounded,
      'wifi': Icons.wifi_rounded,
      'bolt': Icons.bolt_rounded,
      'water_drop': Icons.water_drop_rounded,
      'fitness_center': Icons.fitness_center_rounded,
      'sell': Icons.sell_rounded,
      'redeem': Icons.redeem_rounded,
      'stars': Icons.stars_rounded,
      'category': Icons.category_rounded,
    };
    return icons[name] ?? Icons.category_rounded;
  }
}
