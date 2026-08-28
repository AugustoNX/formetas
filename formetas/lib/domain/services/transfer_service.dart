import 'package:uuid/uuid.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/patrimony_calculator.dart';
import '../../core/utils/reserve_calculator.dart';
import '../entities/investment_entity.dart';
import '../entities/reserve_movement_entity.dart';
import '../entities/transaction_entity.dart';
import '../entities/transfer_entity.dart';
import '../repositories/investment_repository.dart';
import '../repositories/reserve_repository.dart';
import '../repositories/transfer_repository.dart';

class TransferException implements Exception {
  TransferException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TransferService {
  TransferService({
    required TransferRepository transferRepository,
    required ReserveRepository reserveRepository,
    required InvestmentRepository investmentRepository,
  })  : _transferRepository = transferRepository,
        _reserveRepository = reserveRepository,
        _investmentRepository = investmentRepository;

  final TransferRepository _transferRepository;
  final ReserveRepository _reserveRepository;
  final InvestmentRepository _investmentRepository;

  static const defaultInvestmentName = 'Meus Investimentos';

  double computeBalance({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    DateTime? until,
  }) {
    return PatrimonyCalculator.balance(
      transactions: transactions,
      transfers: transfers,
      until: until,
    );
  }

  double availableFrom({
    required WalletType fromType,
    String? fromId,
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required List<ReserveWithMovements> reserves,
    required List<InvestmentEntity> investments,
    required double cdiRate,
  }) {
    switch (fromType) {
      case WalletType.balance:
        return computeBalance(
          transactions: transactions,
          transfers: transfers,
        );
      case WalletType.reserve:
        if (fromId == null || fromId.isEmpty) return 0;
        final item = reserves.where((r) => r.reserve.id == fromId).firstOrNull;
        if (item == null) return 0;
        return ReserveCalculator.maxWithdrawal(
          reserve: item.reserve,
          movements: item.movements,
          cdiRate: cdiRate,
        );
      case WalletType.investment:
        if (fromId == null || fromId.isEmpty) return 0;
        final investment =
            investments.where((i) => i.id == fromId).firstOrNull;
        return investment?.currentValue ?? 0;
    }
  }

  void validateAmount({
    required WalletType fromType,
    String? fromId,
    required double amount,
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required List<ReserveWithMovements> reserves,
    required List<InvestmentEntity> investments,
    required double cdiRate,
  }) {
    final available = availableFrom(
      fromType: fromType,
      fromId: fromId,
      transactions: transactions,
      transfers: transfers,
      reserves: reserves,
      investments: investments,
      cdiRate: cdiRate,
    );

    if (CurrencyFormatter.exceeds(amount, available)) {
      final label = switch (fromType) {
        WalletType.balance => 'Saldo insuficiente',
        WalletType.reserve => 'Saldo insuficiente na caixinha',
        WalletType.investment => 'Saldo insuficiente em investimentos',
      };
      throw TransferException(label);
    }
  }

  Future<void> execute({
    required String userId,
    required WalletType fromType,
    required WalletType toType,
    required double amount,
    required DateTime date,
    String? fromId,
    String? toId,
    String? description,
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    required List<ReserveWithMovements> reserves,
    required List<InvestmentEntity> investments,
    required double cdiRate,
  }) async {
    if (amount <= 0) throw TransferException('Informe um valor maior que zero');
    if (fromType == toType && fromId == toId) {
      throw TransferException('Origem e destino devem ser diferentes');
    }

    _validateWalletId(fromType, fromId);
    _validateWalletId(toType, toId);

    validateAmount(
      fromType: fromType,
      fromId: fromId,
      amount: amount,
      transactions: transactions,
      transfers: transfers,
      reserves: reserves,
      investments: investments,
      cdiRate: cdiRate,
    );

    final transfer = TransferEntity(
      id: const Uuid().v4(),
      userId: userId,
      amount: amount,
      fromType: fromType,
      toType: toType,
      fromId: fromId,
      toId: toId,
      description: description,
      date: date,
      createdAt: DateTime.now(),
    );

    await _transferRepository.createTransfer(transfer);

    if (toType == WalletType.reserve) {
      await _depositToReserve(userId, toId!, amount, date, description, cdiRate);
    }
    if (fromType == WalletType.reserve) {
      await _withdrawFromReserve(userId, fromId!, amount, date, description, cdiRate);
    }

    if (toType == WalletType.investment) {
      await _addToInvestment(
        userId: userId,
        investmentId: toId,
        amount: amount,
        date: date,
        investments: investments,
      );
    }
    if (fromType == WalletType.investment) {
      await _removeFromInvestment(investments, fromId!, amount);
    }
  }

  Future<String> ensureDefaultInvestment(String userId) async {
    final list = await _investmentRepository.getInvestments(userId);
    if (list.isNotEmpty) return list.first.id;

    final investment = InvestmentEntity(
      id: const Uuid().v4(),
      userId: userId,
      name: defaultInvestmentName,
      type: InvestmentType.outros,
      initialValue: 0,
      currentValue: 0,
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _investmentRepository.createInvestment(investment);
    return investment.id;
  }

  void _validateWalletId(WalletType type, String? id) {
    if (type == WalletType.balance) return;
    if (id == null || id.isEmpty) {
      throw TransferException('Selecione ${_walletLabel(type)}');
    }
  }

  String _walletLabel(WalletType type) => switch (type) {
        WalletType.reserve => 'uma caixinha',
        WalletType.investment => 'investimentos',
        WalletType.balance => 'saldo',
      };

  InvestmentEntity _findInvestment(
    List<InvestmentEntity> investments,
    String id,
  ) {
    return investments.firstWhere(
      (i) => i.id == id,
      orElse: () => throw TransferException('Investimento não encontrado'),
    );
  }

  Future<void> _depositToReserve(
    String userId,
    String reserveId,
    double amount,
    DateTime date,
    String? description,
    double cdiRate,
  ) async {
    final movement = ReserveMovementEntity(
      id: const Uuid().v4(),
      reserveId: reserveId,
      userId: userId,
      type: ReserveMovementType.deposit,
      amount: amount,
      date: date,
      description: description ?? 'Aporte do saldo',
      createdAt: DateTime.now(),
    );
    await _reserveRepository.createMovement(movement);
    await _syncReserveTotals(userId, reserveId, cdiRate);
  }

  Future<void> _withdrawFromReserve(
    String userId,
    String reserveId,
    double amount,
    DateTime date,
    String? description,
    double cdiRate,
  ) async {
    final movement = ReserveMovementEntity(
      id: const Uuid().v4(),
      reserveId: reserveId,
      userId: userId,
      type: ReserveMovementType.withdrawal,
      amount: amount,
      date: date,
      description: description ?? 'Resgate para saldo',
      createdAt: DateTime.now(),
    );
    await _reserveRepository.createMovement(movement);
    await _syncReserveTotals(userId, reserveId, cdiRate);
  }

  Future<void> _syncReserveTotals(
    String userId,
    String reserveId,
    double cdiRate,
  ) async {
    final items = await _reserveRepository.getReservesWithMovements(userId);
    final item = items.where((r) => r.reserve.id == reserveId).firstOrNull;
    if (item == null) return;

    final result = ReserveCalculator.compute(
      reserve: item.reserve,
      movements: item.movements,
      cdiRate: cdiRate,
    );

    await _reserveRepository.updateReserve(
      item.reserve.copyWith(
        currentValue: result.currentValue,
        accumulatedYield: result.totalAccumulated,
      ),
    );
  }

  Future<void> _addToInvestment({
    required String userId,
    required String? investmentId,
    required double amount,
    required DateTime date,
    required List<InvestmentEntity> investments,
  }) async {
    final id = investmentId ?? await ensureDefaultInvestment(userId);
    final existing = investments.where((i) => i.id == id).firstOrNull;
    final investment = existing ??
        InvestmentEntity(
          id: id,
          userId: userId,
          name: defaultInvestmentName,
          type: InvestmentType.outros,
          initialValue: 0,
          currentValue: 0,
          startDate: date,
          createdAt: DateTime.now(),
        );

    final updated = investment.copyWith(
      initialValue: investment.initialValue + amount,
      currentValue: investment.currentValue + amount,
    );

    if (existing != null) {
      await _investmentRepository.updateInvestment(updated);
    } else {
      await _investmentRepository.createInvestment(updated);
    }
  }

  Future<void> _removeFromInvestment(
    List<InvestmentEntity> investments,
    String investmentId,
    double amount,
  ) async {
    final investment = _findInvestment(investments, investmentId);
    final updated = investment.copyWith(
      currentValue: investment.currentValue - amount,
    );
    await _investmentRepository.updateInvestment(updated);
  }
}
