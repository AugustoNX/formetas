import 'package:uuid/uuid.dart';

import '../../core/utils/asset_calculator.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/patrimony_calculator.dart';
import '../entities/asset_entity.dart';
import '../entities/asset_trade_entity.dart';
import '../entities/transaction_entity.dart';
import '../entities/transfer_entity.dart';
import '../repositories/asset_repository.dart';
import '../repositories/transfer_repository.dart';

class AssetTradeException implements Exception {
  AssetTradeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cuida dos lançamentos da carteira e do dinheiro que eles movem.
///
/// Comprar tira do saldo, vender e receber provento devolvem. O movimento vira
/// uma transferência interna — o mesmo mecanismo já usado por caixinhas — para
/// que nada apareça como receita ou despesa do mês.
class AssetTradeService {
  AssetTradeService({
    required AssetRepository assetRepository,
    required TransferRepository transferRepository,
  })  : _assetRepository = assetRepository,
        _transferRepository = transferRepository;

  final AssetRepository _assetRepository;
  final TransferRepository _transferRepository;

  Future<void> saveAsset(AssetEntity asset) {
    final ticker = asset.ticker.trim().toUpperCase();
    if (ticker.isEmpty) {
      throw AssetTradeException('Informe o código do ativo');
    }
    return _assetRepository.saveAsset(asset.copyWith(ticker: ticker));
  }

  Future<void> updatePrice(AssetEntity asset, double price) {
    if (price <= 0) {
      throw AssetTradeException('Informe um preço maior que zero');
    }
    return _assetRepository.saveAsset(
      asset.copyWith(currentPrice: price, priceUpdatedAt: DateTime.now()),
    );
  }

  /// Registra o lançamento e move o dinheiro correspondente.
  ///
  /// [position] é a posição atual do ativo, usada para impedir a venda de mais
  /// do que se tem. [transactions] e [transfers] servem para conferir o saldo
  /// disponível antes de uma compra.
  Future<void> registerTrade({
    required AssetEntity asset,
    required AssetTradeType type,
    required DateTime date,
    required AssetPosition? position,
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    double quantity = 0,
    double unitPrice = 0,
    double fees = 0,
    double dividendAmount = 0,
    String? note,
    bool isNewAsset = false,
  }) async {
    final amount = AssetTradeEntity.totalFor(
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      fees: fees,
      dividendAmount: dividendAmount,
    );

    _validate(
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      amount: amount,
      asset: asset,
      position: position,
      transactions: transactions,
      transfers: transfers,
    );

    if (isNewAsset) await saveAsset(asset);

    final transferId = const Uuid().v4();
    await _transferRepository.createTransfer(
      TransferEntity(
        id: transferId,
        userId: asset.userId,
        amount: amount,
        fromType: type == AssetTradeType.buy
            ? WalletType.balance
            : WalletType.investment,
        toType: type == AssetTradeType.buy
            ? WalletType.investment
            : WalletType.balance,
        fromId: type == AssetTradeType.buy ? null : asset.id,
        toId: type == AssetTradeType.buy ? asset.id : null,
        description: _describe(type, asset, quantity),
        date: date,
        createdAt: DateTime.now(),
      ),
    );

    await _assetRepository.createTrade(
      AssetTradeEntity(
        id: const Uuid().v4(),
        assetId: asset.id,
        userId: asset.userId,
        type: type,
        quantity: quantity,
        unitPrice: unitPrice,
        fees: fees,
        amount: amount,
        date: date,
        note: note,
        transferId: transferId,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Apaga o lançamento e desfaz a transferência que ele criou.
  Future<void> removeTrade(AssetTradeEntity trade) async {
    await _assetRepository.deleteTrade(
      trade.userId,
      trade.assetId,
      trade.id,
    );
    final transferId = trade.transferId;
    if (transferId != null) {
      await _transferRepository.deleteTransfer(trade.userId, transferId);
    }
  }

  /// Remove o ativo junto com todo o rastro financeiro dele.
  Future<void> deleteAsset(AssetWithTrades item) async {
    for (final trade in item.trades) {
      final transferId = trade.transferId;
      if (transferId != null) {
        await _transferRepository.deleteTransfer(item.asset.userId, transferId);
      }
    }
    await _assetRepository.deleteAsset(item.asset.userId, item.asset.id);
  }

  void _validate({
    required AssetTradeType type,
    required double quantity,
    required double unitPrice,
    required double amount,
    required AssetEntity asset,
    required AssetPosition? position,
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
  }) {
    if (type == AssetTradeType.dividend) {
      if (amount <= 0) {
        throw AssetTradeException('Informe o valor recebido');
      }
      return;
    }

    if (quantity <= 0) {
      throw AssetTradeException('Informe uma quantidade maior que zero');
    }
    if (unitPrice <= 0) {
      throw AssetTradeException('Informe o preço por ${_unit(asset)}');
    }

    if (type == AssetTradeType.sell) {
      final available = position?.quantity ?? 0;
      if (quantity > available) {
        throw AssetTradeException(
          available <= 0
              ? 'Você não tem ${asset.ticker} na carteira'
              : 'Você tem ${_quantityLabel(available)} de ${asset.ticker}',
        );
      }
      return;
    }

    final balance = PatrimonyCalculator.balance(
      transactions: transactions,
      transfers: transfers,
    );
    if (CurrencyFormatter.exceeds(amount, balance)) {
      throw AssetTradeException(
        'Saldo insuficiente. Disponível: ${CurrencyFormatter.format(balance)}',
      );
    }
  }

  String _describe(AssetTradeType type, AssetEntity asset, double quantity) {
    return switch (type) {
      AssetTradeType.buy =>
        'Compra de ${_quantityLabel(quantity)} ${asset.ticker}',
      AssetTradeType.sell =>
        'Venda de ${_quantityLabel(quantity)} ${asset.ticker}',
      AssetTradeType.dividend => 'Proventos de ${asset.ticker}',
    };
  }

  String _unit(AssetEntity asset) => AssetClassLabels.unitLabel(asset.assetClass);

  static String _quantityLabel(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.round().toString();
    }
    return quantity
        .toStringAsFixed(8)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }
}
