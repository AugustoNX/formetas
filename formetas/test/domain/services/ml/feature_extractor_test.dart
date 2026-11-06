import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/ml/feature_extractor.dart';

void main() {
  test('Pix enviado para Maria gera tokens, tipo e faixa estáveis', () {
    final features = FeatureExtractor.extract(
      description: 'Pix enviado - Maria Souza',
      amount: 80,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 5),
    );

    expect(features, [
      'b:maria_souza',
      'b:pix_enviado_maria',
      'd:inicio',
      'd:qui',
      'p:pix',
      't:despesa',
      't:pix_enviado',
      'v:30-100',
      'w:maria',
      'w:pix_enviado',
      'w:souza',
    ]);
    expect(
      FeatureExtractor.extract(
        description: 'Pix enviado - Maria Souza',
        amount: 80,
        type: TransactionType.expense,
        date: DateTime(2026, 3, 5),
      ),
      features,
    );
  });

  test('Pix recebido não se mistura com Pix enviado', () {
    final features = FeatureExtractor.extract(
      description: 'Transferência recebida pelo Pix - Empresa Acme',
      amount: 2500,
      type: TransactionType.income,
      date: DateTime(2026, 4, 7),
    );

    expect(
      features,
      containsAll([
        't:receita',
        't:pix_recebido',
        'p:pix',
        'w:pix_recebido',
        'w:empresa',
        'w:acme',
        'v:1000+',
      ]),
    );
    expect(features, isNot(contains('t:pix_enviado')));
    expect(features, isNot(contains('t:despesa')));
  });

  test(
    'compra no débito da padaria ignora data, hora, NSU e final do cartão',
    () {
      final features = FeatureExtractor.extract(
        description:
            'Compra no débito - PADARIA PÃO QUENTE 05/03 08:12 NSU 004512 final 1234',
        amount: 18.9,
        type: TransactionType.expense,
        date: DateTime(2026, 3, 5),
      );

      expect(
        features,
        containsAll([
          'w:compra',
          'w:debito',
          'w:padaria',
          'w:pao',
          'w:quente',
          'b:compra_debito',
          'p:debito',
          't:despesa',
          'v:10-30',
        ]),
      );
      for (final feature in features) {
        if (feature.startsWith('v:')) continue;
        expect(feature, isNot(contains(RegExp(r'\d'))));
      }
      expect(features.join(' '), isNot(contains('004512')));
      expect(features.join(' '), isNot(contains('nsu')));
    },
  );

  test('crédito, iFood, Uber, mercado, salário e RDB', () {
    final credit = FeatureExtractor.extract(
      description: 'Compra no crédito - Uber *Trip 12/03',
      amount: 32,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 12),
    );
    expect(
      credit,
      containsAll(['w:uber', 'w:trip', 'w:credito', 'p:credito', 'd:meio']),
    );
    expect(credit.join(' '), isNot(contains('12')));

    final ifood = FeatureExtractor.extract(
      description: 'Compra no débito via NuPay - iFood',
      amount: 46,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 21),
    );
    expect(
      ifood,
      containsAll(['w:ifood', 'w:nupay', 'p:debito', 'd:fim', 'v:30-100']),
    );

    final uber = FeatureExtractor.extract(
      description: 'Uber Trip Sao Paulo',
      amount: 27,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 11),
    );
    expect(
      uber,
      containsAll(['w:uber', 'w:trip', 'w:sao', 'w:paulo', 'd:meio']),
    );
    expect(uber, isNot(contains('p:pix')));

    final market = FeatureExtractor.extract(
      description: 'Compra no débito - SUPERMERCADO PAGUE MENOS',
      amount: 186.4,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 2),
    );
    expect(
      market,
      containsAll([
        'w:supermercado',
        'w:pague',
        'w:menos',
        'p:debito',
        'v:100-300',
        'd:inicio',
      ]),
    );

    final salary = FeatureExtractor.extract(
      description: 'Salário',
      amount: 5000,
      type: TransactionType.income,
      date: DateTime(2026, 9, 2),
    );
    expect(salary, containsAll(['w:salario', 't:receita', 'v:1000+']));
    expect(salary, isNot(contains('t:despesa')));

    final rdb = FeatureExtractor.extract(
      description: 'Aplicação RDB',
      amount: 300,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 20),
    );
    expect(rdb, containsAll(['w:aplicacao', 'w:rdb', 'd:meio']));
    expect(rdb.where((feature) => feature.startsWith('p:')), isEmpty);
  });

  test('faixas de valor e a forma de pagamento informada vencem o texto', () {
    List<String> of(double amount) => FeatureExtractor.extract(
      description: 'Padaria',
      amount: amount,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 10),
    );

    expect(of(0), contains('v:0-10'));
    expect(of(9.99), contains('v:0-10'));
    expect(of(10), contains('v:10-30'));
    expect(of(30), contains('v:30-100'));
    expect(of(100), contains('v:100-300'));
    expect(of(300), contains('v:300-1000'));
    expect(of(1000), contains('v:1000+'));

    final forced = FeatureExtractor.extract(
      description: 'Compra no débito - Padaria',
      amount: 20,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 10),
      paymentMethod: PaymentMethod.credit,
    );
    expect(forced, contains('p:credito'));
    expect(forced, isNot(contains('p:debito')));
  });
}
