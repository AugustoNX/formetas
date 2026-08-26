import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.type,
    required this.selectedName,
    required this.onSelected,
    required this.onCreateCategory,
  });

  final List<CategoryEntity> categories;
  final TransactionType type;
  final String? selectedName;
  final ValueChanged<String> onSelected;
  final Future<void> Function(String name) onCreateCategory;

  List<CategoryEntity> get _filtered {
    return categories.where((c) => c.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    if (filtered.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Categoria',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Criar primeira categoria'),
          ),
        ],
      );
    }

    final effectiveSelection = selectedName != null &&
            filtered.any((c) => c.name == selectedName)
        ? selectedName!
        : filtered.first.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categoria',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered.map((cat) {
            final isSelected = cat.name == effectiveSelection;
            return _CategoryChip(
              category: cat,
              isSelected: isSelected,
              accentColor: _accentColorForType(type),
              onTap: () => onSelected(cat.name),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nome da categoria',
            hintText: type == TransactionType.income ? 'Ex: Salário' : 'Ex: Alimentação',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (created != null && created.isNotEmpty) {
      await onCreateCategory(created);
      onSelected(created);
    }
  }

  Color _accentColorForType(TransactionType type) => AppColors.primary;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final CategoryEntity category;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(category.color);
    final baseGreen = accentColor.withValues(alpha: 0.12);
    final selectedGreen = accentColor.withValues(alpha: 0.28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedGreen : baseGreen,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : accentColor.withValues(alpha: 0.35),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: categoryColor.withValues(alpha: 0.15),
                child: Icon(
                  _categoryIcon(category.icon),
                  size: 14,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

Color _categoryColor(String hex) {
  final value = hex.replaceAll('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

IconData _categoryIcon(String name) {
  const icons = {
    'restaurant': Icons.restaurant_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'school': Icons.school_rounded,
    'home': Icons.home_rounded,
    'wifi': Icons.wifi_rounded,
    'bolt': Icons.bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'health_and_safety': Icons.health_and_safety_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'directions_car': Icons.directions_car_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'pets': Icons.pets_rounded,
    'payments': Icons.payments_rounded,
    'work': Icons.work_rounded,
    'trending_up': Icons.trending_up_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'sell': Icons.sell_rounded,
    'redeem': Icons.redeem_rounded,
    'stars': Icons.stars_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'category': Icons.category_rounded,
  };
  return icons[name] ?? Icons.category_rounded;
}

Future<CategoryEntity> createCategoryForType({
  required String userId,
  required String name,
  required TransactionType type,
}) async {
  return CategoryEntity(
    id: const Uuid().v4(),
    userId: userId,
    name: name,
    color: type == TransactionType.income ? '#22C55E' : '#2F4F3F',
    icon: 'category',
    type: type,
    order: 999,
  );
}
