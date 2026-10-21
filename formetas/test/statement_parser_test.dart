import 'package:flutter_test/flutter_test.dart';
import 'package:formetas/domain/entities/transaction_entity.dart';
import 'package:formetas/domain/services/statement_importer.dart';
import 'package:formetas/domain/services/statement_parser.dart';

void main() {
  test('nubank lê data, valor, descrição e identificador', () {
    final result = StatementParser.parse('''
Data,Valor,Identificador,Descrição
02/09/2026,3645.42,id-1,Transferência Recebida - Fulano
02/09/2026,-1000.00,id-2,Aplicação RDB
02/09/2026,-36.00,id-3,"Compra no débito - FARMACIA, centro"
''');

    expect(result.failed, isFalse);
    expect(result.dateColumn, 'Data');
    expect(result.amountColumn, 'Valor');
    expect(result.descriptionColumn, 'Descrição');
    expect(result.entries, hasLength(3));

    expect(result.entries[0].line, 2);
    expect(result.entries[0].type, TransactionType.income);
    expect(result.entries[0].amount, closeTo(3645.42, 0.001));
    expect(result.entries[0].description, 'Transferência Recebida - Fulano');
    expect(result.entries[0].sourceId, 'id-1');

    expect(result.entries[1].type, TransactionType.expense);
    expect(result.entries[1].amount, closeTo(1000, 0.001));

    expect(result.entries[2].description, 'Compra no débito - FARMACIA, centro');
  });

  test('inter ignora o preâmbulo e não usa o saldo', () {
    final result = StatementParser.parse('''
 Extrato Conta Corrente 
Conta ;397801920
Período ;20/09/2026 a 20/10/2026
Saldo ;26,26

Data Lançamento;Histórico;Descrição;Valor;Saldo
20/10/2026;Crédito Evento B3;* Prov * Rendimento 105                Vgia11;12,60;26,26
16/10/2026;Pix enviado ;Augusto Negri Xavier;-38,00;3,00
23/09/2026;Debito Conta Global De Inv;;-197,82;883,45
22/09/2026;Pix recebido;Alguem;1.000,00;1.083,45
23/09/2026;Debito Iof Conta Global De Inv;;-2,18;1.081,27
''');

    expect(result.failed, isFalse);
    expect(result.dateColumn, 'Data Lançamento');
    expect(result.descriptionColumn, 'Descrição');
    expect(result.amountColumn, 'Valor');
    expect(result.entries, hasLength(5));
    expect(result.rejected, isEmpty);

    final first = result.entries.first;
    expect(first.line, 7);
    expect(first.type, TransactionType.income);
    expect(first.amount, closeTo(12.60, 0.001));
    expect(first.description, '* Prov * Rendimento 105 Vgia11');

    expect(result.entries[1].type, TransactionType.expense);
    expect(result.entries[1].amount, closeTo(38, 0.001));
    expect(result.entries[1].description, 'Augusto Negri Xavier');

    expect(result.entries[2].description, 'Debito Conta Global De Inv');
    expect(result.entries[2].amount, closeTo(197.82, 0.001));
    expect(result.entries[3].amount, closeTo(1000, 0.001));
    expect(result.entries[4].amount, closeTo(2.18, 0.001));
  });

  test('aceita colunas fora de ordem, débito e crédito, e outros separadores', () {
    final swapped = StatementParser.parse('''
Valor;Descrição;Data
-8,90;Padaria;05/05/2026
R\$ 1.234,56;Salário;06/05/2026
''');
    expect(swapped.entries[0].type, TransactionType.expense);
    expect(swapped.entries[0].amount, closeTo(8.90, 0.001));
    expect(swapped.entries[0].description, 'Padaria');
    expect(swapped.entries[1].type, TransactionType.income);
    expect(swapped.entries[1].amount, closeTo(1234.56, 0.001));

    final split = StatementParser.parse('''
Data;Histórico;Débito;Crédito
01/03/2026;Padaria;15,50;
01/03/2026;Salário;;3.200,00
01/03/2026;Confuso;10,00;5,00
''');
    expect(split.entries, hasLength(2));
    expect(split.entries[0].type, TransactionType.expense);
    expect(split.entries[0].amount, closeTo(15.50, 0.001));
    expect(split.entries[0].description, 'Padaria');
    expect(split.entries[1].type, TransactionType.income);
    expect(split.entries[1].amount, closeTo(3200, 0.001));
    expect(split.rejected.single.reason, 'Débito e crédito na mesma linha');

    final english = StatementParser.parse('''
Date,Memo,Amount
2026-01-02,Salary,1500.00
2026-01-03,Coffee,-8.40
''');
    expect(english.entries, hasLength(2));
    expect(english.entries[0].date, DateTime(2026, 1, 2));
    expect(english.entries[0].type, TransactionType.income);

    final tabs = StatementParser.parse('Data\tValor\tDescrição\n01/01/2026\t-10.00\tÔnibus\n');
    expect(tabs.entries.single.description, 'Ônibus');
    expect(tabs.entries.single.amount, closeTo(10, 0.001));
  });

  test('recusa arquivo vazio, sem colunas e linhas inválidas', () {
    expect(StatementParser.parse('   ').message, 'O arquivo está vazio.');
    expect(
      StatementParser.parse('olá\nmundo').message,
      contains('data e valor'),
    );

    final result = StatementParser.parse('''
\uFEFFData,Valor,Descrição
32/01/2026,10,Quebrada
01/01/2026,0,00,Zerada
01/01/2026,"(10,50)",Loja
não é data,8,Texto
''');

    expect(result.entries.single.description, 'Loja');
    expect(result.entries.single.type, TransactionType.expense);
    expect(result.entries.single.amount, closeTo(10.50, 0.001));
    expect(result.rejected.map((item) => item.reason), [
      'Data inválida',
      'Valor zerado',
      'Data inválida',
    ]);
  });

  test('mesmo dia e valor com descrições diferentes não são repetidos', () {
    final parsed = StatementParser.parse('''
Data,Valor,Identificador,Descrição
13/09/2026,21.00,6aa73c5c,Transferência recebida pelo Pix - Vinicius
13/09/2026,21.00,6aa73d04,Transferência Recebida - João Heitor
13/09/2026,21.00,6aa73c5c,Transferência recebida pelo Pix - Vinicius
03/09/2026,20.00,,Mesada
03/09/2026,20.00,,Mesada
03/09/2026,-20.00,,Outra saída
''');

    final manual = TransactionEntity(
      id: 'old',
      userId: 'u1',
      type: TransactionType.income,
      category: 'Outros',
      value: 21,
      description: 'Transferência Recebida - João Heitor',
      date: DateTime(2026, 9, 13),
      createdAt: DateTime(2026, 9, 13),
    );

    final fresh = StatementParser.markDuplicates(
      parsed.entries.take(2).toList(),
      const [],
    );
    expect(fresh[0].duplicate, isFalse);
    expect(fresh[1].duplicate, isFalse);

    final rows = StatementParser.markDuplicates(parsed.entries, [manual]);
    expect(rows[0].duplicate, isFalse);
    expect(rows[0].included, isTrue);
    expect(rows[1].duplicate, isTrue);
    expect(rows[1].included, isFalse);
    expect(rows[2].duplicate, isTrue);
    expect(rows[3].included, isTrue);
    expect(rows[4].duplicate, isTrue);
    expect(rows[5].duplicate, isFalse);

    final again = StatementParser.markDuplicates(parsed.entries, [
      TransactionEntity(
        id: 'saved',
        userId: 'u1',
        type: TransactionType.income,
        category: 'Outros',
        value: 21,
        description: 'Transferência recebida pelo Pix - Vinicius',
        date: DateTime(2026, 9, 13),
        sourceId: '6aa73c5c',
        createdAt: DateTime(2026, 9, 13),
      ),
    ]);
    expect(again[0].duplicate, isTrue);
    expect(again[1].duplicate, isFalse);

    final built = StatementImporter.build(
      userId: 'u1',
      entries: [rows[0], rows[1], rows[5]],
      nextId: () => 'new',
    );
    expect(built, hasLength(2));
    expect(built.first.sourceId, '6aa73c5c');
    expect(built.last.type, TransactionType.expense);
  });
}
