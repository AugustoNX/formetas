import 'package:equatable/equatable.dart';

import 'asset_entity.dart';

enum AssetTradeType { buy, sell, dividend }

/// Um lançamento na carteira: compra, venda ou provento recebido.
class AssetTradeEntity extends Equatable {
  const AssetTradeEntity({
    required this.id,
    required this.assetId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.quantity = 0,
    this.unitPrice = 0,
    this.fees = 0,
    this.note,
    this.transferId,
  });

  final String id;
  final String assetId;
  final String userId;
  final AssetTradeType type;
  final double quantity;
  final double unitPrice;
  final double fees;

  /// Dinheiro que efetivamente saiu ou entrou no saldo. Guardado explicitamente
  /// para que o lançamento não dependa de recalcular taxas depois.
  final double amount;

  final DateTime date;
  final String? note;

  /// Transferência que moveu o dinheiro. Guardar o vínculo permite desfazer o
  /// lançamento sem deixar o saldo torto.
  final String? transferId;
  final DateTime createdAt;

  bool get movesMoneyOut => type == AssetTradeType.buy;

  /// Valor total do negócio, já com as taxas.
  static double totalFor({
    required AssetTradeType type,
    required double quantity,
    required double unitPrice,
    required double fees,
    double dividendAmount = 0,
  }) {
    return switch (type) {
      AssetTradeType.buy => quantity * unitPrice + fees,
      AssetTradeType.sell => quantity * unitPrice - fees,
      AssetTradeType.dividend => dividendAmount,
    };
  }

  AssetTradeEntity copyWith({
    String? id,
    String? assetId,
    String? userId,
    AssetTradeType? type,
    double? quantity,
    double? unitPrice,
    double? fees,
    double? amount,
    DateTime? date,
    String? note,
    String? transferId,
    DateTime? createdAt,
  }) {
    return AssetTradeEntity(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      fees: fees ?? this.fees,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      transferId: transferId ?? this.transferId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, assetId, type, quantity, unitPrice, date];
}

class AssetWithTrades extends Equatable {
  const AssetWithTrades({required this.asset, required this.trades});

  final AssetEntity asset;
  final List<AssetTradeEntity> trades;

  @override
  List<Object?> get props => [asset, trades];
}

abstract final class AssetTradeLabels {
  static String label(AssetTradeType type) => switch (type) {
        AssetTradeType.buy => 'Compra',
        AssetTradeType.sell => 'Venda',
        AssetTradeType.dividend => 'Provento',
      };
}
