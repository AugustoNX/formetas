import '../../core/utils/reserve_calculator.dart';
import '../entities/onboarding_draft.dart';
import '../entities/reserve_entity.dart';
import '../entities/transaction_entity.dart';

/// Monta o snapshot do dia 1: saldo livre e caixinhas como bolsos separados.
/// O saldo inicial não entra como receita do mês, para o extrato a partir da
/// instalação ficar limpo.
abstract final class OnboardingPlanner {
  static const openingCategory = 'Saldo inicial';
  static const openingDescription = 'Saldo disponível no início';

  static TransactionEntity? openingTransaction({
    required String id,
    required String userId,
    required double availableBalance,
    required DateTime at,
  }) {
    if (availableBalance <= 0) return null;
    return TransactionEntity(
      id: id,
      userId: userId,
      type: TransactionType.opening,
      category: openingCategory,
      value: availableBalance,
      description: openingDescription,
      date: at,
      createdAt: at,
    );
  }

  static List<ReserveEntity> reserves({
    required String userId,
    required OnboardingDraft draft,
    required DateTime at,
    required double cdiRate,
    required String Function() nextId,
  }) {
    return [
      for (final item in draft.reserves)
        if (item.name.trim().isNotEmpty && item.amount > 0)
          _reserve(
            id: nextId(),
            userId: userId,
            name: item.name.trim(),
            amount: item.amount,
            at: at,
            cdiRate: cdiRate,
          ),
    ];
  }

  static ReserveEntity _reserve({
    required String id,
    required String userId,
    required String name,
    required double amount,
    required DateTime at,
    required double cdiRate,
  }) {
    final seed = ReserveEntity(
      id: id,
      userId: userId,
      name: name,
      type: ReserveType.caixinha,
      initialValue: amount,
      currentValue: 0,
      cdiPercent: 100,
      startDate: at,
      createdAt: at,
    );
    final result = ReserveCalculator.compute(
      reserve: seed,
      movements: const [],
      cdiRate: cdiRate,
      referenceDate: at,
    );
    return seed.copyWith(
      currentValue: result.currentValue,
      accumulatedYield: result.totalAccumulated,
    );
  }
}
