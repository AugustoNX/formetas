import 'dart:convert';

import '../entities/statement_import.dart';
import '../entities/transaction_entity.dart';
import '../entities/transfer_entity.dart';
import 'statement_text.dart';

abstract final class StatementParser {
  static String decode(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3));
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  static StatementParseResult parse(String text) {
    final source = text.replaceFirst('\uFEFF', '').trim();
    if (source.isEmpty) {
      return const StatementParseResult(message: 'O arquivo está vazio.');
    }

    final table = _bestTable(source);
    if (table == null) {
      return const StatementParseResult(
        message:
            'Não encontrei colunas de data e valor. Confira se o CSV é o extrato do banco.',
      );
    }

    final entries = <StatementEntry>[];
    final rejected = <StatementRejection>[];

    for (final row in table.rows.skip(table.header.index + 1)) {
      final cells = _align(row.cells, table.header, table.delimiter);
      if (cells.every((cell) => _clean(cell).isEmpty)) continue;
      if (_headerOf(cells) != null) continue;

      final raw = cells.map(_clean).where((cell) => cell.isNotEmpty).join(' | ');
      final date = _date(_cell(cells, table.header.date));
      final signed = _signedAmount(cells, table.header);
      final description = _description(cells, table.header);
      final sourceId = _blankToNull(_clean(_cell(cells, table.header.sourceId)));

      if (date == null) {
        rejected.add(StatementRejection(
          line: row.line,
          reason: 'Data inválida',
          raw: raw,
        ));
        continue;
      }
      if (signed == null) {
        rejected.add(StatementRejection(
          line: row.line,
          reason: 'Valor inválido',
          raw: raw,
        ));
        continue;
      }
      if (signed == 0) {
        rejected.add(StatementRejection(
          line: row.line,
          reason: 'Valor zerado',
          raw: raw,
        ));
        continue;
      }
      if (signed.isNaN) {
        rejected.add(StatementRejection(
          line: row.line,
          reason: 'Débito e crédito na mesma linha',
          raw: raw,
        ));
        continue;
      }

      entries.add(StatementEntry(
        line: row.line,
        date: date,
        amount: signed.abs(),
        type: signed < 0 ? TransactionType.expense : TransactionType.income,
        description: description,
        sourceId: sourceId,
      ));
    }

    if (entries.isEmpty && rejected.isEmpty) {
      return const StatementParseResult(
        message: 'O extrato não tem lançamentos.',
      );
    }

    return StatementParseResult(
      entries: entries,
      rejected: rejected,
      dateColumn: table.header.dateLabel,
      descriptionColumn: table.header.descriptionLabel,
      amountColumn: table.header.amountLabel,
    );
  }

  static List<StatementEntry> markDuplicates(
    List<StatementEntry> entries,
    List<TransactionEntity> existing, {
    List<TransferEntity> transfers = const [],
  }) {
    final seen = _DuplicateIndex.from(existing);
    final reserves = _ReserveDuplicateIndex.from(transfers);
    return [
      for (final entry in entries)
        entry.role == StatementRole.transaction
            ? seen.take(entry)
            : reserves.take(entry),
    ];
  }
}

enum _Role { date, amount, debit, credit, description, narrative, sourceId }

class _Synonym {
  const _Synonym(this.role, this.text);

  final _Role role;
  final String text;
}

const _synonyms = [
  _Synonym(_Role.date, 'data lancamento'),
  _Synonym(_Role.date, 'data do lancamento'),
  _Synonym(_Role.date, 'data movimento'),
  _Synonym(_Role.date, 'data da transacao'),
  _Synonym(_Role.date, 'data transacao'),
  _Synonym(_Role.date, 'data'),
  _Synonym(_Role.date, 'date'),
  _Synonym(_Role.date, 'dt'),
  _Synonym(_Role.debit, 'valor debito'),
  _Synonym(_Role.debit, 'debito'),
  _Synonym(_Role.debit, 'debit'),
  _Synonym(_Role.debit, 'saidas'),
  _Synonym(_Role.debit, 'saida'),
  _Synonym(_Role.credit, 'valor credito'),
  _Synonym(_Role.credit, 'credito'),
  _Synonym(_Role.credit, 'credit'),
  _Synonym(_Role.credit, 'entradas'),
  _Synonym(_Role.credit, 'entrada'),
  _Synonym(_Role.amount, 'valor'),
  _Synonym(_Role.amount, 'amount'),
  _Synonym(_Role.amount, 'value'),
  _Synonym(_Role.amount, 'quantia'),
  _Synonym(_Role.description, 'descricao'),
  _Synonym(_Role.description, 'description'),
  _Synonym(_Role.description, 'titulo'),
  _Synonym(_Role.description, 'detalhe'),
  _Synonym(_Role.description, 'memo'),
  _Synonym(_Role.narrative, 'historico'),
  _Synonym(_Role.narrative, 'lancamento'),
  _Synonym(_Role.sourceId, 'identificador'),
  _Synonym(_Role.sourceId, 'id transacao'),
  _Synonym(_Role.sourceId, 'nsu'),
];

