import '../entities/asset_trade_entity.dart';
import '../entities/investment_entity.dart';
import '../entities/movement_entry.dart';
import '../entities/reserve_movement_entity.dart';
import '../entities/transaction_entity.dart';
import '../entities/transfer_entity.dart';

abstract final class MovementListBuilder {
  static List<MovementEntry> build({
    required List<TransactionEntity> transactions,
    required List<TransferEntity> transfers,
    List<ReserveWithMovements> reserves = const [],
    List<InvestmentEntity> investments = const [],
    List<AssetWithTrades> assets = const [],
  }) {
    final reserveNames = {
      for (final item in reserves) item.reserve.id: item.reserve.name,
    };
    // Compra e venda de ativos também viajam como transferência, então o
    // extrato precisa saber traduzir o id do ativo para o ticker.
    final investmentNames = {
      for (final item in investments) item.id: item.name,
      for (final item in assets) item.asset.id: item.asset.ticker,
    };

    final items = <MovementEntry>[
      for (final tx in transactions)
        MovementEntry(
          id: tx.id,
          date: tx.date,
          amount: tx.value,
          title: tx.description.isNotEmpty ? tx.description : tx.category,
          subtitle: tx.category,
          kind: switch (tx.type) {
            TransactionType.income => MovementKind.income,
            TransactionType.expense => MovementKind.expense,
            TransactionType.investment => MovementKind.investment,
          },
          transaction: tx,
        ),
      for (final transfer in transfers)
        MovementEntry(
          id: transfer.id,
          date: transfer.date,
          amount: transfer.amount,
          title: _routeLabel(
            transfer,
            reserveNames: reserveNames,
            investmentNames: investmentNames,
          ),
          subtitle: (transfer.description?.trim().isNotEmpty == true)
              ? transfer.description!.trim()
              : 'Transferência interna',
          kind: MovementKind.transfer,
          transfer: transfer,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return items;
  }

  static String _routeLabel(
    TransferEntity transfer, {
    required Map<String, String> reserveNames,
    required Map<String, String> investmentNames,
  }) {
    String name(WalletType type, String? id) => switch (type) {
          WalletType.balance => 'Saldo',
          WalletType.reserve =>
            (id != null ? reserveNames[id] : null) ?? 'Caixinha',
          WalletType.investment =>
            (id != null ? investmentNames[id] : null) ?? 'Investimentos',
        };

    return '${name(transfer.fromType, transfer.fromId)} → ${name(transfer.toType, transfer.toId)}';
  }
}
