import 'package:equatable/equatable.dart';

/// Seções da carteira. Cada ativo pertence a uma, e a tela agrupa por elas.
enum AssetClass { acao, fii, etf, bdr, cripto, rendaFixa, outros }

/// Um ativo da carteira de mercado (PETR4, MXRF11, BTC...).
///
/// Quantidade e preço médio não ficam aqui: são derivados dos lançamentos,
/// para que o histórico seja sempre a fonte da verdade.
class AssetEntity extends Equatable {
  const AssetEntity({
    required this.id,
    required this.userId,
    required this.ticker,
    required this.assetClass,
    required this.createdAt,
    this.name = '',
    this.currentPrice,
    this.priceUpdatedAt,
    this.targetPercent,
    this.broker,
  });

  final String id;
  final String userId;
  final String ticker;
  final String name;
  final AssetClass assetClass;

  /// Cotação informada manualmente. Nulo significa "sem cotação": nesse caso a
  /// posição vale o que custou, sem inventar valorização.
  final double? currentPrice;
  final DateTime? priceUpdatedAt;

  /// Quanto esse ativo deveria representar da carteira, em porcentagem.
  final double? targetPercent;
  final String? broker;
  final DateTime createdAt;

  String get displayName => name.trim().isEmpty ? ticker : name.trim();

  AssetEntity copyWith({
    String? id,
    String? userId,
    String? ticker,
    String? name,
    AssetClass? assetClass,
    double? currentPrice,
    DateTime? priceUpdatedAt,
    double? targetPercent,
    String? broker,
    DateTime? createdAt,
    bool clearCurrentPrice = false,
    bool clearTargetPercent = false,
  }) {
    return AssetEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      assetClass: assetClass ?? this.assetClass,
      currentPrice: clearCurrentPrice ? null : currentPrice ?? this.currentPrice,
      priceUpdatedAt:
          clearCurrentPrice ? null : priceUpdatedAt ?? this.priceUpdatedAt,
      targetPercent:
          clearTargetPercent ? null : targetPercent ?? this.targetPercent,
      broker: broker ?? this.broker,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, ticker, assetClass, currentPrice];
}

abstract final class AssetClassLabels {
  static const ordered = [
    AssetClass.acao,
    AssetClass.fii,
    AssetClass.etf,
    AssetClass.bdr,
    AssetClass.cripto,
    AssetClass.rendaFixa,
    AssetClass.outros,
  ];

  static String plural(AssetClass value) => switch (value) {
        AssetClass.acao => 'Ações',
        AssetClass.fii => 'FIIs',
        AssetClass.etf => 'ETFs',
        AssetClass.bdr => 'BDRs',
        AssetClass.cripto => 'Criptomoedas',
        AssetClass.rendaFixa => 'Renda fixa',
        AssetClass.outros => 'Outros',
      };

  static String singular(AssetClass value) => switch (value) {
        AssetClass.acao => 'Ação',
        AssetClass.fii => 'FII',
        AssetClass.etf => 'ETF',
        AssetClass.bdr => 'BDR',
        AssetClass.cripto => 'Criptomoeda',
        AssetClass.rendaFixa => 'Renda fixa',
        AssetClass.outros => 'Outro',
      };

  /// Cripto é fracionável; o resto se compra em unidades inteiras.
  static bool allowsFraction(AssetClass value) =>
      value == AssetClass.cripto || value == AssetClass.rendaFixa;

  static String unitLabel(AssetClass value) => switch (value) {
        AssetClass.fii => 'cota',
        AssetClass.cripto => 'unidade',
        AssetClass.rendaFixa => 'unidade',
        _ => 'ação',
      };
}