class _CsvRow {
  const _CsvRow(this.line, this.cells);

  final int line;
  final List<String> cells;
}

class _Header {
  const _Header({
    required this.index,
    required this.width,
    required this.labels,
    required this.date,
    required this.dateLabel,
    this.amount,
    this.debit,
    this.credit,
    this.description,
    this.narrative,
    this.sourceId,
  });

  final int index;
  final int width;
  final List<String> labels;
  final int date;
  final String dateLabel;
  final int? amount;
  final int? debit;
  final int? credit;
  final int? description;
  final int? narrative;
  final int? sourceId;

  int get score {
    var value = 5;
    if (amount != null) value += 3;
    if (debit != null || credit != null) value += 3;
    if (description != null) value += 2;
    if (narrative != null) value += 1;
    if (sourceId != null) value += 1;
    return value;
  }

  String? get descriptionLabel {
    final index = description ?? narrative;
    if (index == null || index >= labels.length) return null;
    return _clean(labels[index]);
  }

  String? get amountLabel {
    if (amount != null && amount! < labels.length) return _clean(labels[amount!]);
    final parts = <String>[
      if (debit != null && debit! < labels.length) _clean(labels[debit!]),
      if (credit != null && credit! < labels.length) _clean(labels[credit!]),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' / ');
  }
}

class _Table {
  const _Table({
    required this.delimiter,
    required this.header,
    required this.rows,
  });

  final String delimiter;
  final _Header header;
  final List<_CsvRow> rows;
}

_Table? _bestTable(String text) {
  _Table? best;
  for (final delimiter in const [',', ';', '\t']) {
    final rows = _readCsv(text, delimiter);
    for (var i = 0; i < rows.length; i++) {
      final header = _headerOf(rows[i].cells, index: i);
      if (header == null) continue;
      final candidate = _Table(delimiter: delimiter, header: header, rows: rows);
      if (best == null ||
          header.score > best.header.score ||
          (header.score == best.header.score && header.index < best.header.index)) {
        best = candidate;
      }
      break;
    }
  }
  return best;
}

_Header? _headerOf(List<String> cells, {int index = 0}) {
  int? date;
  int? amount;
  int? debit;
  int? credit;
  int? description;
  int? narrative;
  int? sourceId;

  for (var i = 0; i < cells.length; i++) {
    switch (_roleOf(cells[i])) {
      case _Role.date:
        date ??= i;
      case _Role.amount:
        amount ??= i;
      case _Role.debit:
        debit ??= i;
      case _Role.credit:
        credit ??= i;
      case _Role.description:
        description ??= i;
      case _Role.narrative:
        narrative ??= i;
      case _Role.sourceId:
        sourceId ??= i;
      case null:
        break;
    }
  }

  if (date == null || (amount == null && debit == null && credit == null)) {
    return null;
  }

  return _Header(
    index: index,
    width: cells.length,
    labels: cells,
    date: date,
    dateLabel: _clean(cells[date]),
    amount: amount,
    debit: debit,
    credit: credit,
    description: description,
    narrative: narrative,
    sourceId: sourceId,
  );
}

_Role? _roleOf(String cell) {
  final text = _normalize(cell);
  if (text.isEmpty) return null;

  _Synonym? best;
  for (final synonym in _synonyms) {
    final matches = text == synonym.text || text.startsWith('${synonym.text} ');
    if (!matches) continue;
    if (synonym.role == _Role.amount &&
        (text.contains('saldo') || text.contains('balance'))) {
      continue;
    }
    if (best == null || synonym.text.length > best.text.length) best = synonym;
  }
  return best?.role;
}

