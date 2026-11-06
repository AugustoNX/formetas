import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/ant_brain.dart';
import 'package:formetas/domain/entities/import_rule.dart';
import 'package:formetas/domain/entities/recurring_pattern.dart';
import 'package:formetas/domain/entities/statement_import.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/description_normalizer.dart';
import 'package:formetas/domain/services/ml/ant_brain_trainer.dart';
import 'package:formetas/domain/services/ml/category_classifier.dart';
import 'package:formetas/domain/services/ml/feature_extractor.dart';
import 'package:formetas/domain/services/ml/smart_categorizer.dart';
import 'package:formetas/domain/services/statement_classifier.dart';

StatementEntry _entry({
  required String description,
  required double amount,
  required TransactionType type,
  DateTime? date,
  String category = 'Outros',
  int line = 1,
}) {
  return StatementEntry(
    line: line,
    date: date ?? DateTime(2026, 6, 15),
    amount: amount,
    type: type,
    description: description,
    category: category,
  );
}

RecurringPattern _netflix() {
  return RecurringPattern(
    key: DescriptionNormalizer.key('Compra no débito - NETFLIX'),
    label: 'Netflix',
    kind: RecurringKind.subscription,
    type: TransactionType.expense,
    cadence: RecurrenceCadence.monthly,
    averageAmount: 39.9,
    amountVariance: 0,
    lastDate: DateTime(2026, 5, 3),
    expectedNextDate: DateTime(2026, 6, 3),
    confidence: 0.86,
    transactionIds: const ['a', 'b'],
    category: 'Assinaturas',
  );
}

