import '../../domain/entities/transfer_entity.dart';

class TransferModel extends TransferEntity {
  const TransferModel({
    required super.id,
    required super.userId,
    required super.amount,
    required super.fromType,
    required super.toType,
    required super.date,
    required super.createdAt,
    super.fromId,
    super.toId,
    super.description,
  });

  factory TransferModel.fromMap(Map<String, dynamic> map, String id) {
    return TransferModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      amount: (map['valor'] ?? map['amount'] ?? 0).toDouble(),
      fromType: _parseWallet(map['deTipo'] ?? map['fromType']),
      toType: _parseWallet(map['paraTipo'] ?? map['toType']),
      fromId: map['deId'] as String? ?? map['fromId'] as String?,
      toId: map['paraId'] as String? ?? map['toId'] as String?,
      description: map['descricao'] as String? ?? map['description'] as String?,
      date: _parseDate(map['data'] ?? map['date']),
      createdAt: _parseDate(map['criadoEm'] ?? map['createdAt']),
    );
  }

  factory TransferModel.fromEntity(TransferEntity entity) {
    return TransferModel(
      id: entity.id,
      userId: entity.userId,
      amount: entity.amount,
      fromType: entity.fromType,
      toType: entity.toType,
      fromId: entity.fromId,
      toId: entity.toId,
      description: entity.description,
      date: entity.date,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'valor': amount,
      'deTipo': fromType.name,
      'paraTipo': toType.name,
      'deId': fromId,
      'paraId': toId,
      'descricao': description,
      'data': date.toIso8601String(),
      'criadoEm': createdAt.toIso8601String(),
    };
  }

  static WalletType _parseWallet(dynamic value) {
    final str = value?.toString() ?? 'balance';
    return WalletType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => WalletType.balance,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
