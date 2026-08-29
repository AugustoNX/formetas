import '../../domain/entities/asset_trade_entity.dart';

class AssetTradeModel extends AssetTradeEntity {
  const AssetTradeModel({
    required super.id,
    required super.assetId,
    required super.userId,
    required super.type,
    required super.amount,
    required super.date,
    required super.createdAt,
    super.quantity,
    super.unitPrice,
    super.fees,
    super.note,
    super.transferId,
  });

  factory AssetTradeModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? assetId,
  }) {
    return AssetTradeModel(
      id: id,
      assetId: assetId ?? map['ativoId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: _parseType(map['tipo']),
      quantity: (map['quantidade'] as num?)?.toDouble() ?? 0,
      unitPrice: (map['precoUnitario'] as num?)?.toDouble() ?? 0,
      fees: (map['taxas'] as num?)?.toDouble() ?? 0,
      amount: (map['valor'] as num?)?.toDouble() ?? 0,
      date: _parseDate(map['data']),
      note: map['observacao'] as String?,
      transferId: map['transferenciaId'] as String?,
      createdAt: _parseDate(map['criadoEm']),
    );
  }

  factory AssetTradeModel.fromEntity(AssetTradeEntity entity) {
    return AssetTradeModel(
      id: entity.id,
      assetId: entity.assetId,
      userId: entity.userId,
      type: entity.type,
      quantity: entity.quantity,
      unitPrice: entity.unitPrice,
      fees: entity.fees,
      amount: entity.amount,
      date: entity.date,
      note: entity.note,
      transferId: entity.transferId,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ativoId': assetId,
      'tipo': type.name,
      'quantidade': quantity,
      'precoUnitario': unitPrice,
      'taxas': fees,
      'valor': amount,
      'data': date.toIso8601String(),
      'observacao': note,
      'transferenciaId': transferId,
      'criadoEm': createdAt.toIso8601String(),
    };
  }

  static AssetTradeType _parseType(dynamic value) {
    final raw = value?.toString() ?? 'buy';
    return AssetTradeType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AssetTradeType.buy,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
