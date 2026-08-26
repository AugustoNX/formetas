import '../../domain/entities/investment_entity.dart';

abstract final class InvestmentTypeGroups {
  static const marketTypes = [
    InvestmentType.acoes,
    InvestmentType.fiis,
    InvestmentType.etf,
    InvestmentType.fundos,
    InvestmentType.cripto,
    InvestmentType.outros,
  ];

  static const reserveTypes = [
    InvestmentType.caixinha,
    InvestmentType.cdb,
    InvestmentType.tesouro,
    InvestmentType.lci,
    InvestmentType.lca,
    InvestmentType.poupanca,
  ];

  static bool isMarket(InvestmentType type) => marketTypes.contains(type);

  static bool isReserveLegacy(InvestmentType type) =>
      reserveTypes.contains(type);

  static String label(InvestmentType type) => switch (type) {
        InvestmentType.caixinha => 'Caixinha',
        InvestmentType.cdb => 'CDB',
        InvestmentType.tesouro => 'Tesouro',
        InvestmentType.lci => 'LCI',
        InvestmentType.lca => 'LCA',
        InvestmentType.fundos => 'Fundos',
        InvestmentType.acoes => 'Ações',
        InvestmentType.fiis => 'FIIs',
        InvestmentType.etf => 'ETF',
        InvestmentType.cripto => 'Cripto',
        InvestmentType.poupanca => 'Poupança',
        InvestmentType.outros => 'Outros',
      };
}
