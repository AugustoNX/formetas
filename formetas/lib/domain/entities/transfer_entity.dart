import 'package:equatable/equatable.dart';

enum WalletType { balance, reserve, investment }

class TransferEntity extends Equatable {
  const TransferEntity({
    required this.id,
    required this.userId,
    required this.amount,
    required this.fromType,
    required this.toType,
    required this.date,
    required this.createdAt,
    this.fromId,
    this.toId,
    this.description,
  });

  final String id;
  final String userId;
  final double amount;
  final WalletType fromType;
  final WalletType toType;
  final String? fromId;
  final String? toId;
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  bool get affectsBalance =>
      fromType == WalletType.balance || toType == WalletType.balance;

  @override
  List<Object?> get props => [id, amount, fromType, toType, date];
}

abstract final class WalletTypeLabels {
  static String label(WalletType type) => switch (type) {
        WalletType.balance => 'Saldo',
        WalletType.reserve => 'Caixinha',
        WalletType.investment => 'Investimentos',
      };
}
