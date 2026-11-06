import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/statement_import.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/ml/category_classifier.dart';
import 'package:formetas/domain/services/ml/smart_categorizer.dart';
import 'package:formetas/presentation/widgets/statement_import_review.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });
  testWidgets(
    'mostra selo e confiança, corrige a linha e aplica nas parecidas',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final host = _Host();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: host)));

      expect(find.text('Aprendi'), findsWidgets);
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('Baixa'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('source-badge-1')));
      await tester.pumpAndSettle();

      expect(find.text('Por que essa categoria?'), findsOneWidget);
      expect(find.text('ifood'), findsOneWidget);

      await tester.tap(find.text('Mercado'));
      await tester.pumpAndSettle();

      expect(find.text('Aplicar a todas parecidas'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('apply-similar-1')));
      await tester.pumpAndSettle();

      expect(find.text('Transporte'), findsNothing);
      expect(find.text('Mercado'), findsNWidgets(2));
    },
  );
}

class _Host extends StatefulWidget {
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<CategorizedEntry> _rows = [
    _line(
      line: 1,
      description: 'Compra no débito - iFood 01/03',
      category: 'Alimentação',
      suggested: 'Alimentação',
      source: SuggestionSource.aprendido,
      confidence: 0.92,
      reasons: const ['ifood'],
      alternatives: const [
        CategoryPrediction(category: 'Mercado', confidence: 0.2, reasons: []),
      ],
    ),
    _line(
      line: 2,
      description: 'Compra no débito - iFood 05/04',
      category: 'Transporte',
      suggested: 'Transporte',
      source: SuggestionSource.aprendido,
      confidence: 0.7,
      reasons: const ['ifood'],
    ),
    _line(
      line: 3,
      description: 'Uber Trip Sao Paulo',
      category: '',
      suggested: null,
      source: SuggestionSource.nenhuma,
      confidence: 0.22,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StatementImportReview(
      rejected: const [],
      rows: _rows,
      incomeCategories: const ['Salário', 'Outros'],
      expenseCategories: const [
        'Alimentação',
        'Mercado',
        'Transporte',
        'Outros',
      ],
      onToggle: (index, included) => setState(() {
        _rows[index] = _rows[index].copyWith(
          entry: _rows[index].entry.copyWith(included: included),
        );
      }),
      onCategory: (index, category) => setState(() {
        _rows[index] = _rows[index].copyWith(
          entry: _rows[index].entry.copyWith(category: category),
        );
      }),
      onRole: (_, _) {},
      onEdit: (_) {},
      onApplySimilar: (index) => setState(() {
        _rows = withSimilarCategory(_rows, index, _rows[index].entry.category);
      }),
    );
  }
}

CategorizedEntry _line({
  required int line,
  required String description,
  required String category,
  required String? suggested,
  required SuggestionSource source,
  required double confidence,
  List<String> reasons = const [],
  List<CategoryPrediction> alternatives = const [],
}) {
  return CategorizedEntry(
    entry: StatementEntry(
      line: line,
      date: DateTime(2026, 3, line),
      amount: 40,
      type: TransactionType.expense,
      description: description,
      category: category,
    ),
    source: source,
    confidence: confidence,
    reasons: reasons,
    alternatives: alternatives,
    suggestedCategory: suggested,
    suggestedRole: StatementRole.transaction,
  );
}
