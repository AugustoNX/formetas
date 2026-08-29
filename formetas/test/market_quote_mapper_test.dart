import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/asset_entity.dart';
import 'package:formetas/domain/entities/market_quote.dart';

void main() {
  group('tipo da brapi', () {
    test('FII, ETF, BDR e ação caem na seção certa', () {
      expect(MarketQuoteMapper.assetClass('fund', 'fii'), AssetClass.fii);
      expect(MarketQuoteMapper.assetClass('fund', 'etf'), AssetClass.etf);
      expect(MarketQuoteMapper.assetClass('bdr', 'bdr'), AssetClass.bdr);
      expect(MarketQuoteMapper.assetClass('stock', 'stock'), AssetClass.acao);
      expect(MarketQuoteMapper.assetClass('fund', 'fi-infra'), AssetClass.fii);
    });

    test('cripto e renda fixa ficam de fora do catálogo', () {
      expect(MarketQuoteMapper.isListed(AssetClass.acao), isTrue);
      expect(MarketQuoteMapper.isListed(AssetClass.fii), isTrue);
      expect(MarketQuoteMapper.isListed(AssetClass.cripto), isFalse);
      expect(MarketQuoteMapper.isListed(AssetClass.rendaFixa), isFalse);
    });
  });

  group('nome de exibição', () {
    test('encurta o nome longo de FII no estilo do Investidor10', () {
      expect(
        MarketQuoteMapper.displayName(
          'HTMX11',
          'HTMX11',
          'Fundo de Investimento Imobiliario Hotel Maxinvest Cotas',
        ),
        'FII Hotel Maxinvest',
      );
    });

    test('não repete o ticker quando não há nome de verdade', () {
      expect(
        MarketQuoteMapper.displayName('MXRF11', 'MXRF11', null),
        'MXRF11',
      );
    });
  });
}
