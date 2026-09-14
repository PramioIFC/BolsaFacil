import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../models/portfolio_item.dart';
import '../models/user_account.dart';
import 'database_factory.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String databaseName = 'bolsa_facil.db'})
      : _factory = factory ?? createDatabaseFactory(),
        _databaseName = databaseName;

  final DatabaseFactory _factory;
  final String _databaseName;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _factory.openDatabase(
      _databaseName,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
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
            CREATE TABLE session (
              slot INTEGER PRIMARY KEY CHECK (slot = 1),
              user_id INTEGER NOT NULL,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
          ''');
        },
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    return _database!;
  }

  Future<UserAccount?> restoreSession() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT users.id, users.name, users.email
      FROM session
      JOIN users ON users.id = session.user_id
      WHERE session.slot = 1
      LIMIT 1
    ''');
    return rows.isEmpty ? null : UserAccount.fromMap(rows.first);
  }

  Future<UserAccount> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await database;
    final normalizedEmail = email.trim().toLowerCase();
    final existing = await db.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const AuthException('Já existe uma conta com este e-mail.');
    }
    final salt = _createSalt();
    final id = await db.insert('users', {
      'name': name.trim(),
      'email': normalizedEmail,
      'password_hash': _hashPassword(password, salt),
      'password_salt': salt,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _saveSession(db, id);
    return UserAccount(id: id, name: name.trim(), email: normalizedEmail);
  }

  Future<UserAccount> login(String email, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('E-mail ou senha incorretos.');
    }
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
    await db.delete('session');
  }

  Future<List<PortfolioItem>> positionsFor(int userId) async {
    final db = await database;
    final rows = await db.query(
      'positions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'purchased_at DESC',
    );
    return rows
        .map(
          (row) => PortfolioItem(
            symbol: row['symbol'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            averagePrice: (row['average_price'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<void> savePosition(int userId, PortfolioItem item) async {
    final db = await database;
    await db.insert(
      'positions',
      {
        'user_id': userId,
        'symbol': item.symbol,
        'quantity': item.quantity,
        'average_price': item.averagePrice,
        'purchased_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removePosition(int userId, String symbol) async {
    final db = await database;
    await db.delete(
      'positions',
      where: 'user_id = ? AND symbol = ?',
      whereArgs: [userId, symbol],
    );
  }

  Future<Set<String>> favoritesFor(int userId) async {
    final db = await database;
    final rows = await db.query(
      'favorites',
      columns: ['symbol'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((row) => row['symbol'] as String).toSet();
  }

  Future<void> setFavorite(int userId, String symbol, bool favorite) async {
    final db = await database;
    if (favorite) {
      await db.insert(
        'favorites',
        {'user_id': userId, 'symbol': symbol},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete(
        'favorites',
        where: 'user_id = ? AND symbol = ?',
        whereArgs: [userId, symbol],
      );
    }
  }

  Future<void> _saveSession(Database db, int userId) async {
    await db.insert(
      'session',
      {'slot': 1, 'user_id': userId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _createSalt() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
  }

  String _hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}