void main() {
  final clock = DateTime.utc(2026, 6, 1);

  CategoryClassifier foodModel() {
    final model = CategoryClassifier();
    for (final description in [
      'Compra no débito via NuPay - iFood',
      'Compra no débito - IFOOD 01/02',
      'Compra no débito - iFood 02/03 NSU 10',
      'Compra no débito - IFOOD *IFOOD',
    ]) {
      model.train(
        FeatureExtractor.extract(
          description: description,
          amount: 40,
          type: TransactionType.expense,
          date: clock,
        ),
        'Alimentação',
        type: TransactionType.expense,
        now: clock,
      );
    }
    for (final description in [
      'Uber Trip',
      'Uber Trip Sao Paulo',
      'UBER *TRIP',
    ]) {
      model.train(
        FeatureExtractor.extract(
          description: description,
          amount: 22,
          type: TransactionType.expense,
          date: clock,
        ),
        'Transporte',
        type: TransactionType.expense,
        now: clock,
      );
    }
    return model;
  }

  test('regra existente vence recorrência, modelo e heurística', () {
    final model = foodModel();
    model.train(
      FeatureExtractor.extract(
        description: 'Compra no débito - NETFLIX',
        amount: 40,
        type: TransactionType.expense,
        date: clock,
      ),
      'Lazer',
      type: TransactionType.expense,
      weight: 8,
      now: clock,
    );
    final entry = _entry(
      description: 'Compra no débito - Netflix 03/04',
      amount: 39.9,
      type: TransactionType.expense,
    );
    final result = SmartCategorizer(
      classifier: model,
      rules: [
        ImportRule(
          text: StatementClassifier.normalize('Compra no débito - NETFLIX'),
          role: StatementRole.transaction,
          category: 'Streaming',
          type: TransactionType.expense,
        ),
      ],
      patterns: [_netflix()],
    ).categorizeOne(entry);

    expect(result.source, SuggestionSource.regra);
    expect(result.confidence, 1);
    expect(result.entry.category, 'Streaming');
    expect(result.suggestedCategory, 'Streaming');
  });

  test('sem regra, o padrão recorrente vence o modelo', () {
    final model = foodModel();
    model.train(
      FeatureExtractor.extract(
        description: 'Compra no débito - NETFLIX',
        amount: 40,
        type: TransactionType.expense,
        date: clock,
      ),
      'Lazer',
      type: TransactionType.expense,
      weight: 8,
      now: clock,
    );
    final result = SmartCategorizer(classifier: model, patterns: [_netflix()])
        .categorizeOne(
          _entry(
            description: 'Compra no débito - Netflix 08/05 NSU 123',
            amount: 39.9,
            type: TransactionType.expense,
          ),
        );

    expect(result.source, SuggestionSource.recorrente);
    expect(result.entry.category, 'Assinaturas');
    expect(result.confidence, greaterThanOrEqualTo(0.4));
  });

  test(
    'modelo só entra acima do limiar; abaixo disso a linha fica sem categoria',
    () {
      final learned = SmartCategorizer(classifier: foodModel()).categorizeOne(
        _entry(
          description: 'Compra no débito - iFood 19/07 NSU 900100',
          amount: 37,
          type: TransactionType.expense,
          date: DateTime(2026, 7, 19),
        ),
      );
      expect(learned.source, SuggestionSource.aprendido);
      expect(learned.entry.category, 'Alimentação');
      expect(learned.confidence, greaterThanOrEqualTo(0.6));
      expect(learned.alternatives.length, lessThanOrEqualTo(3));

      final unsure = CategoryClassifier();
      unsure.train(
        const ['w:loja'],
        'Lazer',
        type: TransactionType.expense,
        now: clock,
      );
      unsure.train(
        const ['w:loja'],
        'Mercado',
        type: TransactionType.expense,
        now: clock,
      );
      final blank = SmartCategorizer(classifier: unsure).categorizeOne(
        _entry(description: 'Loja', amount: 20, type: TransactionType.expense),
      );
      expect(blank.source, SuggestionSource.nenhuma);
      expect(blank.entry.category, isEmpty);
      expect(blank.confidence, lessThan(0.6));
      expect(blank.alternatives.length, lessThanOrEqualTo(3));
      expect(blank.needsReview, isTrue);
    },
  );

  test(
    'heurística antiga continua valendo quando o modelo não tem certeza',
    () {
      final rows = SmartCategorizer(classifier: CategoryClassifier())
          .categorize([
            _entry(
              description: 'Pagamento de fatura',
              amount: 800,
              type: TransactionType.expense,
            ),
            _entry(
              description: 'Aplicação RDB',
              amount: 200,
              type: TransactionType.expense,
            ),
            _entry(
              description: 'Transferência Recebida - Empresa ACME',
              amount: 4500,
              type: TransactionType.income,
              date: DateTime(2026, 9, 2),
            ),
          ]);

      expect(rows[0].source, SuggestionSource.heuristica);
      expect(rows[0].entry.role, StatementRole.ignored);
      expect(rows[1].source, SuggestionSource.heuristica);
      expect(rows[1].entry.role, StatementRole.toReserve);
      expect(rows[2].source, SuggestionSource.heuristica);
      expect(rows[2].entry.category, 'Salário');
      expect(rows[2].confidence, 1);
    },
  );

  test('correção pesa mais que aceite e o resumo conta o acerto', () {
    const trainer = AntBrainTrainer();
    final acceptedLine = CategorizedEntry(
      entry: _entry(
        description: 'Compra no débito - iFood',
        amount: 40,
        type: TransactionType.expense,
        category: 'Alimentação',
      ),
      source: SuggestionSource.aprendido,
      confidence: 0.9,
      reasons: const ['ifood'],
      alternatives: const [],
      suggestedCategory: 'Alimentação',
      suggestedRole: StatementRole.transaction,
    );
    final correctedLine = CategorizedEntry(
      entry: _entry(
        description: 'Compra no débito - iFood',
        amount: 40,
        type: TransactionType.expense,
        category: 'Transporte',
        line: 2,
      ),
      source: SuggestionSource.aprendido,
      confidence: 0.9,
      reasons: const ['ifood'],
      alternatives: const [],
      suggestedCategory: 'Alimentação',
      suggestedRole: StatementRole.transaction,
    );

    final accepted = trainer.learnImport(
      snapshot: AntBrainSnapshot.empty(),
      lines: [acceptedLine],
      now: clock,
    );
    final corrected = trainer.learnImport(
      snapshot: AntBrainSnapshot.empty(),
      lines: [correctedLine],
      now: clock,
    );

    expect(_count(accepted.snapshot, 'Alimentação'), 1);
    expect(_count(corrected.snapshot, 'Transporte'), 3);
    expect(accepted.summary.accepted, 1);
    expect(accepted.summary.corrected, 0);
    expect(corrected.summary.corrected, 1);
    expect(accepted.summary.message, 'A formiga acertou 1 de 1 (100%).');

    final second = trainer.learnImport(
      snapshot: accepted.snapshot,
      lines: [correctedLine],
      now: clock,
    );
    expect(second.summary.previousRate, 1);
    expect(
      second.summary.message,
      contains('Na importação anterior tinha sido 100%.'),
    );
    expect(second.snapshot.history, hasLength(2));
  });

  test('classifica 1000 linhas em menos de 500 ms', () {
    final model = foodModel();
    final categorizer = SmartCategorizer(
      classifier: model,
      rules: [
        for (var i = 0; i < 8; i++)
          ImportRule(
            text: 'regra avulsa $i',
            role: StatementRole.transaction,
            category: 'Outros',
            type: TransactionType.expense,
          ),
      ],
      patterns: [_netflix()],
    );
    final templates = [
      'Pix enviado - ENEL {n}',
      'Compra no débito - IFOOD {n}',
      'Compra no crédito - UBER TRIP {n}',
      'Compra no débito - SUPERMERCADO PAGUE MENOS {n}',
      'Transferência recebida pelo Pix - EMPRESA ACME {n}',
    ];
    List<StatementEntry> batch(int count) => [
      for (var i = 0; i < count; i++)
        _entry(
          line: i + 1,
          description: templates[i % templates.length].replaceAll('{n}', '$i'),
          amount: 15 + (i % 80),
          type: templates[i % templates.length].contains('recebida')
              ? TransactionType.income
              : TransactionType.expense,
          date: DateTime(2026, 1, 1).add(Duration(days: i % 27)),
        ),
    ];

    categorizer.categorize(batch(30));
    final watch = Stopwatch()..start();
    final result = categorizer.categorize(batch(1000));
    watch.stop();

    expect(result, hasLength(1000));
    expect(watch.elapsedMilliseconds, lessThan(500));
  });
}

double _count(AntBrainSnapshot snapshot, String category) {
  final rows = snapshot.model.toMap()['despesa'] as List<Object?>;
  final row = rows.cast<Map<Object?, Object?>>().firstWhere(
    (item) => item['categoria'] == category,
  );
  return (row['contagem'] as num).toDouble();
}
