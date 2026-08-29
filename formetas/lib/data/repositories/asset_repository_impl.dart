import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/asset_trade_entity.dart';
import '../../domain/repositories/asset_repository.dart';
import '../datasources/asset_remote_datasource.dart';

class AssetRepositoryImpl implements AssetRepository {
  AssetRepositoryImpl(this._dataSource);

  final AssetRemoteDataSource _dataSource;

  @override
  Stream<List<AssetWithTrades>> watchAssets(String userId) =>
      _dataSource.watchAssets(userId);

  @override
  Future<List<AssetWithTrades>> getAssets(String userId) =>
      _dataSource.getAssets(userId);

  @override
  Future<void> saveAsset(AssetEntity asset) => _dataSource.saveAsset(asset);

  @override
  Future<void> deleteAsset(String userId, String assetId) =>
      _dataSource.deleteAsset(userId, assetId);

  @override
  Future<void> createTrade(AssetTradeEntity trade) =>
      _dataSource.createTrade(trade);

  @override
  Future<void> deleteTrade(String userId, String assetId, String tradeId) =>
      _dataSource.deleteTrade(userId, assetId, tradeId);
}
