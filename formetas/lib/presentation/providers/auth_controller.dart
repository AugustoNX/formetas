import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'auth_provider.dart';
import 'core_providers.dart';
import 'data_providers.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  AuthRepository get _authRepo => _ref.read(authRepositoryProvider);

  Future<UserEntity?> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepo.signIn(email: email, password: password);
      state = const AsyncValue.data(null);
      return user;
    } on AuthFailure catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<UserEntity?> signUp(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepo.signUp(
        name: name,
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
      return user;
    } on AuthFailure catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authRepo.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
    } on AuthFailure catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    _ref.invalidate(transactionsProvider);
    _ref.invalidate(investmentsProvider);
    _ref.invalidate(reservesWithMovementsProvider);
    _ref.invalidate(transfersProvider);
    _ref.invalidate(goalsProvider);
    _ref.invalidate(settingsProvider);
    _ref.invalidate(customCategoriesProvider);
    _ref.read(selectedMonthProvider.notifier).state =
        DateTime(DateTime.now().year, DateTime.now().month);
    _ref.read(transactionFilterProvider.notifier).state =
        const TransactionFilter();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});
