import 'package:equatable/equatable.dart';

import 'investment_entity.dart';

enum ReserveType {
  caixinha,
  cdb,
  lci,
  lca,
  tesouro,
  poupanca,
  outros,
}

class ReserveEntity extends Equatable {
  const ReserveEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.initialValue,
    required this.currentValue,
    required this.startDate,
    required this.createdAt,
    this.bank,
    this.cdiPercent,
    this.fixedRate,
    this.indexer,
    this.monthlyContribution = 0,
    this.liquidity = LiquidityType.daily,
    this.maturityDate,
    this.accumulatedYield = 0,
  });

  final String id;
  final String userId;
  final String name;
  final ReserveType type;
  final String? bank;
  final double initialValue;
  final double currentValue;
  final double? cdiPercent;
  final double? fixedRate;
  final String? indexer;
  final double monthlyContribution;
  final DateTime startDate;
  final LiquidityType liquidity;
  final DateTime? maturityDate;
  final double accumulatedYield;
  final DateTime createdAt;

  ReserveEntity copyWith({
    String? id,
    String? userId,
    String? name,
    ReserveType? type,
    String? bank,
    double? initialValue,
    double? currentValue,
    double? cdiPercent,
    double? fixedRate,
    String? indexer,
    double? monthlyContribution,
    DateTime? startDate,
    LiquidityType? liquidity,
    DateTime? maturityDate,
    double? accumulatedYield,
    DateTime? createdAt,
  }) {
    return ReserveEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      bank: bank ?? this.bank,
      initialValue: initialValue ?? this.initialValue,
      currentValue: currentValue ?? this.currentValue,
      cdiPercent: cdiPercent ?? this.cdiPercent,
      fixedRate: fixedRate ?? this.fixedRate,
      indexer: indexer ?? this.indexer,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      startDate: startDate ?? this.startDate,
      liquidity: liquidity ?? this.liquidity,
      maturityDate: maturityDate ?? this.maturityDate,
      accumulatedYield: accumulatedYield ?? this.accumulatedYield,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, name, currentValue];
}

abstract final class ReserveTypeLabels {
  static String label(ReserveType type) => switch (type) {
        ReserveType.caixinha => 'Caixinha',
        ReserveType.cdb => 'CDB',
        ReserveType.lci => 'LCI',
        ReserveType.lca => 'LCA',
        ReserveType.tesouro => 'Tesouro Direto',
        ReserveType.poupanca => 'Poupança',
        ReserveType.outros => 'Outros',
      };
}
