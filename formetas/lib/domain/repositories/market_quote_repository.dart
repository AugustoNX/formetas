import '../entities/asset_entity.dart';
import '../entities/market_quote.dart';

class MarketQuoteException implements Exception {
  MarketQuoteException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MarketQuoteRepository {
  Future<List<MarketQuote>> search(String query, {AssetClass? assetClass});

  Future<MarketQuote?> lookup(String ticker);
}
