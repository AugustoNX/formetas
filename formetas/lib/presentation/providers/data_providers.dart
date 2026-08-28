import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category_entity.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/entities/investment_entity.dart';
import '../../domain/entities/reserve_movement_entity.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/movement_entry.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/category_merger.dart';
import '../../domain/services/movement_list_builder.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

final settingsProvider = StreamProvider<SettingsEntity>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const SettingsEntity());
  return ref.watch(userRepositoryProvider).watchSettings(user.id);
});

final transactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(transactionRepositoryProvider).watchTransactions(user.id);
});

final customCategoriesProvider = StreamProvider<List<CategoryEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(categoryRepositoryProvider).watchCustomCategories(user.id);
});

final categoriesProvider = Provider<AsyncValue<List<CategoryEntity>>>((ref) {
  final user = ref.watch(currentUserProvider);
  final custom = ref.watch(customCategoriesProvider);

  if (user == null) return const AsyncValue.data([]);

  return custom.when(
    loading: () => AsyncValue.data(CategoryMerger.merge(userId: user.id, custom: [])),
    error: AsyncValue.error,
    data: (list) => AsyncValue.data(
      CategoryMerger.merge(userId: user.id, custom: list),
    ),
  );
});

final investmentsProvider = StreamProvider<List<InvestmentEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(investmentRepositoryProvider).watchInvestments(user.id);
});

final transfersProvider = StreamProvider<List<TransferEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(transferRepositoryProvider).watchTransfers(user.id);
});

final reservesWithMovementsProvider =
    StreamProvider<List<ReserveWithMovements>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(reserveRepositoryProvider).watchReservesWithMovements(user.id);
});

final goalsProvider = StreamProvider<List<GoalEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(goalRepositoryProvider).watchGoals(user.id);
});

final transactionFilterProvider =
    StateProvider<TransactionFilter>((ref) => const TransactionFilter());

final movementsProvider = Provider<AsyncValue<List<MovementEntry>>>((ref) {
  final user = ref.watch(currentUserProvider);
  final transactions = ref.watch(transactionsProvider);
  final transfers = ref.watch(transfersProvider);
  final reserves = ref.watch(reservesWithMovementsProvider);
  final investments = ref.watch(investmentsProvider);

  if (user == null) return const AsyncValue.data([]);

  if (transactions.isLoading ||
      transfers.isLoading ||
      reserves.isLoading ||
      investments.isLoading) {
    return const AsyncValue.loading();
  }

  if (transactions.hasError) {
    return AsyncValue.error(transactions.error!, transactions.stackTrace!);
  }
  if (transfers.hasError) {
    return AsyncValue.error(transfers.error!, transfers.stackTrace!);
  }
  if (reserves.hasError) {
    return AsyncValue.error(reserves.error!, reserves.stackTrace!);
  }
  if (investments.hasError) {
    return AsyncValue.error(investments.error!, investments.stackTrace!);
  }

  return AsyncValue.data(
    MovementListBuilder.build(
      transactions: transactions.requireValue,
      transfers: transfers.requireValue,
      reserves: reserves.requireValue,
      investments: investments.requireValue,
    ),
  );
});

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading || auth.valueOrNull == null) {
    return const AsyncValue.loading();
  }

  final transactions = ref.watch(transactionsProvider);
  final investments = ref.watch(investmentsProvider);
  final reserves = ref.watch(reservesWithMovementsProvider);
  final transfers = ref.watch(transfersProvider);
  final settings = ref.watch(settingsProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final service = ref.watch(dashboardServiceProvider);

  if (transactions.isLoading ||
      investments.isLoading ||
      reserves.isLoading ||
      transfers.isLoading ||
      settings.isLoading) {
    return const AsyncValue.loading();
  }

  if (transactions.hasError) return AsyncValue.error(transactions.error!, transactions.stackTrace!);
  if (investments.hasError) return AsyncValue.error(investments.error!, investments.stackTrace!);
  if (reserves.hasError) return AsyncValue.error(reserves.error!, reserves.stackTrace!);
  if (transfers.hasError) return AsyncValue.error(transfers.error!, transfers.stackTrace!);
  if (settings.hasError) return AsyncValue.error(settings.error!, settings.stackTrace!);

  return AsyncValue.data(service.compute(
    transactions: transactions.requireValue,
    investments: investments.requireValue,
    reservesWithMovements: reserves.requireValue,
    transfers: transfers.requireValue,
    settings: settings.requireValue,
    selectedMonth: selectedMonth,
  ));
});

final statisticsProvider = Provider<AsyncValue<StatisticsSummary>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading || auth.valueOrNull == null) {
    return const AsyncValue.loading();
  }

  final transactions = ref.watch(transactionsProvider);
  final investments = ref.watch(investmentsProvider);
  final reserves = ref.watch(reservesWithMovementsProvider);
  final transfers = ref.watch(transfersProvider);
  final settings = ref.watch(settingsProvider);
  final service = ref.watch(dashboardServiceProvider);

  if (transactions.isLoading ||
      investments.isLoading ||
      reserves.isLoading ||
      transfers.isLoading ||
      settings.isLoading) {
    return const AsyncValue.loading();
  }

  if (transactions.hasError) return AsyncValue.error(transactions.error!, transactions.stackTrace!);
  if (investments.hasError) return AsyncValue.error(investments.error!, investments.stackTrace!);
  if (reserves.hasError) return AsyncValue.error(reserves.error!, reserves.stackTrace!);
  if (transfers.hasError) return AsyncValue.error(transfers.error!, transfers.stackTrace!);
  if (settings.hasError) return AsyncValue.error(settings.error!, settings.stackTrace!);

  return AsyncValue.data(service.computeStatistics(
    transactions: transactions.requireValue,
    investments: investments.requireValue,
    reservesWithMovements: reserves.requireValue,
    transfers: transfers.requireValue,
    settings: settings.requireValue,
  ));
});
