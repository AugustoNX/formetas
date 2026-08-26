import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.category,
    required super.value,
    required super.description,
    required super.date,
    required super.createdAt,
    super.subcategory,
    super.observations,
    super.recurrence,
    super.account,
    super.paymentMethod,
    super.isPaid,
    super.isInstallment,
    super.installmentCount,
    super.installmentNumber,
    super.parentId,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      type: _parseType(map['tipo'] ?? map['type']),
      category: map['categoria'] as String? ?? map['category'] as String? ?? '',
      subcategory: map['subcategoria'] as String? ?? map['subcategory'] as String?,
      value: (map['valor'] ?? map['value'] ?? 0).toDouble(),
      description: map['descrição'] as String? ??
          map['descricao'] as String? ??
          map['description'] as String? ??
          '',
      date: _parseDate(map['data'] ?? map['date']),
      observations: map['observações'] as String? ??
          map['observacoes'] as String? ??
          map['observations'] as String?,
      recurrence: _parseRecurrence(map['recorrente'] ?? map['recurrence']),
      account: map['conta'] as String? ?? map['account'] as String?,
      paymentMethod: _parsePayment(map['formaPagamento'] ?? map['paymentMethod']),
      isPaid: map['pago'] as bool? ?? map['isPaid'] as bool? ?? true,
      isInstallment: map['parcelada'] as bool? ?? map['isInstallment'] as bool? ?? false,
      installmentCount: map['quantidadeParcelas'] as int? ??
          map['installmentCount'] as int? ??
          1,
      installmentNumber: map['numeroParcela'] as int? ??
          map['installmentNumber'] as int? ??
          1,
      parentId: map['parentId'] as String?,
      createdAt: _parseDate(map['criadoEm'] ?? map['createdAt']),
    );
  }

  factory TransactionModel.fromEntity(TransactionEntity entity) {
    return TransactionModel(
      id: entity.id,
      userId: entity.userId,
      type: entity.type,
      category: entity.category,
      subcategory: entity.subcategory,
      value: entity.value,
      description: entity.description,
      date: entity.date,
      observations: entity.observations,
      recurrence: entity.recurrence,
      account: entity.account,
      paymentMethod: entity.paymentMethod,
      isPaid: entity.isPaid,
      isInstallment: entity.isInstallment,
      installmentCount: entity.installmentCount,
      installmentNumber: entity.installmentNumber,
      parentId: entity.parentId,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tipo': type.name,
      'categoria': category,
      'subcategoria': subcategory,
      'valor': value,
      'descrição': description,
      'data': date.toIso8601String(),
      'observações': observations,
      'recorrente': recurrence.name,
      'conta': account,
      'formaPagamento': paymentMethod?.name,
      'pago': isPaid,
      'parcelada': isInstallment,
      'quantidadeParcelas': installmentCount,
      'numeroParcela': installmentNumber,
      'parentId': parentId,
      'criadoEm': createdAt.toIso8601String(),
    };
  }

  static TransactionType _parseType(dynamic value) {
    final str = value?.toString() ?? 'expense';
    return TransactionType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => TransactionType.expense,
    );
  }

  static RecurrenceType _parseRecurrence(dynamic value) {
    final str = value?.toString() ?? 'none';
    return RecurrenceType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => RecurrenceType.none,
    );
  }

  static PaymentMethod? _parsePayment(dynamic value) {
    if (value == null) return null;
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value.toString(),
      orElse: () => PaymentMethod.other,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
