import '../entities/transaction_entity.dart';
import '../entities/transfer_entity.dart';

enum MovementKind { income, expense, investment, transfer }

class MovementEntry {
  const MovementEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.transaction,
    this.transfer,
  });

  final String id;
  final DateTime date;
  final double amount;
  final String title;
  final String subtitle;
  final MovementKind kind;
  final TransactionEntity? transaction;
  final TransferEntity? transfer;

  bool get isTransfer => transfer != null;
}
