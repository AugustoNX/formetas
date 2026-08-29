import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/utils/asset_calculator.dart';
import 'package:formetas/core/utils/patrimony_calculator.dart';
import 'package:formetas/domain/entities/asset_entity.dart';
import 'package:formetas/domain/entities/asset_trade_entity.dart';

/// Regras da carteira por ativo: preço médio, resultado e alocação.
void main() {
  final day = DateTime(2026, 8, 10);
  var sequence = 0;

  AssetEntity asset(
    String ticker, {
    AssetClass assetClass = AssetClass.acao,
    double? price,
    double? target,
  }) {
    return AssetEntity(
      id: ticker,
      userId: 'u1',
      ticker: ticker,
      assetClass: assetClass,
      currentPrice: price,
      targetPercent: target,
      createdAt: day,
    );
  }

  AssetTradeEntity trade(
    String assetId,
    AssetTradeType type, {
    double quantity = 0,
    double unitPrice = 0,
    double fees = 0,
    double dividendAmount = 0,
    int dayOffset = 0,
  }) {
    return AssetTradeEntity(
      id: 't${sequence++}',
      assetId: assetId,
      userId: 'u1',
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      fees: fees,
      amount: AssetTradeEntity.totalFor(
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        fees: fees,
        dividendAmount: dividendAmount,
      ),
      date: day.add(Duration(days: dayOffset)),
      createdAt: day.add(Duration(days: dayOffset)),
    );
  }

  group('preço médio', () {
    test('compras somam pelo custo ponderado', () {
      final position = AssetCalculator.position(
        asset: asset('PETR4'),
        trades: [
          trade('PETR4', AssetTradeType.buy, quantity: 10, unitPrice: 10),
          trade('PETR4', AssetTradeType.buy,
              quantity: 10, unitPrice: 20, dayOffset: 1),
        ],
      );

      expect(position.quantity, 20);
      expect(position.averagePrice, 15);
      expect(position.investedCost, 300);
    });

    test('taxas entram no custo do ativo', () {
      final position = AssetCalculator.position(
        asset: asset('VALE3'),
        trades: [
          trade('VALE3', AssetTradeType.buy,
              quantity: 10, unitPrice: 10, fees: 5),
        ],
      );

      expect(position.averagePrice, 10.5);
    });

    test('venda realiza o lucro sem mexer no preço médio', () {
      final position = AssetCalculator.position(
        asset: asset('PETR4', price: 18),
        trades: [
          trade('PETR4', AssetTradeType.buy, quantity: 10, unitPrice: 10),
          trade('PETR4', AssetTradeType.buy,
              quantity: 10, unitPrice: 20, dayOffset: 1),
          trade('PETR4', AssetTradeType.sell,
              quantity: 5, unitPrice: 25, dayOffset: 2),
        ],
      );

      expect(position.quantity, 15);
      expect(position.averagePrice, 15);
      expect(position.realizedProfit, 50);
    });

    test('vender tudo zera a posição e a próxima compra começa do zero', () {
      final position = AssetCalculator.position(
        asset: asset('ITUB4'),
        trades: [
          trade('ITUB4', AssetTradeType.buy, quantity: 10, unitPrice: 10),
          trade('ITUB4', AssetTradeType.sell,
              quantity: 10, unitPrice: 12, dayOffset: 1),
          trade('ITUB4', AssetTradeType.buy,
              quantity: 4, unitPrice: 30, dayOffset: 2),
        ],
      );

      expect(position.quantity, 4);
      expect(position.averagePrice, 30);
      expect(position.realizedProfit, 20);
    });
  });

  group('resultado', () {
    test('valorização e proventos entram na rentabilidade', () {
      final position = AssetCalculator.position(
        asset: asset('PETR4', price: 18),
        trades: [
          trade('PETR4', AssetTradeType.buy, quantity: 10, unitPrice: 10),
          trade('PETR4', AssetTradeType.buy,
              quantity: 10, unitPrice: 20, dayOffset: 1),
          trade('PETR4', AssetTradeType.dividend,
              dividendAmount: 30, dayOffset: 2),
        ],
      );

      expect(position.currentValue, 360);
      expect(position.priceChange, closeTo(0.2, 0.0001));
      expect(position.dividends, 30);
      expect(position.totalProfit, 90);
      expect(position.profitability, closeTo(0.3, 0.0001));
    });

    test('sem cotação a posição vale o que custou', () {
      final position = AssetCalculator.position(
        asset: asset('MXRF11', assetClass: AssetClass.fii),
        trades: [
          trade('MXRF11', AssetTradeType.buy, quantity: 100, unitPrice: 10),
        ],
      );

      expect(position.hasQuote, isFalse);
      expect(position.currentValue, 1000);
      expect(position.priceChange, 0);
      expect(position.profitability, 0);
    });
  });

  group('carteira', () {
    final assets = [
      AssetWithTrades(
        asset: asset('PETR4', price: 18, target: 70),
        trades: [
          trade('PETR4', AssetTradeType.buy, quantity: 20, unitPrice: 15),
        ],
      ),
      AssetWithTrades(
        asset: asset('MXRF11', assetClass: AssetClass.fii, price: 12),
        trades: [
          trade('MXRF11', AssetTradeType.buy, quantity: 20, unitPrice: 10),
        ],
      ),
    ];

    test('agrupa por seção e soma os totais', () {
      final portfolio = AssetCalculator.portfolio(assets);

      expect(portfolio.groups.length, 2);
      expect(portfolio.groups.first.assetClass, AssetClass.acao);
      expect(portfolio.totalValue, 600);
      expect(portfolio.totalCost, 500);
      expect(portfolio.variation, closeTo(0.2, 0.0001));
    });

    test('aponta o ativo abaixo da meta de alocação', () {
      final portfolio = AssetCalculator.portfolio(assets);
      final petr = portfolio.positions
          .firstWhere((p) => p.asset.ticker == 'PETR4');
      final mxrf = portfolio.positions
          .firstWhere((p) => p.asset.ticker == 'MXRF11');

      expect(portfolio.share(petr.currentValue), closeTo(0.6, 0.0001));
      expect(portfolio.shouldBuy(petr), isTrue);
      expect(portfolio.shouldBuy(mxrf), isFalse);
    });

    test('carteira vazia não quebra os cálculos', () {
      final portfolio = AssetCalculator.portfolio([]);

      expect(portfolio.isEmpty, isTrue);
      expect(portfolio.totalValue, 0);
      expect(portfolio.profitability, 0);
      expect(portfolio.share(100), 0);
    });
  });

  group('patrimônio', () {
    test('valor de mercado entra no total de investimentos', () {
      final portfolio = AssetCalculator.portfolio([
        AssetWithTrades(
          asset: asset('PETR4', price: 18),
          trades: [
            trade('PETR4', AssetTradeType.buy, quantity: 20, unitPrice: 15),
          ],
        ),
      ]);

      final totals = PatrimonyCalculator.investments(
        investments: const [],
        cdiRate: 0.1,
        positions: portfolio.positions,
      );

      expect(totals.total, 360);
      expect(totals.principal, 300);
      expect(totals.accumulatedYield, 60);
    });

    test('sem ativos o resultado continua igual ao de antes', () {
      final totals = PatrimonyCalculator.investments(
        investments: const [],
        cdiRate: 0.1,
      );

      expect(totals.total, 0);
      expect(totals.principal, 0);
      expect(totals.accumulatedYield, 0);
    });
  });
}
