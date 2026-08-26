import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';

abstract final class DefaultCategories {
  static const defaultIdPrefix = 'local_default_';

  static const expense = [
    (name: 'Alimentação', icon: 'restaurant', color: '#EF4444'),
    (name: 'Mercado', icon: 'shopping_cart', color: '#F97316'),
    (name: 'Lazer', icon: 'sports_esports', color: '#8B5CF6'),
    (name: 'Educação', icon: 'school', color: '#3B82F6'),
    (name: 'Moradia', icon: 'home', color: '#2F4F3F'),
    (name: 'Internet', icon: 'wifi', color: '#6366F1'),
    (name: 'Energia', icon: 'bolt', color: '#EAB308'),
    (name: 'Água', icon: 'water_drop', color: '#0EA5E9'),
    (name: 'Saúde', icon: 'health_and_safety', color: '#EC4899'),
    (name: 'Academia', icon: 'fitness_center', color: '#14B8A6'),
    (name: 'Transporte', icon: 'directions_car', color: '#6B7280'),
    (name: 'Assinaturas', icon: 'subscriptions', color: '#8B5CF6'),
    (name: 'Pets', icon: 'pets', color: '#A16207'),
    (name: 'Outros', icon: 'more_horiz', color: '#9CA3AF'),
  ];

  static const income = [
    (name: 'Salário', icon: 'payments', color: '#22C55E'),
    (name: 'Freelance', icon: 'work', color: '#16A34A'),
    (name: 'Décimo Terceiro', icon: 'card_giftcard', color: '#059669'),
    (name: 'Dividendos', icon: 'trending_up', color: '#15803D'),
    (name: 'Venda', icon: 'sell', color: '#10B981'),
    (name: 'Presente', icon: 'redeem', color: '#34D399'),
    (name: 'Bonificação', icon: 'stars', color: '#059669'),
    (name: 'Outros', icon: 'more_horiz', color: '#4ADE80'),
  ];

  static bool isDefault(CategoryEntity category) =>
      category.id.startsWith(defaultIdPrefix);

  static List<CategoryEntity> forUser(String userId) {
    final categories = <CategoryEntity>[];
    var order = 0;

    for (final item in expense) {
      categories.add(CategoryEntity(
        id: '${defaultIdPrefix}exp_${item.name.hashCode.abs()}',
        userId: userId,
        name: item.name,
        color: item.color,
        icon: item.icon,
        type: TransactionType.expense,
        order: order++,
      ));
    }

    order = 0;
    for (final item in income) {
      categories.add(CategoryEntity(
        id: '${defaultIdPrefix}inc_${item.name.hashCode.abs()}',
        userId: userId,
        name: item.name,
        color: item.color,
        icon: item.icon,
        type: TransactionType.income,
        order: order++,
      ));
    }

    return categories;
  }
}
