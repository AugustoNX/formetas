import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/asset_trade_entity.dart';

/// Quantidades muito pequenas viram zero para não deixar resíduo de ponto
/// flutuante depois de vender tudo.
const _epsilon = 0.0000001;

/// Posição consolidada de um ativo: o que os lançamentos dizem sobre ele.
class AssetPosition {
  const AssetPosition({
    required this.asset,
    required this.trades,
    required this.quantity,
    required this.averagePrice,
    required this.dividends,
    required this.realizedProfit,
  });

  final AssetEntity asset;
  final List<AssetTradeEntity> trades;
  final double quantity;
  final double averagePrice;

  /// Proventos já recebidos.
  final double dividends;

  /// Lucro (ou prejuízo) que virou dinheiro nas vendas.
  final double realizedProfit;

  bool get hasQuote => asset.currentPrice != null;

  /// Sem cotação informada, a posição vale o que custou.
  double get currentPrice => asset.currentPrice ?? averagePrice;

  double get investedCost => quantity * averagePrice;

  double get currentValue => quantity * currentPrice;

  /// Quanto o preço andou desde o preço médio.
  double get priceChange =>
      averagePrice <= 0 ? 0 : (currentPrice - averagePrice) / averagePrice;

  double get unrealizedProfit => currentValue - investedCost;

  /// Resultado completo: valorização, proventos e vendas.
  double get totalProfit => unrealizedProfit + dividends + realizedProfit;

  double get profitability =>
      investedCost <= 0 ? 0 : totalProfit / investedCost;

  /// Proventos sobre o que foi investido, o "yield on cost".
  double get dividendYield => investedCost <= 0 ? 0 : dividends / investedCost;

  bool get isOpen => quantity > _epsilon;

  int get tradeCount => trades.length;
}

/// Uma seção da carteira (Ações, FIIs...) com seus totais.
class AssetClassSummary {
  const AssetClassSummary({
    required this.assetClass,
    required this.positions,
  });

  final AssetClass assetClass;
  final List<AssetPosition> positions;

  List<AssetPosition> get openPositions =>
      positions.where((p) => p.isOpen).toList();

  int get assetCount => openPositions.length;

  double get totalValue =>
      positions.fold(0.0, (sum, p) => sum + p.currentValue);

  double get totalCost =>
      positions.fold(0.0, (sum, p) => sum + p.investedCost);

  double get dividends => positions.fold(0.0, (sum, p) => sum + p.dividends);

  double get realizedProfit =>
      positions.fold(0.0, (sum, p) => sum + p.realizedProfit);

  double get totalProfit => positions.fold(0.0, (sum, p) => sum + p.totalProfit);

  double get variation =>
      totalCost <= 0 ? 0 : (totalValue - totalCost) / totalCost;

  double get profitability => totalCost <= 0 ? 0 : totalProfit / totalCost;

  /// Alvo da seção: a soma das metas dos ativos dentro dela.
  double get targetPercent =>
      positions.fold(0.0, (sum, p) => sum + (p.asset.targetPercent ?? 0));

  bool get hasTarget => targetPercent > 0;
}

/// A carteira inteira, já agrupada por seção.
class PortfolioSummary {
  const PortfolioSummary({required this.groups});

  static const empty = PortfolioSummary(groups: []);

  final List<AssetClassSummary> groups;

  List<AssetPosition> get positions =>
      [for (final group in groups) ...group.positions];

  List<AssetPosition> get openPositions =>
      positions.where((p) => p.isOpen).toList();

  bool get isEmpty => positions.isEmpty;

  double get totalValue => groups.fold(0.0, (sum, g) => sum + g.totalValue);

  double get totalCost => groups.fold(0.0, (sum, g) => sum + g.totalCost);

  double get dividends => groups.fold(0.0, (sum, g) => sum + g.dividends);

  double get realizedProfit =>
      groups.fold(0.0, (sum, g) => sum + g.realizedProfit);

  double get totalProfit => groups.fold(0.0, (sum, g) => sum + g.totalProfit);

  double get variation =>
      totalCost <= 0 ? 0 : (totalValue - totalCost) / totalCost;

  double get profitability => totalCost <= 0 ? 0 : totalProfit / totalCost;

  /// Quanto um valor representa da carteira.
  double share(double value) => totalValue <= 0 ? 0 : value / totalValue;

  /// Fica abaixo da meta de alocação, então vale a pena aportar.
  bool shouldBuy(AssetPosition position) {
    final target = position.asset.targetPercent;
    if (target == null || target <= 0) return false;
    return share(position.currentValue) * 100 < target;
  }
}

abstract final class AssetCalculator {
  /// Reconstrói a posição percorrendo os lançamentos em ordem de data.
  ///
  /// A compra recalcula o preço médio ponderado (taxas entram no custo), a
  /// venda realiza o lucro sem mexer no preço médio e o provento só acumula.
  static AssetPosition position({
    required AssetEntity asset,
    required List<AssetTradeEntity> trades,
  }) {
    final ordered = [...trades]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });

    var quantity = 0.0;
    var averagePrice = 0.0;
    var dividends = 0.0;
    var realized = 0.0;

    for (final trade in ordered) {
      switch (trade.type) {
        case AssetTradeType.buy:
          final incoming = trade.quantity;
          if (incoming <= 0) continue;
          final newQuantity = quantity + incoming;
          final newCost =
              quantity * averagePrice + incoming * trade.unitPrice + trade.fees;
          averagePrice = newCost / newQuantity;
          quantity = newQuantity;

        case AssetTradeType.sell:
          final sold = trade.quantity > quantity ? quantity : trade.quantity;
          if (sold <= 0) continue;
          realized += sold * (trade.unitPrice - averagePrice) - trade.fees;
          quantity -= sold;
          if (quantity <= _epsilon) {
            quantity = 0;
            averagePrice = 0;
          }

        case AssetTradeType.dividend:
          dividends += trade.amount;
      }
    }

    return AssetPosition(
      asset: asset,
      trades: ordered.reversed.toList(),
      quantity: quantity,
      averagePrice: averagePrice,
      dividends: dividends,
      realizedProfit: realized,
    );
  }

  static PortfolioSummary portfolio(List<AssetWithTrades> assets) {
    if (assets.isEmpty) return PortfolioSummary.empty;

    final positions = [
      for (final item in assets)
        position(asset: item.asset, trades: item.trades),
    ];

    final groups = <AssetClassSummary>[];
    for (final assetClass in AssetClassLabels.ordered) {
      final inClass = positions
          .where((p) => p.asset.assetClass == assetClass)
          .toList()
        ..sort((a, b) => b.currentValue.compareTo(a.currentValue));

      if (inClass.isEmpty) continue;
      groups.add(AssetClassSummary(assetClass: assetClass, positions: inClass));
    }

    return PortfolioSummary(groups: groups);
  }
}
