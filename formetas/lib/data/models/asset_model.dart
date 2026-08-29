import '../../domain/entities/asset_entity.dart';

class AssetModel extends AssetEntity {
  const AssetModel({
    required super.id,
    required super.userId,
    required super.ticker,
    required super.assetClass,
    required super.createdAt,
    super.name,
    super.currentPrice,
    super.priceUpdatedAt,
    super.targetPercent,
    super.broker,
  });

  factory AssetModel.fromMap(Map<String, dynamic> map, String id) {
    return AssetModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      ticker: (map['ticker'] as String? ?? '').toUpperCase(),
      name: map['nome'] as String? ?? '',
      assetClass: _parseClass(map['classe']),
      currentPrice: (map['precoAtual'] as num?)?.toDouble(),
      priceUpdatedAt: _parseNullableDate(map['precoAtualizadoEm']),
      targetPercent: (map['metaPercentual'] as num?)?.toDouble(),
      broker: map['corretora'] as String?,
      createdAt: _parseDate(map['criadoEm']),
    );
  }

  factory AssetModel.fromEntity(AssetEntity entity) {
    return AssetModel(
      id: entity.id,
      userId: entity.userId,
      ticker: entity.ticker,
      name: entity.name,
      assetClass: entity.assetClass,
      currentPrice: entity.currentPrice,
      priceUpdatedAt: entity.priceUpdatedAt,
      targetPercent: entity.targetPercent,
      broker: entity.broker,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ticker': ticker.toUpperCase(),
      'nome': name,
      'classe': assetClass.name,
      'precoAtual': currentPrice,
      'precoAtualizadoEm': priceUpdatedAt?.toIso8601String(),
      'metaPercentual': targetPercent,
      'corretora': broker,
      'criadoEm': createdAt.toIso8601String(),
    };
  }

  static AssetClass _parseClass(dynamic value) {
    final raw = value?.toString() ?? 'outros';
    return AssetClass.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AssetClass.outros,
    );
  }

  static DateTime _parseDate(dynamic value) {
    return _parseNullableDate(value) ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
