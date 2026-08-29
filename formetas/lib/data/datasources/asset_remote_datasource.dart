import 'package:firebase_database/firebase_database.dart';

import '../../core/config/rtdb_helper.dart';
import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/asset_trade_entity.dart';
import '../models/asset_model.dart';
import '../models/asset_trade_model.dart';

class AssetRemoteDataSource {
  AssetRemoteDataSource({FirebaseDatabase? database})
      : _database = database ?? RtdbHelper.database;

  final FirebaseDatabase _database;

  DatabaseReference _ref(String userId) => _database.ref('users/$userId/ativos');

  DatabaseReference _tradesRef(String userId, String assetId) =>
      _ref(userId).child(assetId).child('lancamentos');

  Stream<List<AssetWithTrades>> watchAssets(String userId) {
    return _ref(userId).onValue.map((event) {
      final list = RtdbHelper.parseChildren(event.snapshot.value, _parse);
      list.sort((a, b) => a.asset.ticker.compareTo(b.asset.ticker));
      return list;
    });
  }

  Future<List<AssetWithTrades>> getAssets(String userId) async {
    final snapshot = await _ref(userId).get();
    final list = RtdbHelper.parseChildren(snapshot.value, _parse);
    list.sort((a, b) => a.asset.ticker.compareTo(b.asset.ticker));
    return list;
  }

  /// Grava com `update` mesmo ao criar: assim o mesmo método serve para os dois
  /// casos sem risco de um salvamento apagar os lançamentos já existentes.
  Future<void> saveAsset(AssetEntity asset) async {
    final data = AssetModel.fromEntity(asset).toMap();
    await _ref(asset.userId).child(asset.id).update(data);
  }

  Future<void> deleteAsset(String userId, String assetId) async {
    await _ref(userId).child(assetId).remove();
  }

  Future<void> createTrade(AssetTradeEntity trade) async {
    final data = AssetTradeModel.fromEntity(trade).toMap();
    await _tradesRef(trade.userId, trade.assetId).child(trade.id).set(data);
  }

  Future<void> deleteTrade(String userId, String assetId, String tradeId) async {
    await _tradesRef(userId, assetId).child(tradeId).remove();
  }

  AssetWithTrades _parse(Map<String, dynamic> map, String id) {
    final data = Map<String, dynamic>.from(map);
    final rawTrades = data.remove('lancamentos');
    final asset = AssetModel.fromMap(data, id);

    final trades = <AssetTradeEntity>[];
    if (rawTrades is Map) {
      rawTrades.forEach((key, value) {
        if (value is Map) {
          trades.add(
            AssetTradeModel.fromMap(
              Map<String, dynamic>.from(value),
              key.toString(),
              assetId: id,
            ),
          );
        }
      });
    }

    trades.sort((a, b) => b.date.compareTo(a.date));
    return AssetWithTrades(asset: asset, trades: trades);
  }
}
