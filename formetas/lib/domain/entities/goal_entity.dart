import 'package:equatable/equatable.dart';

class GoalEntity extends Equatable {
  const GoalEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetValue,
    required this.currentValue,
    required this.targetDate,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final double targetValue;
  final double currentValue;
  final DateTime targetDate;
  final DateTime createdAt;

  double get progressPercent =>
      targetValue > 0 ? (currentValue / targetValue * 100).clamp(0, 100) : 0;

  bool get isCompleted => currentValue >= targetValue;

  GoalEntity copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetValue,
    double? currentValue,
    DateTime? targetDate,
    DateTime? createdAt,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, name, targetValue];
}
