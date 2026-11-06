import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ant_brain.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/ml/ant_brain_trainer.dart';
import '../../domain/services/ml/category_classifier.dart';
import '../../domain/services/ml/classifier_thresholds.dart';
import '../../domain/services/ml/feature_extractor.dart';
import '../../domain/services/ml/smart_categorizer.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

final antBrainProvider =
    AsyncNotifierProvider<AntBrainController, AntBrainSnapshot>(
      AntBrainController.new,
    );

/// Cérebro da formiga em memória, carregado uma vez por sessão.
class AntBrainController extends AsyncNotifier<AntBrainSnapshot> {
  Timer? _timer;
  int _lifetime = 0;
  int _saveGeneration = 0;
  AntBrainSnapshot? _cache;
  String? _cacheUser;
  Future<AntBrainSnapshot>? _inFlight;
  String? _inFlightUser;

  @override
  Future<AntBrainSnapshot> build() {
    final life = ++_lifetime;
    ref.onDispose(() {
      if (life == _lifetime) _timer?.cancel();
    });

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      _cache = null;
      _cacheUser = null;
      _inFlight = null;
      _inFlightUser = null;
      return Future.value(AntBrainSnapshot.empty());
    }
    if (_cacheUser != null && _cacheUser != user.id) {
      _cache = null;
      _inFlight = null;
      _inFlightUser = null;
    }
    if (_cache != null && _cacheUser == user.id) {
      return Future.value(_cache);
    }
    if (_inFlight != null && _inFlightUser == user.id) {
      return _inFlight!;
    }

    _inFlightUser = user.id;
    final future = _load(user.id);
    _inFlight = future;
    return future;
  }

  Future<AntBrainSnapshot> _load(String userId) async {
    final repo = ref.read(antBrainRepositoryProvider);
    final stored = await repo.load(userId);
    final versionOk =
        stored != null &&
        stored.model.schemaVersion == ClassifierThresholds.schemaVersion;
    if (stored != null &&
        versionOk &&
        (!stored.model.isEmpty || stored.cleared)) {
      _cache = stored;
      _cacheUser = userId;
      return stored;
    }

    final transactions = await ref
        .read(transactionRepositoryProvider)
        .getTransactions(userId);
    final model = await CategoryClassifier.bootstrap(transactions);
    if (stored != null &&
        versionOk &&
        stored.model.isEmpty &&
        model.isEmpty) {
      _cache = stored;
      _cacheUser = userId;
      return stored;
    }

    final snapshot = AntBrainSnapshot(
      model: model,
      history: stored?.history ?? const [],
    );
    await repo.save(userId, snapshot);
    _cache = snapshot;
    _cacheUser = userId;
    return snapshot;
  }

  Future<ImportSummary> learnImport(List<CategorizedEntry> lines) async {
    final user = ref.read(currentUserProvider);
    final current = _cache ?? await future;
    if (user == null) {
      return const ImportSummary(
        total: 0,
        accepted: 0,
        corrected: 0,
        regra: 0,
        recorrente: 0,
        aprendido: 0,
        heuristica: 0,
        semSugestao: 0,
      );
    }

    final result = const AntBrainTrainer().learnImport(
      snapshot: current,
      lines: lines,
    );
    _publish(result.snapshot, user.id);
    _timer?.cancel();
    try {
      await ref.read(antBrainRepositoryProvider).save(user.id, result.snapshot);
    } catch (_) {
      _scheduleSave();
    }
    return result.summary;
  }

  /// Tira o exemplo da categoria antiga e ensina a nova com peso de correção.
  Future<void> retarget({
    required TransactionEntity before,
    required TransactionEntity after,
  }) async {
    if (before.category == after.category && before.type == after.type) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final current = _cache ?? await future;
    final model = CategoryClassifier.fromMap(current.model.toMap());
    _forget(model, before);
    _remember(model, after);
    _publish(AntBrainSnapshot(model: model, history: current.history), user.id);
    _scheduleSave();
  }

  Future<int> relearnFromHistory() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return 0;
    final current = _cache ?? await future;
    final transactions = await ref
        .read(transactionRepositoryProvider)
        .getTransactions(user.id);
    final model = await CategoryClassifier.bootstrap(transactions);
    _publish(AntBrainSnapshot(model: model, history: current.history), user.id);
    _timer?.cancel();
    await ref
        .read(antBrainRepositoryProvider)
        .save(
          user.id,
          AntBrainSnapshot(model: model, history: current.history),
        );
    return model.exampleCount;
  }

  Future<void> reset() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final current = _cache ?? await future;
    final snapshot = AntBrainSnapshot(
      model: CategoryClassifier(),
      history: current.history,
      cleared: true,
    );
    _publish(snapshot, user.id);
    _timer?.cancel();
    await ref.read(antBrainRepositoryProvider).save(user.id, snapshot);
  }

  void _publish(AntBrainSnapshot snapshot, String userId) {
    _cache = snapshot;
    _cacheUser = userId;
    state = AsyncData(snapshot);
  }

  void _scheduleSave() {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final generation = ++_saveGeneration;
    final life = _lifetime;
    _timer?.cancel();
    _timer = Timer(ClassifierThresholds.saveDebounce, () async {
      if (generation != _saveGeneration || life != _lifetime) return;
      final snapshot = _cache;
      if (snapshot == null) return;
      try {
        await ref.read(antBrainRepositoryProvider).save(userId, snapshot);
      } catch (_) {}
    });
  }

  void _forget(CategoryClassifier model, TransactionEntity transaction) {
    if (!_canLearn(transaction)) return;
    model.untrain(
      _features(transaction),
      transaction.category,
      type: transaction.type,
      weight: ClassifierThresholds.acceptWeight,
    );
  }

  void _remember(CategoryClassifier model, TransactionEntity transaction) {
    if (!_canLearn(transaction)) return;
    model.train(
      _features(transaction),
      transaction.category,
      type: transaction.type,
      weight: ClassifierThresholds.correctionWeight,
      now: DateTime.now(),
    );
  }

  bool _canLearn(TransactionEntity transaction) {
    if (transaction.category.trim().isEmpty) return false;
    if (transaction.description.trim().isEmpty) return false;
    return transaction.type == TransactionType.income ||
        transaction.type == TransactionType.expense;
  }

  List<String> _features(TransactionEntity transaction) {
    return FeatureExtractor.extract(
      description: transaction.description,
      amount: transaction.value,
      type: transaction.type,
      date: transaction.date,
      paymentMethod: transaction.paymentMethod,
    );
  }
}
