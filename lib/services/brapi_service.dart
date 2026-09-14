import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  static const _baseUrl = 'https://brapi.dev/api';
  String get _token => dotenv.env['BRAPI_TOKEN']?.trim() ?? '';

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<List<Stock>> getQuotes(
    List<String> symbols, {
    bool historical = false,
  }) async {
    if (symbols.isEmpty) return [];
    final joined = symbols.map((e) => e.toUpperCase()).join(',');
    final query = <String, String>{
      if (historical) 'range': '3mo',
      if (historical) 'interval': '1d',
      if (_token.isNotEmpty) 'token': _token,
    };
    final uri = Uri.parse('$_baseUrl/quote/$joined').replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw BrapiException(_messageFor(response.statusCode));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Stock.fromJson)
        .toList();
  }

  Future<Stock> getQuote(String symbol) async {
    final stocks = await getQuotes([symbol], historical: true);
    if (stocks.isEmpty) throw const BrapiException('Ação não encontrada.');
    return stocks.first;
  }

  String _messageFor(int code) {
    if (code == 401 || code == 403) {
      return 'A API solicitou um token válido. Configure BRAPI_TOKEN.';
    }
    if (code == 404) return 'Ação não encontrada.';
    if (code == 429) return 'Limite de consultas atingido. Tente novamente em instantes.';
    return 'Não foi possível consultar a bolsa (erro $code).';
  }
}
