import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/portfolio_item.dart';
import '../models/user_account.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : baseUrl = baseUrl ?? (kIsWeb ? 'http://localhost:8080' : 'http://192.168.3.103:8080'),
        _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  String? _token;

  bool get hasToken => _token != null;
  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<({UserAccount user, String token})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(Uri.parse('$baseUrl/auth/register'), headers: _headers, body: jsonEncode({'name': name, 'email': email, 'password': password}));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) throw AuthException(data['error'] as String? ?? 'Erro ao criar conta.');
    final token = data['token'] as String;
    _token = token;
    return (user: UserAccount(id: data['user']['id'], name: data['user']['name'], email: data['user']['email']), token: token);
  }

  Future<({UserAccount user, String token})> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(Uri.parse('$baseUrl/auth/login'), headers: _headers, body: jsonEncode({'email': email, 'password': password}));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw AuthException(data['error'] as String? ?? 'E-mail ou senha incorretos.');
    final token = data['token'] as String;
    _token = token;
    return (user: UserAccount(id: data['user']['id'], name: data['user']['name'], email: data['user']['email']), token: token);
  }

  Future<UserAccount?> me() async {
    if (_token == null) return null;
    try {
      final response = await _client.get(Uri.parse('$baseUrl/auth/me'), headers: _headers);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserAccount(id: data['user']['id'], name: data['user']['name'], email: data['user']['email']);
    } catch (_) { return null; }
  }

  Future<void> logout() async {
    try { await _client.post(Uri.parse('$baseUrl/auth/logout'), headers: _headers); } catch (_) {}
    _token = null;
  }

  Future<List<PortfolioItem>> getPositions() async {
    final response = await _client.get(Uri.parse('$baseUrl/data/positions'), headers: _headers);
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['positions'] as List).map((e) => PortfolioItem.fromJson(e)).toList();
  }

  Future<void> savePosition(PortfolioItem item) async {
    await _client.post(Uri.parse('$baseUrl/data/positions'), headers: _headers, body: jsonEncode(item.toJson()));
  }

  Future<void> removePosition(String symbol) async {
    await _client.delete(Uri.parse('$baseUrl/data/positions?symbol=$symbol'), headers: _headers);
  }

  Future<Set<String>> getFavorites() async {
    final response = await _client.get(Uri.parse('$baseUrl/data/favorites'), headers: _headers);
    if (response.statusCode != 200) return {};
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['favorites'] as List).cast<String>().toSet();
  }

  Future<void> setFavorite(String symbol, bool favorite) async {
    await _client.post(Uri.parse('$baseUrl/data/favorites'), headers: _headers, body: jsonEncode({'symbol': symbol, 'favorite': favorite}));
  }
}
