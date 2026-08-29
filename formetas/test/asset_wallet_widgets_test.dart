import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/core/utils/asset_calculator.dart';
import 'package:formetas/domain/entities/asset_entity.dart';
import 'package:formetas/domain/entities/asset_trade_entity.dart';
import 'package:formetas/presentation/widgets/wallet/asset_section.dart';

/// A tabela da carteira tem nove colunas, então precisa caber tanto no celular
/// quanto no desktop sem estourar o layout.
void main() {
  final day = DateTime(2026, 8, 10);
  var sequence = 0;

  AssetWithTrades entry(
    String ticker,
    AssetClass assetClass,
    double quantity,
    double buyPrice,
    double? currentPrice, {
    String name = '',
    double? target,
  }) {
    return AssetWithTrades(
      asset: AssetEntity(
        id: ticker,
        userId: 'u1',
        ticker: ticker,
        name: name,
        assetClass: assetClass,
        currentPrice: currentPrice,
        targetPercent: target,
        createdAt: day,
      ),
      trades: [
        AssetTradeEntity(
          id: 't${sequence++}',
          assetId: ticker,
          userId: 'u1',
          type: AssetTradeType.buy,
          quantity: quantity,
          unitPrice: buyPrice,
          amount: quantity * buyPrice,
          date: day,
          createdAt: day,
        ),
      ],
    );
  }

  final portfolio = AssetCalculator.portfolio([
    entry('PETR4', AssetClass.acao, 23, 35.42, 43.55,
        name: 'Petróleo Brasileiro', target: 30),
    entry('BBAS3', AssetClass.acao, 20, 23.87, 20.15, target: 5),
    entry('MXRF11', AssetClass.fii, 100, 10.35, 10.02),
    entry('BTC', AssetClass.cripto, 0.00042135, 350000, 412000),
  ]);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required Size size,
    required Brightness brightness,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Widget sections() {
    return Column(
      children: [
        PortfolioHeaderCard(portfolio: portfolio),
        for (final group in portfolio.groups)
          AssetClassSection(
            summary: group,
            portfolio: portfolio,
            onOpenAsset: (_) {},
          ),
      ],
    );
  }

  for (final brightness in Brightness.values) {
    group('tema ${brightness.name}', () {
      testWidgets('carteira cabe na tela do celular', (tester) async {
        await pump(
          tester,
          sections(),
          size: const Size(360, 900),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('PETR4'), findsOneWidget);
        expect(find.text('Ações'), findsOneWidget);
        expect(find.text('Criptomoedas'), findsOneWidget);
      });

      testWidgets('no desktop a tabela completa cabe', (tester) async {
        await pump(
          tester,
          sections(),
          size: const Size(1400, 1000),
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Preço médio'), findsWidgets);
        expect(find.text('Comprar?'), findsWidgets);
      });
    });
  }

  testWidgets('seção recolhe e expande ao tocar no cabeçalho', (tester) async {
    await pump(
      tester,
      sections(),
      size: const Size(360, 900),
      brightness: Brightness.light,
    );

    expect(find.text('PETR4'), findsOneWidget);

    await tester.tap(find.text('Ações'));
    await tester.pumpAndSettle();

    expect(find.text('PETR4'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
