import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recurring_pattern.dart';
import '../../domain/services/recurrence_detector.dart';
import 'data_providers.dart';

final recurrenceDetectorProvider = Provider<RecurrenceDetector>(
  (_) => const RecurrenceDetector(),
);

/// Salários, contas fixas e assinaturas detectados no histórico, no aparelho.
final recurringPatternsProvider =
    Provider<AsyncValue<List<RecurringPattern>>>((ref) {
  final detector = ref.watch(recurrenceDetectorProvider);
  return ref
      .watch(transactionsProvider)
      .whenData((transactions) => detector.detect(transactions));
});
