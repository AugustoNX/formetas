import '../../domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.color,
    required super.icon,
    required super.type,
    super.order,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['nome'] as String? ?? map['name'] as String? ?? '',
      color: map['cor'] as String? ?? map['color'] as String? ?? '#2F4F3F',
      icon: map['ícone'] as String? ?? map['icone'] as String? ?? map['icon'] as String? ?? 'category',
      type: _parseType(map['tipo'] ?? map['type']),
      order: map['ordem'] as int? ?? map['order'] as int? ?? 0,
    );
  }

  factory CategoryModel.fromEntity(CategoryEntity entity) {
    return CategoryModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      color: entity.color,
      icon: entity.icon,
      type: entity.type,
      order: entity.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nome': name,
      'cor': color,
      'ícone': icon,
      'tipo': type.name,
      'ordem': order,
    };
  }

  static TransactionType _parseType(dynamic value) {
    final str = value?.toString() ?? 'expense';
    return TransactionType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => TransactionType.expense,
    );
  }
}
