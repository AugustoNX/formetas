import '../../core/utils/reserve_calculator.dart';
import '../entities/investment_entity.dart';
import '../entities/import_rule.dart';
import '../entities/reserve_entity.dart';
import '../entities/reserve_movement_entity.dart';
import '../entities/statement_import.dart';
import '../entities/transfer_entity.dart';
import '../repositories/import_rule_repository.dart';
import '../repositories/reserve_repository.dart';
import '../repositories/transaction_repository.dart';
import '../../core/utils/balance_cutoff.dart';
import 'statement_classifier.dart';
import 'statement_importer.dart';
import 'statement_reserve_plan.dart';
import 'transfer_service.dart';

class StatementImportResult {
  const StatementImportResult({
    required this.transactions,
    required this.reserveMoves,
  });

  final int transactions;
  final int reserveMoves;

  int get total => transactions + reserveMoves;
}

class StatementImportService {
  const StatementImportService({
    required TransactionRepository transactionRepository,
    required ReserveRepository reserveRepository,
    required ImportRuleRepository importRuleRepository,
    required TransferService transferService,
    required this.nextId,
  }) : _transactions = transactionRepository,
       _reserves = reserveRepository,
       _rules = importRuleRepository,
       _transfers = transferService;

  final TransactionRepository _transactions;
  final ReserveRepository _reserves;
  final ImportRuleRepository _rules;
  final TransferService _transfers;
  final String Function() nextId;

  Future<StatementImportResult> save({
    required String userId,
    required List<StatementEntry> entries,
    required double cdiRate,
  }) async {
    final selected = entries.where((entry) => entry.included).toList();
    final movements = [
      for (final entry in selected)
        if (entry.role == StatementRole.transaction) entry,
    ];
    final boxes = [
      for (final entry in selected)
        if (entry.role == StatementRole.toReserve ||
            entry.role == StatementRole.fromReserve)
          entry,
    ];

    final transactions = StatementImporter.build(
      userId: userId,
      entries: movements,
      nextId: nextId,
    );
    await _transactions.createTransactions(transactions);
    await _remember(userId, selected);

    if (boxes.isEmpty) {
      return StatementImportResult(
        transactions: transactions.length,
        reserveMoves: 0,
      );
    }

    final reserveId = await _ensureReserve(userId, boxes);
    await _coverOpening(userId, reserveId, boxes, cdiRate);
    final ordered = [...boxes]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.line.compareTo(b.line);
      });

    for (final entry in ordered) {
      final intoBox = entry.role == StatementRole.toReserve;
      await _transfers.recordSettled(
        userId: userId,
        fromType: intoBox ? WalletType.balance : WalletType.reserve,
        toType: intoBox ? WalletType.reserve : WalletType.balance,
        fromId: intoBox ? null : reserveId,
        toId: intoBox ? reserveId : null,
        amount: entry.amount,
        date: entry.date,
        description: entry.description.trim(),
        cdiRate: cdiRate,
      );
    }

    return StatementImportResult(
      transactions: transactions.length,
      reserveMoves: ordered.length,
    );
  }

  Future<void> _remember(String userId, List<StatementEntry> entries) {
    return _rules.saveRules(userId, [
      for (final entry in entries)
        if (entry.description.trim().isNotEmpty)
          ImportRule(
            text: StatementClassifier.normalize(entry.description),
            role: entry.role,
            category: entry.category.trim().isEmpty
                ? 'Outros'
                : entry.category.trim(),
            type: entry.type,
          ),
    ]);
  }

  Future<String> _ensureReserve(
    String userId,
    List<StatementEntry> boxes,
  ) async {
    final existing = await _reserves.getReserves(userId);
    for (final reserve in existing) {
      if (reserve.name.trim().toLowerCase() ==
          StatementClassifier.reserveName.toLowerCase()) {
        return reserve.id;
      }
    }

    final start = boxes
        .map((entry) => entry.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final reserve = ReserveEntity(
      id: nextId(),
      userId: userId,
      name: StatementClassifier.reserveName,
      type: ReserveType.caixinha,
      initialValue: 0,
      currentValue: 0,
      cdiPercent: 100,
      startDate: start,
      liquidity: LiquidityType.daily,
      createdAt: DateTime.now(),
    );
    await _reserves.createReserve(reserve);
    return reserve.id;
  }

  Future<void> _coverOpening(
    String userId,
    String reserveId,
    List<StatementEntry> boxes,
    double cdiRate,
  ) async {
    final items = await _reserves.getReservesWithMovements(userId);
    final item = items
        .where((entry) => entry.reserve.id == reserveId)
        .firstOrNull;
    if (item == null) return;

    final position = ReserveCalculator.compute(
      reserve: item.reserve,
      movements: item.movements,
      cdiRate: cdiRate,
    );
    final counted = [
      for (final entry in boxes)
        if (BalanceCutoff.counts(entry.date, item.reserve.startDate)) entry,
    ];
    final shortfall = StatementReservePlan.openingShortfall(
      current: position.currentValue,
      entries: counted,
    );
    if (shortfall <= 0 || counted.isEmpty) return;

    final date = counted
        .map((entry) => entry.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    await _reserves.createMovement(
      ReserveMovementEntity(
        id: nextId(),
        reserveId: reserveId,
        userId: userId,
        type: ReserveMovementType.deposit,
        amount: shortfall,
        date: date,
        description: 'Saldo que já estava na caixinha',
        createdAt: DateTime.now(),
      ),
    );
  }
}
