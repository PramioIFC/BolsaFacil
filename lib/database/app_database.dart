import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/portfolio_item.dart';
import '../models/user_account.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  AppDatabase._init();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bolsa_facil.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE positions (
        user_id INTEGER NOT NULL,
        symbol TEXT NOT NULL,
        quantity REAL NOT NULL,
        average_price REAL NOT NULL,
        purchased_at TEXT NOT NULL,
        PRIMARY KEY (user_id, symbol),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE favorites (
        user_id INTEGER NOT NULL,
        symbol TEXT NOT NULL,
        PRIMARY KEY (user_id, symbol),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  String _createSalt() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
  }

  String _hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<void> _saveSession(Database db, int userId) async {
    await db.insert(
      'sessions',
      {'id': 1, 'user_id': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserAccount?> getSession() async {
    final db = await database;
    final rows = await db.query('sessions', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    final userId = rows.first['user_id'] as int;
    final userRows = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (userRows.isEmpty) return null;
    return UserAccount.fromMap(userRows.first);
  }

  Future<UserAccount> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await database;
    final normalizedEmail = email.trim().toLowerCase();
    final salt = _createSalt();
    final hash = _hashPassword(password, salt);
    final existing = await db.query('users', where: 'email = ?', whereArgs: [normalizedEmail], limit: 1);
    int id;
    if (existing.isNotEmpty) {
      id = existing.first['id'] as int;
      await db.update('users', {'name': name.trim(), 'password_hash': hash, 'password_salt': salt}, where: 'id = ?', whereArgs: [id]);
    } else {
      id = await db.insert('users', {
        'name': name.trim(),
        'email': normalizedEmail,
        'password_hash': hash,
        'password_salt': salt,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    await _saveSession(db, id);
    return UserAccount(id: id, name: name.trim(), email: normalizedEmail);
  }

  Future<UserAccount> login(String email, String password) async {
    final db = await database;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()], limit: 1);
    if (rows.isEmpty) throw const AuthException('E-mail ou senha incorretos.');
    final row = rows.first;
    final salt = row['password_salt'] as String;
    if (_hashPassword(password, salt) != row['password_hash']) {
      throw const AuthException('E-mail ou senha incorretos.');
    }
    final user = UserAccount.fromMap(row);
    await _saveSession(db, user.id);
    return user;
  }

  Future<void> logout() async {
    final db = await database;
    await db.delete('sessions');
  }

  Future<Set<String>> getFavorites(int userId) async {
    final db = await database;
    final rows = await db.query('favorites', columns: ['symbol'], where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => r['symbol'] as String).toSet();
  }

  Future<void> toggleFavorite(int userId, String symbol, bool isFavorite) async {
    final db = await database;
    if (isFavorite) {
      await db.insert('favorites', {'user_id': userId, 'symbol': symbol}, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('favorites', where: 'user_id = ? AND symbol = ?', whereArgs: [userId, symbol]);
    }
  }

  Future<List<PortfolioItem>> getPositions(int userId) async {
    final db = await database;
    final rows = await db.query('positions', where: 'user_id = ?', whereArgs: [userId], orderBy: 'purchased_at DESC');
    return rows.map((r) => PortfolioItem(
          symbol: r['symbol'] as String,
          quantity: (r['quantity'] as num).toDouble(),
          averagePrice: (r['average_price'] as num).toDouble(),
        )).toList();
  }

  Future<void> savePosition(int userId, PortfolioItem item) async {
    final db = await database;
    await db.insert('positions', {
      'user_id': userId,
      'symbol': item.symbol,
      'quantity': item.quantity,
      'average_price': item.averagePrice,
      'purchased_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removePosition(int userId, String symbol) async {
    final db = await database;
    await db.delete('positions', where: 'user_id = ? AND symbol = ?', whereArgs: [userId, symbol]);
  }
}