List<String> _align(List<String> cells, _Header header, String delimiter) {
  final description = header.description;
  if (description == null || description != header.width - 1 || cells.length <= header.width) {
    return cells;
  }
  return [
    ...cells.sublist(0, description),
    cells.sublist(description).join(delimiter),
  ];
}

String _description(List<String> cells, _Header header) {
  final primary = _clean(_cell(cells, header.description));
  if (primary.isNotEmpty) return StatementText.shorten(primary);
  return StatementText.shorten(_clean(_cell(cells, header.narrative)));
}

double? _signedAmount(List<String> cells, _Header header) {
  if (header.amount != null) return _amount(_cell(cells, header.amount));

  final debit = _amount(_cell(cells, header.debit));
  final credit = _amount(_cell(cells, header.credit));
  final debitValue = debit?.abs() ?? 0;
  final creditValue = credit?.abs() ?? 0;
  if (debit == null && credit == null) return null;
  if (debitValue > 0 && creditValue > 0) return double.nan;
  if (debitValue > 0) return -debitValue;
  if (creditValue > 0) return creditValue;
  return 0;
}

String _cell(List<String> cells, int? index) {
  if (index == null || index < 0 || index >= cells.length) return '';
  return cells[index];
}

List<_CsvRow> _readCsv(String text, String delimiter) {
  final rows = <_CsvRow>[];
  final cells = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  var line = 1;
  var rowLine = 1;

  void pushCell() {
    cells.add(buffer.toString());
    buffer.clear();
  }

  void pushRow() {
    pushCell();
    if (cells.any((cell) => _clean(cell).isNotEmpty)) {
      rows.add(_CsvRow(rowLine, List<String>.of(cells)));
    }
    cells.clear();
    rowLine = line;
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
      continue;
    }
    if (!quoted && char == delimiter) {
      pushCell();
      continue;
    }
    if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      pushRow();
      line++;
      rowLine = line;
      continue;
    }
    buffer.write(char);
  }

  pushRow();
  return rows;
}

const _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

