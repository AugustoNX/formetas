import '../entities/asset_entity.dart';
import '../entities/asset_trade_entity.dart';

abstract class AssetRepository {
  Stream<List<AssetWithTrades>> watchAssets(String userId);

  Future<List<AssetWithTrades>> getAssets(String userId);

  Future<void> saveAsset(AssetEntity asset);

  Future<void> deleteAsset(String userId, String assetId);

  Future<void> createTrade(AssetTradeEntity trade);

  Future<void> deleteTrade(String userId, String assetId, String tradeId);
}
