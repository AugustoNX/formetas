import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/asset_entity.dart';
import '../../domain/entities/market_quote.dart';
import '../../domain/repositories/market_quote_repository.dart';

/// Catálogo público da brapi. Sem token, a busca de tickers já devolve nome
/// e último preço — o suficiente para o autocomplete do lançamento.
///
/// Cotações pontuais (`/api/quote/{ticker}`) pedem cadastro; a busca não.
class BrapiMarketDataSource {
  BrapiMarketDataSource({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'brapi.dev';
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;

  Future<List<MarketQuote>> search(
    String query, {
    AssetClass? assetClass,
  }) async {
    final term = query.trim();
    if (term.length < 2) return const [];

    final filter =
        assetClass == null ? null : MarketQuoteMapper.catalogFilter(assetClass);
    final type = filter?.type;
    final subType = filter?.subType;

    final uri = Uri.https(_host, '/api/v2/tickers', {
      'search': term,
      'limit': '8',
      'type': ?type,
      'subType': ?subType,
    });

    final json = await _get(uri);
    final results = json['results'];
    if (results is! List) return const [];

    return [
      for (final item in results)
        if (item is Map) _parse(Map<String, dynamic>.from(item)),
    ];
  }

  Future<MarketQuote?> lookup(String ticker) async {
    final symbol = ticker.trim().toUpperCase();
    if (symbol.isEmpty) return null;

    final matches = await search(symbol);
    for (final quote in matches) {
      if (quote.ticker == symbol) return quote;
    }
    return matches.where((q) => q.ticker.startsWith(symbol)).firstOrNull;
  }

  MarketQuote _parse(Map<String, dynamic> map) {
    final ticker = (map['symbol'] as String? ?? '').toUpperCase();
    final quote = map['quote'] is Map
        ? Map<String, dynamic>.from(map['quote'] as Map)
        : const <String, dynamic>{};

    return MarketQuote(
      ticker: ticker,
      name: MarketQuoteMapper.displayName(
        ticker,
        map['name'] as String? ?? '',
        map['longName'] as String?,
      ),
      assetClass: MarketQuoteMapper.assetClass(
        map['assetType'] as String?,
        map['subType'] as String?,
      ),
      price: (quote['lastPrice'] as num?)?.toDouble(),
      changePercent: (quote['changePercent'] as num?)?.toDouble(),
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 429) {
      throw MarketQuoteException(
        'Muitas buscas em pouco tempo. Espere um instante e tente de novo.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MarketQuoteException('Não foi possível consultar o mercado agora.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw MarketQuoteException('Resposta inesperada da cotação.');
    }
    if (decoded['error'] == true) {
      throw MarketQuoteException(
        decoded['message'] as String? ?? 'Busca indisponível no momento.',
      );
    }
    return decoded;
  }
}
