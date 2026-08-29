import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/asset_remote_datasource.dart';
import '../../data/datasources/brapi_market_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/category_remote_datasource.dart';
import '../../data/datasources/goal_remote_datasource.dart';
import '../../data/datasources/investment_remote_datasource.dart';
import '../../data/datasources/settings_local_datasource.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/datasources/transfer_remote_datasource.dart';
import '../../data/repositories/transfer_repository_impl.dart';
import '../../data/datasources/user_remote_datasource.dart';
import '../../data/repositories/asset_repository_impl.dart';
import '../../data/repositories/market_quote_repository_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../data/repositories/goal_repository_impl.dart';
import '../../data/datasources/reserve_remote_datasource.dart';
import '../../data/repositories/investment_repository_impl.dart';
import '../../data/repositories/reserve_repository_impl.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/repositories/market_quote_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/repositories/investment_repository.dart';
import '../../domain/repositories/reserve_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../../domain/services/asset_trade_service.dart';
import '../../domain/services/dashboard_service.dart';
import '../../domain/services/transfer_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((ref) {
  return SettingsLocalDataSource(ref.watch(sharedPreferencesProvider));
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource();
});

final transactionRemoteDataSourceProvider =
    Provider<TransactionRemoteDataSource>((ref) {
  return TransactionRemoteDataSource();
});

final categoryRemoteDataSourceProvider =
    Provider<CategoryRemoteDataSource>((ref) {
  return CategoryRemoteDataSource();
});

final investmentRemoteDataSourceProvider =
    Provider<InvestmentRemoteDataSource>((ref) {
  return InvestmentRemoteDataSource();
});

final brapiMarketDataSourceProvider = Provider<BrapiMarketDataSource>((ref) {
  return BrapiMarketDataSource();
});

final marketQuoteRepositoryProvider = Provider<MarketQuoteRepository>((ref) {
  return MarketQuoteRepositoryImpl(ref.watch(brapiMarketDataSourceProvider));
});

final assetRemoteDataSourceProvider = Provider<AssetRemoteDataSource>((ref) {
  return AssetRemoteDataSource();
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepositoryImpl(ref.watch(assetRemoteDataSourceProvider));
});

final reserveRemoteDataSourceProvider = Provider<ReserveRemoteDataSource>((ref) {
  return ReserveRemoteDataSource();
});

final reserveRepositoryProvider = Provider<ReserveRepository>((ref) {
  return ReserveRepositoryImpl(ref.watch(reserveRemoteDataSourceProvider));
});

final goalRemoteDataSourceProvider = Provider<GoalRemoteDataSource>((ref) {
  return GoalRemoteDataSource();
});

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionRemoteDataSourceProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(categoryRemoteDataSourceProvider));
});

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  return InvestmentRepositoryImpl(ref.watch(investmentRemoteDataSourceProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepositoryImpl(ref.watch(goalRemoteDataSourceProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(ref.watch(userRemoteDataSourceProvider));
});

final transferRemoteDataSourceProvider =
    Provider<TransferRemoteDataSource>((ref) {
  return TransferRemoteDataSource();
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepositoryImpl(ref.watch(transferRemoteDataSourceProvider));
});

final transferServiceProvider = Provider<TransferService>((ref) {
  return TransferService(
    transferRepository: ref.watch(transferRepositoryProvider),
    reserveRepository: ref.watch(reserveRepositoryProvider),
    investmentRepository: ref.watch(investmentRepositoryProvider),
  );
});

final assetTradeServiceProvider = Provider<AssetTradeService>((ref) {
  return AssetTradeService(
    assetRepository: ref.watch(assetRepositoryProvider),
    transferRepository: ref.watch(transferRepositoryProvider),
  );
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService();
});

final themeModeProvider = StateProvider<AppThemeMode>((ref) {
  return ref.watch(settingsLocalDataSourceProvider).getThemeMode();
});
