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

  // Tokens nunca devem ser enviados no bundle Web. No navegador, o proxy
  // adiciona a credencial no servidor.
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
    // O plano gratuito da brapi aceita somente um ticker por requisição.
    // Consultas individuais também evitam perder toda a lista caso um ativo
    // específico esteja indisponível.
    final requests = symbols
        .map((symbol) => _getSingleQuote(symbol, historical: historical))
        .toList();
    final results = await Future.wait(requests);
    final stocks = results.whereType<Stock>().toList();
    if (stocks.isEmpty) {
      throw const BrapiException(
        'Não foi possível carregar as cotações. Confira seu token da brapi.',
      );
    }
    return stocks;
  }

  Future<Stock?> _getSingleQuote(
    String symbol, {
    required bool historical,
  }) async {
    final normalized = symbol.trim().toUpperCase();
    final query = <String, String>{
      if (historical) 'range': '3mo',
      if (historical) 'interval': '1d',
      if (_token.isNotEmpty) 'token': _token,
    };
    final uri = Uri.parse(
      '$_baseUrl/quote/$normalized',
    ).replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final stocks = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Stock.fromJson)
        .toList();
    return stocks.isEmpty ? null : stocks.first;
  }

  Future<Stock> getQuote(String symbol) async {
    final stock = await _getSingleQuote(symbol, historical: true);
    if (stock == null) throw const BrapiException('Ação não encontrada.');
    return stock;
  }

}
