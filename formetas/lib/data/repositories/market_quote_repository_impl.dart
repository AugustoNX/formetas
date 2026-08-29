import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/market_quote.dart';
import '../../domain/repositories/market_quote_repository.dart';
import '../datasources/brapi_market_datasource.dart';

class MarketQuoteRepositoryImpl implements MarketQuoteRepository {
  MarketQuoteRepositoryImpl(this._dataSource);

  final BrapiMarketDataSource _dataSource;

  @override
  Future<List<MarketQuote>> search(String query, {AssetClass? assetClass}) =>
      _dataSource.search(query, assetClass: assetClass);

  @override
  Future<MarketQuote?> lookup(String ticker) => _dataSource.lookup(ticker);
}
