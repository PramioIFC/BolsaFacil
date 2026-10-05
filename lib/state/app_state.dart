import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/portfolio_item.dart';
import '../models/stock.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/brapi_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.brapiService, this.api);

  final BrapiService brapiService;
  final ApiService api;
  AppDatabase get db => AppDatabase.instance;

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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final savedToken = prefs.getString('auth_token');
        if (savedToken != null) {
          api.setToken(savedToken);
          currentUser = await api.me();
        }
        if (currentUser == null) {
          api.setToken(null);
          await prefs.remove('auth_token');
        }
      } else {
        currentUser = await db.getSession();
      }

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
    if (kIsWeb) {
      final result = await api.register(name: name, email: email, password: password);
      currentUser = result.user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', result.token);
    } else {
      currentUser = await db.register(name: name, email: email, password: password);
    }
    await _loadUserData();
    await refresh();
  }

  Future<void> login(String email, String password) async {
    if (kIsWeb) {
      final result = await api.login(email: email, password: password);
      currentUser = result.user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', result.token);
    } else {
      currentUser = await db.login(email, password);
    }
    await _loadUserData();
    await refresh();
  }

  Future<void> logout() async {
    if (kIsWeb) {
      await api.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } else {
      await db.logout();
    }
    currentUser = null;
    favorites = {};
    portfolio = [];
    stocks = [];
    error = null;
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;
    if (kIsWeb) {
      favorites = await api.getFavorites();
      portfolio = await api.getPositions();
    } else {
      favorites = await db.getFavorites(currentUser!.id);
      portfolio = await db.getPositions(currentUser!.id);
    }
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final symbols = {...defaultSymbols, ...favorites, ...portfolio.map((e) => e.symbol)};
      stocks = await brapiService.getQuotes(symbols.toList());
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
    final stock = await brapiService.getQuote(normalized);
    stocks = [...stocks, stock];
    notifyListeners();
    return stock;
  }

  Future<void> toggleFavorite(String symbol) async {
    if (currentUser == null) return;
    final isFav = favorites.contains(symbol);
    if (isFav) {
      favorites.remove(symbol);
    } else {
      favorites.add(symbol);
    }
    notifyListeners();
    if (kIsWeb) {
      await api.setFavorite(symbol, !isFav);
    } else {
      await db.toggleFavorite(currentUser!.id, symbol, !isFav);
    }
  }

  Future<void> savePosition(PortfolioItem item) async {
    if (currentUser == null) return;
    portfolio = [...portfolio.where((e) => e.symbol != item.symbol), item];
    if (kIsWeb) {
      await api.savePosition(item);
    } else {
      await db.savePosition(currentUser!.id, item);
    }
    notifyListeners();
    if (!stocks.any((stock) => stock.symbol == item.symbol)) await refresh();
  }

  Future<void> buy(String symbol, double quantity, double price) async {
    final normalized = symbol.trim().toUpperCase();
    final existing = portfolio.where((item) => item.symbol == normalized);
    if (existing.isEmpty) {
      await savePosition(
        PortfolioItem(symbol: normalized, quantity: quantity, averagePrice: price),
      );
      return;
    }

    final current = existing.first;
    final totalQuantity = current.quantity + quantity;
    final averagePrice = (current.invested + (quantity * price)) / totalQuantity;
    await savePosition(
      PortfolioItem(symbol: normalized, quantity: totalQuantity, averagePrice: averagePrice),
    );
  }

  Future<void> removePosition(String symbol) async {
    if (currentUser == null) return;
    portfolio = portfolio.where((e) => e.symbol != symbol).toList();
    if (kIsWeb) {
      await api.removePosition(symbol);
    } else {
      await db.removePosition(currentUser!.id, symbol);
    }
    notifyListeners();
  }

  Stock? stockFor(String symbol) {
    for (final stock in stocks) {
      if (stock.symbol == symbol) return stock;
    }
    return null;
  }
}
