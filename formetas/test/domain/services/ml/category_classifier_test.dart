import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/ml/category_classifier.dart';
import 'package:formetas/domain/services/ml/feature_extractor.dart';

void main() {
  final clock = DateTime.utc(2026, 3, 5);

  List<String> featuresOf({
    required String description,
    required double amount,
    required TransactionType type,
    DateTime? date,
    PaymentMethod? paymentMethod,
  }) {
    return FeatureExtractor.extract(
      description: description,
      amount: amount,
      type: type,
      date: date ?? clock,
      paymentMethod: paymentMethod,
    );
  }

  CategoryClassifier trained() {
    final model = CategoryClassifier();
    const bills = [
      'Pix enviado - ENEL',
      'Pix enviado 02/01 - ENEL 111',
      'Pix enviado 05/02 - ENEL DISTR 222333',
      'Transferência enviada pelo Pix - ENEL',
    ];
    for (final description in bills) {
      model.train(
        featuresOf(
          description: description,
          amount: 180,
          type: TransactionType.expense,
        ),
        'Moradia',
        type: TransactionType.expense,
        now: clock,
      );
    }
    const people = [
      'Pix enviado - Maria Souza',
      'Pix enviado 11/02 - Maria Souza 998877',
      'Transferência enviada pelo Pix - Maria Souza',
    ];
    for (final description in people) {
      model.train(
        featuresOf(
          description: description,
          amount: 50,
          type: TransactionType.expense,
        ),
        'Presentes',
        type: TransactionType.expense,
        now: clock,
      );
    }
    const food = [
      'Compra no débito via NuPay - iFood',
      'Compra no débito - IFOOD 03/03 NSU 445566',
    ];
    for (final description in food) {
      model.train(
        featuresOf(
          description: description,
          amount: 42,
          type: TransactionType.expense,
        ),
        'Alimentação',
        type: TransactionType.expense,
        now: clock,
      );
    }
    model.train(
      featuresOf(
        description: 'Transferência recebida pelo Pix - Empresa Acme',
        amount: 5000,
        type: TransactionType.income,
      ),
      'Salário',
      type: TransactionType.income,
      now: clock,
    );
    model.train(
      featuresOf(
        description: 'Pix recebido - Empresa Acme',
        amount: 5000,
        type: TransactionType.income,
      ),
      'Salário',
      type: TransactionType.income,
      now: clock,
    );
    return model;
  }

  test('acerta um lançamento novo com data e código diferentes', () {
    final model = trained();
    final prediction = model.predict(
      featuresOf(
        description: 'Pix enviado 05/04 - ENEL 987654 NSU 120045',
        amount: 190,
        type: TransactionType.expense,
        date: DateTime.utc(2026, 4, 5),
      ),
      TransactionType.expense,
    );

    expect(prediction, isNotEmpty);
    expect(prediction.first.category, 'Moradia');
    expect(prediction.first.confidence, greaterThanOrEqualTo(0.6));
    expect(prediction.first.confidence, lessThanOrEqualTo(1));
    expect(
      prediction.first.reasons.any((reason) => reason.contains('enel')),
      isTrue,
    );
    expect(prediction.map((item) => item.category), isNot(contains('Salário')));
  });

  test('não sugere categoria de despesa para receita nem o contrário', () {
    final model = trained();
    final income = featuresOf(
      description: 'Pix recebido 02/05 - Empresa Acme 554433',
      amount: 5000,
      type: TransactionType.income,
    );
    final expense = featuresOf(
      description: 'Pix enviado 05/04 - ENEL 987654',
      amount: 180,
      type: TransactionType.expense,
    );

    final asIncome = model.predict(income, TransactionType.income);
    final incomeAsExpense = model.predict(income, TransactionType.expense);
    final asExpense = model.predict(expense, TransactionType.expense);
    final expenseAsIncome = model.predict(expense, TransactionType.income);

    expect(asIncome.first.category, 'Salário');
    expect(asExpense.first.category, 'Moradia');
    expect(
      incomeAsExpense.map((item) => item.category),
      isNot(contains('Salário')),
    );
    expect(
      expenseAsIncome.map((item) => item.category),
      isNot(contains('Moradia')),
    );
    expect(
      expenseAsIncome.map((item) => item.category),
      isNot(contains('Alimentação')),
    );
    expect(asIncome.map((item) => item.category), isNot(contains('Moradia')));
  });

  test('untrain desfaz o exemplo e a serialização ida e volta é idêntica', () {
    final model = CategoryClassifier();
    final market = featuresOf(
      description: 'Compra no débito - SUPERMERCADO PAGUE MENOS',
      amount: 120,
      type: TransactionType.expense,
    );
    final ride = featuresOf(
      description: 'Uber Trip Sao Paulo',
      amount: 26,
      type: TransactionType.expense,
    );

    expect(model.toMap(), CategoryClassifier().toMap());
    model.train(market, 'Mercado', type: TransactionType.expense, now: clock);
    model.untrain(market, 'Mercado', type: TransactionType.expense);
    expect(model.toMap(), CategoryClassifier().toMap());

    model.train(market, 'Mercado', type: TransactionType.expense, now: clock);
    final middle = model.toMap();
    model.train(ride, 'Transporte', type: TransactionType.expense, now: clock);
    model.untrain(ride, 'Transporte', type: TransactionType.expense);
    expect(model.toMap(), middle);

    model.train(ride, 'Transporte', type: TransactionType.expense, now: clock);
    model.train(
      featuresOf(
        description: 'Salário',
        amount: 4000,
        type: TransactionType.income,
      ),
      'Salário',
      type: TransactionType.income,
      now: clock,
    );
    final restored = CategoryClassifier.fromMap(model.toMap());
    expect(restored.toMap(), model.toMap());
    expect(restored.schemaVersion, 1);
    expect(
      restored.predict(market, TransactionType.expense).first.category,
      'Mercado',
    );
  });

  test('poda tokens raros e continua acertando o token forte', () {
    final model = CategoryClassifier(maxFeaturesPerCategory: 3);
    model.train(
      const ['w:feira', 'w:compra', 'b:compra_feira'],
      'Mercado',
      type: TransactionType.expense,
      weight: 8,
      now: clock,
    );
    for (var i = 0; i < 25; i++) {
      model.train(
        ['w:feira', 'w:raro$i'],
        'Mercado',
        type: TransactionType.expense,
        now: clock,
      );
    }
    model.train(
      featuresOf(
        description: 'Uber Trip',
        amount: 30,
        type: TransactionType.expense,
      ),
      'Transporte',
      type: TransactionType.expense,
      weight: 5,
      now: clock,
    );

    final rows = model.toMap()['despesa'] as List<Object?>;
    final market = rows.cast<Map<Object?, Object?>>().firstWhere(
      (row) => row['categoria'] == 'Mercado',
    );
    final attributes = market['atributos'] as Map<Object?, Object?>;
    expect(attributes.length, lessThanOrEqualTo(3));
    expect(attributes.containsKey('w:feira'), isTrue);
    expect(
      attributes.keys.where((key) => '$key'.startsWith('w:raro')),
      isEmpty,
    );

    final prediction = model.predict(
      featuresOf(
        description: 'Compra no débito - FEIRA DO BAIRRO 09/08 NSU 778899',
        amount: 60,
        type: TransactionType.expense,
      ),
      TransactionType.expense,
    );
    expect(prediction.first.category, 'Mercado');
  });

  test('o decaimento encolhe o hábito antigo quando passam os dias', () {
    final model = CategoryClassifier();
    model.train(
      const ['w:academia'],
      'Saúde',
      type: TransactionType.expense,
      weight: 10,
      now: clock,
    );
    model.train(
      const ['w:netflix'],
      'Assinaturas',
      type: TransactionType.expense,
      now: clock.add(const Duration(days: 120)),
    );

    final rows = model.toMap()['despesa'] as List<Object?>;
    final health = rows.cast<Map<Object?, Object?>>().firstWhere(
      (row) => row['categoria'] == 'Saúde',
    );
    final count = (health['atributos'] as Map)['w:academia'] as double;
    expect(count, lessThan(10));
    expect(count, greaterThan(5));
  });

  test('bootstrap em lote aprende o histórico, inclusive no isolate', () async {
    final transactions = <TransactionEntity>[
      for (var i = 0; i < 90; i++)
        TransactionEntity(
          id: 't$i',
          userId: 'u',
          type: i.isEven ? TransactionType.expense : TransactionType.income,
          category: i.isEven ? 'Mercado' : 'Salário',
          value: i.isEven ? 80 : 4000,
          description: i.isEven
              ? 'Compra no débito - SUPERMERCADO $i'
              : 'Salário empresa',
          date: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
          paymentMethod: i.isEven ? PaymentMethod.debit : PaymentMethod.pix,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
    ];

    final model = await CategoryClassifier.bootstrap(transactions);
    expect(model.exampleCount, 90);
    expect(model.schemaVersion, 1);
    final expense = model.predict(
      featuresOf(
        description: 'Compra no débito - SUPERMERCADO 999111',
        amount: 75,
        type: TransactionType.expense,
      ),
      TransactionType.expense,
    );
    expect(expense.first.category, 'Mercado');
    expect(
      model
          .predict(
            featuresOf(
              description: 'Salário empresa',
              amount: 4000,
              type: TransactionType.income,
            ),
            TransactionType.income,
          )
          .first
          .category,
      'Salário',
    );
  });
}
