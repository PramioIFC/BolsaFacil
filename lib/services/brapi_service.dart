import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/stock.dart';

class BrapiException implements Exception {
  const BrapiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BrapiService {
  BrapiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _configuredBaseUrl = String.fromEnvironment('BRAPI_BASE_URL');
  static const _nativeToken = String.fromEnvironment('BRAPI_TOKEN');

  String get _baseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : kIsWeb
          ? 'http://localhost:8080/api'
          : 'https://brapi.dev/api';

  String get _token => kIsWeb ? '' : _nativeToken.trim();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<List<Stock>> getQuotes(
    List<String> symbols, {
    bool historical = false,
  }) async {
    if (symbols.isEmpty) return [];

    final List<Stock> stocks = [];
    
    // O plano gratuito permite apenas 1 ticker por requisição.
    // Fazemos as consultas de forma sequencial para não estourar o limite de requisições simultâneas.
    for (final symbol in symbols) {
      try {
        final stock = await _getSingleQuote(symbol, range: historical ? '3mo' : null);
        if (stock != null) {
          stocks.add(stock);
        }
      } catch (_) {
        // Ignora erros individuais para não quebrar a lista toda
      }
    }

    if (stocks.isEmpty) {
      throw BrapiException(
        kIsWeb
            ? 'O proxy da brapi não está acessível. Execute .\\run_web.ps1 para iniciar o app.'
            : 'Não foi possível carregar as cotações. Confira seu token da brapi.',
      );
    }
    return stocks;
  }

  Future<Stock?> _getSingleQuote(
    String symbol, {
    String? range,
    bool fundamentals = false,
  }) async {
    final normalized = symbol.trim().toUpperCase();
    final query = <String, String>{
      if (range != null) 'range': range,
      if (range != null) 'interval': '1d',
      if (_token.isNotEmpty) 'token': _token,
      if (fundamentals) 'modules': 'defaultKeyStatistics,financialData',
      if (fundamentals) 'fundamental': 'true',
      if (fundamentals) 'dividends': 'true',
    };
    final uri = Uri.parse(
      '$_baseUrl/quote/$normalized',
    ).replace(queryParameters: query);
    http.Response response;
    try {
      response = await _client.get(uri, headers: _headers);
    } on http.ClientException {
      return null;
    }
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final stocks = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Stock.fromJson)
        .toList();
    return stocks.isEmpty ? null : stocks.first;
  }

  Future<Stock> getQuote(String symbol, {String range = '3mo'}) async {
    // Try fetching with fundamentals first for the details screen
    Stock? stock = await _getSingleQuote(symbol, range: range, fundamentals: true);
    // If it fails (some free API tickers don't support fundamentals), fallback to basic data
    if (stock == null) {
      stock = await _getSingleQuote(symbol, range: range, fundamentals: false);
    }
    if (stock == null) throw const BrapiException('Ação não encontrada.');
    return stock;
  }

}