String _normalize(String value) {
  final buffer = StringBuffer();
  for (final rune in _clean(value).toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final mapped = _accents[char];
    if (mapped != null) {
      buffer.write(mapped);
    } else if ((rune >= 48 && rune <= 57) || (rune >= 97 && rune <= 122)) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _clean(String value) {
  return value
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _blankToNull(String value) => value.isEmpty ? null : value;

DateTime? _date(String raw) {
  final text = _clean(raw);
  if (text.isEmpty) return null;
  final token = text.split(RegExp(r'[\sT]')).first;

  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(token);
  if (iso != null) {
    return _calendar(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final local = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$').firstMatch(token);
  if (local == null) return null;
  final day = int.parse(local.group(1)!);
  final month = int.parse(local.group(2)!);
  var year = int.parse(local.group(3)!);
  if (year < 100) year += 2000;
  return _calendar(year, month, day);
}

DateTime? _calendar(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

double? _amount(String raw) {
  var text = _clean(raw).toLowerCase().replaceAll('\u00a0', '');
  if (text.isEmpty) return null;

  var negative = false;
  text = text.replaceAll('r\$', '').replaceAll(' ', '');
  if (text.startsWith('(') && text.endsWith(')') && text.length > 2) {
    negative = true;
    text = text.substring(1, text.length - 1);
  }
  if (text.endsWith('-') || text.endsWith('−')) {
    negative = true;
    text = text.substring(0, text.length - 1);
  }
  if (text.startsWith('-') || text.startsWith('−') || text.startsWith('+')) {
    negative = negative || text.startsWith('-') || text.startsWith('−');
    text = text.substring(1);
  }
  if (text.endsWith('d')) {
    negative = true;
    text = text.substring(0, text.length - 1);
  } else if (text.endsWith('c')) {
    text = text.substring(0, text.length - 1);
  }

  text = text.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (text.isEmpty) return null;

  final normalized = _decimal(text);
  final value = double.tryParse(normalized);
  if (value == null) return null;
  if (value == 0) return 0;
  return negative ? -value : value;
}

String _decimal(String text) {
  final hasComma = text.contains(',');
  final hasDot = text.contains('.');
  if (hasComma && hasDot) {
    if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
      return text.replaceAll('.', '').replaceAll(',', '.');
    }
    return text.replaceAll(',', '');
  }

  final separator = hasComma ? ',' : hasDot ? '.' : null;
  if (separator == null) return text;

  final parts = text.split(separator);
  if (parts.length > 2) {
    final grouped = parts.skip(1).every((part) => part.length == 3);
    if (grouped) return parts.join();
    final fraction = parts.removeLast();
    return '${parts.join()}.$fraction';
  }

  final fraction = parts[1];
  if (fraction.length == 3) return parts.join();
  return '${parts[0]}.$fraction';
}

class _DuplicateIndex {
  _DuplicateIndex()
      : ids = <String>{},
        unidentified = <String>{},
        identified = <String>{};

  _DuplicateIndex.from(List<TransactionEntity> existing)
      : ids = <String>{},
        unidentified = <String>{},
        identified = <String>{} {
    for (final item in existing) {
      _remember(
        sourceId: item.sourceId,
        date: item.date,
        type: item.type,
        amount: item.value,
        description: item.description,
      );
    }
  }

  final Set<String> ids;
  final Set<String> unidentified;
  final Set<String> identified;

  StatementEntry take(StatementEntry entry) {
    final sourceId = _blankToNull(entry.sourceId?.trim() ?? '');
    final movement = _movementKey(
      entry.date,
      entry.type,
      entry.amount,
      entry.description,
    );
    final duplicate = sourceId != null
        ? ids.contains(sourceId) || unidentified.contains(movement)
        : unidentified.contains(movement) || identified.contains(movement);
    _remember(
      sourceId: sourceId,
      date: entry.date,
      type: entry.type,
      amount: entry.amount,
      description: entry.description,
    );
    if (!duplicate) return entry;
    return entry.copyWith(duplicate: true);
  }

  void _remember({
    required String? sourceId,
    required DateTime date,
    required TransactionType type,
    required double amount,
    required String description,
  }) {
    final movement = _movementKey(date, type, amount, description);
    final id = _blankToNull(sourceId?.trim() ?? '');
    if (id != null) {
      ids.add(id);
      identified.add(movement);
      return;
    }
    unidentified.add(movement);
  }
}

String _movementKey(
  DateTime date,
  TransactionType type,
  double amount,
  String description,
) {
  final day = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final cents = (amount.abs() * 100).round();
  return '$day|${type.name}|$cents|${_clean(description).toLowerCase()}';
}

class _ReserveDuplicateIndex {
  _ReserveDuplicateIndex.from(List<TransferEntity> transfers)
      : ids = <String>{},
        unidentified = <String>{},
        identified = <String>{} {
    for (final transfer in transfers) {
      final role = _transferRole(transfer);
      if (role == null) continue;
      unidentified.add(
        _reserveKey(role, transfer.date, transfer.amount, transfer.description ?? ''),
      );
    }
  }

  final Set<String> ids;
  final Set<String> unidentified;
  final Set<String> identified;

  StatementEntry take(StatementEntry entry) {
    final sourceId = _blankToNull(entry.sourceId?.trim() ?? '');
    final key = _reserveKey(entry.role, entry.date, entry.amount, entry.description);
    final duplicate = sourceId != null
        ? ids.contains(sourceId) || unidentified.contains(key)
        : unidentified.contains(key) || identified.contains(key);
    if (sourceId != null) {
      ids.add(sourceId);
      identified.add(key);
    } else {
      unidentified.add(key);
    }
    if (!duplicate) return entry;
    return entry.copyWith(duplicate: true);
  }
}

StatementRole? _transferRole(TransferEntity transfer) {
  if (transfer.fromType == WalletType.balance &&
      transfer.toType == WalletType.reserve) {
    return StatementRole.toReserve;
  }
  if (transfer.fromType == WalletType.reserve &&
      transfer.toType == WalletType.balance) {
    return StatementRole.fromReserve;
  }
  return null;
}

String _reserveKey(
  StatementRole role,
  DateTime date,
  double amount,
  String description,
) {
  final day = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final cents = (amount.abs() * 100).round();
  return '${role.name}|$day|$cents|${_clean(description).toLowerCase()}';
}
