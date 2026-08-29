import 'package:equatable/equatable.dart';

import 'asset_entity.dart';

/// Resultado de uma busca no catálogo da B3: código, nome e último preço.
class MarketQuote extends Equatable {
  const MarketQuote({
    required this.ticker,
    required this.name,
    required this.assetClass,
    this.price,
    this.changePercent,
  });

  final String ticker;
  final String name;
  final AssetClass assetClass;
  final double? price;
  final double? changePercent;

  String get label => name.toUpperCase() == ticker ? ticker : '$ticker · $name';

  @override
  List<Object?> get props => [ticker, name, assetClass, price];
}

/// Traduz o tipo da brapi para as seções da carteira.
abstract final class MarketQuoteMapper {
  static AssetClass assetClass(String? type, String? subType) {
    final kind = (subType ?? type ?? '').toLowerCase();
    return switch (kind) {
      'fii' || 'fi-infra' || 'fi-agro' || 'fip' || 'fidc' => AssetClass.fii,
      'etf' => AssetClass.etf,
      'bdr' => AssetClass.bdr,
      'fund' => AssetClass.fii,
      _ => AssetClass.acao,
    };
  }

  /// Nome curto o bastante para caber no autocomplete, no estilo do Investidor10.
  static String displayName(String ticker, String name, String? longName) {
    final long = longName?.trim() ?? '';
    final short = name.trim();
    final raw = long.isNotEmpty && long.toUpperCase() != ticker.toUpperCase()
        ? long
        : short;

    if (raw.isEmpty || raw.toUpperCase() == ticker.toUpperCase()) return ticker;

    return raw
        .replaceAll(
          RegExp(r'Fundo de Investimento Imobili[aá]rio', caseSensitive: false),
          'FII',
        )
        .replaceAll(RegExp(r'\s+Cotas$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Filtros do catálogo para cada seção. Cripto e renda fixa não estão nele.
  static ({String? type, String? subType})? catalogFilter(AssetClass assetClass) {
    return switch (assetClass) {
      AssetClass.acao => (type: 'stock', subType: null),
      AssetClass.fii => (type: 'fund', subType: 'fii'),
      AssetClass.etf => (type: 'fund', subType: 'etf'),
      AssetClass.bdr => (type: 'bdr', subType: 'bdr'),
      AssetClass.cripto ||
      AssetClass.rendaFixa ||
      AssetClass.outros =>
        null,
    };
  }

  static bool isListed(AssetClass assetClass) =>
      catalogFilter(assetClass) != null;
}
