import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/portfolio_item.dart';
import '../models/stock.dart';
import '../models/user_account.dart';
import '../services/brapi_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.api, this.database);

  final BrapiService api;
  final AppDatabase database;
  static const defaultSymbols = [
    'PETR4', 'VALE3', 'ITUB4', 'BBDC4', 'ABEV3', 'WEGE3', 'BBAS3', 'MGLU3'
  ];

  List<Stock> stocks = [];
  Set<String> favorites = {};
  List<PortfolioItem> portfolio = [];
  bool loading = false;
  bool initializing = true;
  String? error;
  UserAccount? currentUser;

  bool get isAuthenticated => currentUser != null;

  Future<void> initialize() async {
    try {
      currentUser = await database.restoreSession();
      if (currentUser != null) {
        await _loadUserData();
        await refresh();
      }
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    currentUser = await database.register(
      name: name,
      email: email,
      password: password,
    );
    await _loadUserData();
    await refresh();
  }

  Future<void> login(String email, String password) async {
    currentUser = await database.login(email, password);
    await _loadUserData();
    await refresh();
  }

  Future<void> logout() async {
    await database.logout();
    currentUser = null;
    favorites = {};
    portfolio = [];
    stocks = [];
    error = null;
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    final userId = currentUser!.id;
    favorites = await database.favoritesFor(userId);
    portfolio = await database.positionsFor(userId);
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
    if (currentUser == null) return;
    favorites.contains(symbol) ? favorites.remove(symbol) : favorites.add(symbol);
    notifyListeners();
    await database.setFavorite(
      currentUser!.id,
      symbol,
      favorites.contains(symbol),
    );
  }

  Future<void> savePosition(PortfolioItem item) async {
    if (currentUser == null) return;
    portfolio = [...portfolio.where((e) => e.symbol != item.symbol), item];
    await database.savePosition(currentUser!.id, item);
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
    if (currentUser == null) return;
    portfolio = portfolio.where((e) => e.symbol != symbol).toList();
    await database.removePosition(currentUser!.id, symbol);
    notifyListeners();
  }

  Stock? stockFor(String symbol) {
    for (final stock in stocks) {
      if (stock.symbol == symbol) return stock;
    }
    return null;
  }

}
