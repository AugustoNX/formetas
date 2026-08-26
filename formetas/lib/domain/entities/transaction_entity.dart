import 'package:equatable/equatable.dart';

enum TransactionType { income, expense, investment }

enum RecurrenceType { none, daily, weekly, monthly, yearly }

enum PaymentMethod { cash, debit, credit, pix, transfer, other }

class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.value,
    required this.description,
    required this.date,
    required this.createdAt,
    this.subcategory,
    this.observations,
    this.recurrence = RecurrenceType.none,
    this.account,
    this.paymentMethod,
    this.isPaid = true,
    this.isInstallment = false,
    this.installmentCount = 1,
    this.installmentNumber = 1,
    this.parentId,
  });

  final String id;
  final String userId;
  final TransactionType type;
  final String category;
  final String? subcategory;
  final double value;
  final String description;
  final DateTime date;
  final String? observations;
  final RecurrenceType recurrence;
  final String? account;
  final PaymentMethod? paymentMethod;
  final bool isPaid;
  final bool isInstallment;
  final int installmentCount;
  final int installmentNumber;
  final String? parentId;
  final DateTime createdAt;

  TransactionEntity copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    String? category,
    String? subcategory,
    double? value,
    String? description,
    DateTime? date,
    String? observations,
    RecurrenceType? recurrence,
    String? account,
    PaymentMethod? paymentMethod,
    bool? isPaid,
    bool? isInstallment,
    int? installmentCount,
    int? installmentNumber,
    String? parentId,
    DateTime? createdAt,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      value: value ?? this.value,
      description: description ?? this.description,
      date: date ?? this.date,
      observations: observations ?? this.observations,
      recurrence: recurrence ?? this.recurrence,
      account: account ?? this.account,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      isInstallment: isInstallment ?? this.isInstallment,
      installmentCount: installmentCount ?? this.installmentCount,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, value, date];
}
