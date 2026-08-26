import 'package:equatable/equatable.dart';

import 'transaction_entity.dart';

class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.icon,
    required this.type,
    this.order = 0,
  });

  final String id;
  final String userId;
  final String name;
  final String color;
  final String icon;
  final TransactionType type;
  final int order;

  CategoryEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? color,
    String? icon,
    TransactionType? type,
    int? order,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => [id, userId, name, type];
}
