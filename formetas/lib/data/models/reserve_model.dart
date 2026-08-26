import '../../domain/entities/investment_entity.dart';
import '../../domain/entities/reserve_entity.dart';

class ReserveModel extends ReserveEntity {
  const ReserveModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    required super.initialValue,
    required super.currentValue,
    required super.startDate,
    required super.createdAt,
    super.bank,
    super.cdiPercent,
    super.fixedRate,
    super.indexer,
    super.monthlyContribution,
    super.liquidity,
    super.maturityDate,
    super.accumulatedYield,
  });

  factory ReserveModel.fromMap(Map<String, dynamic> map, String id) {
    return ReserveModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['nome'] as String? ?? map['name'] as String? ?? '',
      type: _parseType(map['tipo'] ?? map['type']),
      bank: map['banco'] as String? ?? map['bank'] as String?,
      initialValue: (map['valorInicial'] ?? map['initialValue'] ?? 0).toDouble(),
      currentValue: (map['valorAtual'] ?? map['currentValue'] ?? 0).toDouble(),
      cdiPercent: (map['percentualCDI'] ?? map['cdiPercent'])?.toDouble(),
      fixedRate: (map['taxaFixa'] ?? map['fixedRate'])?.toDouble(),
      indexer: map['indexador'] as String? ?? map['indexer'] as String?,
      monthlyContribution:
          (map['aporteMensal'] ?? map['monthlyContribution'] ?? 0).toDouble(),
      startDate: _parseDate(map['dataInicio'] ?? map['startDate']),
      liquidity: _parseLiquidity(map['liquidez'] ?? map['liquidity']),
      maturityDate: map['vencimento'] != null || map['maturityDate'] != null
          ? _parseDate(map['vencimento'] ?? map['maturityDate'])
          : null,
      accumulatedYield:
          (map['rendimentoAcumulado'] ?? map['accumulatedYield'] ?? 0).toDouble(),
      createdAt: _parseDate(map['criadoEm'] ?? map['createdAt']),
    );
  }

  factory ReserveModel.fromEntity(ReserveEntity entity) {
    return ReserveModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      type: entity.type,
      bank: entity.bank,
      initialValue: entity.initialValue,
      currentValue: entity.currentValue,
      cdiPercent: entity.cdiPercent,
      fixedRate: entity.fixedRate,
      indexer: entity.indexer,
      monthlyContribution: entity.monthlyContribution,
      startDate: entity.startDate,
      liquidity: entity.liquidity,
      maturityDate: entity.maturityDate,
      accumulatedYield: entity.accumulatedYield,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'nome': name,
      'tipo': type.name,
      'banco': bank,
      'valorInicial': initialValue,
      'valorAtual': currentValue,
      'percentualCDI': cdiPercent,
      'taxaFixa': fixedRate,
      'indexador': indexer,
      'aporteMensal': monthlyContribution,
      'dataInicio': startDate.toIso8601String(),
      'liquidez': liquidity.name,
      'vencimento': maturityDate?.toIso8601String(),
      'rendimentoAcumulado': accumulatedYield,
      'criadoEm': createdAt.toIso8601String(),
    };
  }

  static ReserveType _parseType(dynamic value) {
    final str = value?.toString() ?? 'caixinha';
    return ReserveType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => ReserveType.caixinha,
    );
  }

  static LiquidityType _parseLiquidity(dynamic value) {
    final str = value?.toString() ?? 'daily';
    return LiquidityType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => LiquidityType.daily,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
