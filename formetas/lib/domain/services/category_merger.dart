import '../../core/constants/default_categories.dart';
import '../entities/category_entity.dart';

abstract final class CategoryMerger {
  static List<CategoryEntity> merge({
    required String userId,
    required List<CategoryEntity> custom,
  }) {
    final defaults = DefaultCategories.forUser(userId);
    final result = <CategoryEntity>[...defaults];

    for (final category in custom) {
      if (DefaultCategories.isDefault(category)) continue;

      final duplicate = defaults.any(
        (d) =>
            d.type == category.type &&
            d.name.toLowerCase() == category.name.toLowerCase(),
      );
      if (!duplicate) result.add(category);
    }

    result.sort((a, b) {
      final aDefault = DefaultCategories.isDefault(a);
      final bDefault = DefaultCategories.isDefault(b);
      if (aDefault != bDefault) return aDefault ? -1 : 1;
      return a.order.compareTo(b.order);
    });

    return result;
  }
}
