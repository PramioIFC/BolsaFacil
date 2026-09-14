import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/portfolio_item.dart';
import '../models/stock.dart';
import '../services/brapi_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  final BrapiService api;
  static const defaultSymbols = [
    'PETR4', 'VALE3', 'ITUB4', 'BBDC4', 'ABEV3', 'WEGE3', 'BBAS3', 'MGLU3'
  ];

  List<Stock> stocks = [];
  Set<String> favorites = {};
  List<PortfolioItem> portfolio = [];
  bool loading = false;
  String? error;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = (prefs.getStringList('favorites') ?? []).toSet();
    final saved = prefs.getString('portfolio');
    if (saved != null) {
      portfolio = (jsonDecode(saved) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(PortfolioItem.fromJson)
          .toList();
    }
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final symbols = {...defaultSymbols, ...favorites, ...portfolio.map((e) => e.symbol)};
      stocks = await api.getQuotes(symbols.toList());
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Stock?> search(String symbol) async {
    final normalized = symbol.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final found = stocks.where((stock) => stock.symbol == normalized);
    if (found.isNotEmpty) return found.first;
    final stock = await api.getQuote(normalized);
    stocks = [...stocks, stock];
    notifyListeners();
    return stock;
  }

  Future<void> toggleFavorite(String symbol) async {
    favorites.contains(symbol) ? favorites.remove(symbol) : favorites.add(symbol);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favorites.toList());
  }

  Future<void> savePosition(PortfolioItem item) async {
    portfolio = [...portfolio.where((e) => e.symbol != item.symbol), item];
    await _savePortfolio();
    notifyListeners();
    if (!stocks.any((stock) => stock.symbol == item.symbol)) await refresh();
  }

  Future<void> buy(String symbol, double quantity, double price) async {
    final normalized = symbol.trim().toUpperCase();
    final existing = portfolio.where((item) => item.symbol == normalized);
    if (existing.isEmpty) {
      await savePosition(
        PortfolioItem(
          symbol: normalized,
          quantity: quantity,
          averagePrice: price,
        ),
      );
      return;
    }

    final current = existing.first;
    final totalQuantity = current.quantity + quantity;
    final averagePrice =
        (current.invested + (quantity * price)) / totalQuantity;
    await savePosition(
      PortfolioItem(
        symbol: normalized,
        quantity: totalQuantity,
        averagePrice: averagePrice,
      ),
    );
  }

  Future<void> removePosition(String symbol) async {
    portfolio = portfolio.where((e) => e.symbol != symbol).toList();
    await _savePortfolio();
    notifyListeners();
  }

  Stock? stockFor(String symbol) {
    for (final stock in stocks) {
      if (stock.symbol == symbol) return stock;
    }
    return null;
  }

  Future<void> _savePortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('portfolio', jsonEncode(portfolio.map((e) => e.toJson()).toList()));
  }
}
