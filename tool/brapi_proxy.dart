import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database _db;

Future<void> initDatabase() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final dbPath = '${Directory.current.path}/.data/bolsa_facil.db';
  await Directory('${Directory.current.path}/.data').create(recursive: true);
  _db = await factory.openDatabase(
    dbPath,
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
          CREATE TABLE sessions (
            token TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
          )
        ''');
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

String _createSalt() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
}

String _hashPassword(String password, String salt) =>
    sha256.convert(utf8.encode('$salt:$password')).toString();

String _createToken() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
}

void _jsonResponse(HttpRequest request, int statusCode, Object body) {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  request.response.close();
}

Future<Map<String, dynamic>?> _readJson(HttpRequest request) async {
  try {
    final body = await utf8.decoder.bind(request).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<int?> _authenticate(HttpRequest request) async {
  final auth = request.headers.value('authorization');
  if (auth == null || !auth.startsWith('Bearer ')) return null;
  final token = auth.substring(7);
  final rows = await _db.query('sessions', columns: ['user_id'], where: 'token = ?', whereArgs: [token], limit: 1);
  if (rows.isEmpty) return null;
  return rows.first['user_id'] as int;
}

Future<void> handleRegister(HttpRequest request) async {
  final json = await _readJson(request);
  if (json == null) return _jsonResponse(request, 400, {'error': 'JSON inválido.'});
  final name = (json['name'] as String?)?.trim() ?? '';
  final email = (json['email'] as String?)?.trim().toLowerCase() ?? '';
  final password = (json['password'] as String?) ?? '';

  if (name.length < 2 || !email.contains('@') || password.length < 6) return _jsonResponse(request, 400, {'error': 'Dados inválidos.'});

  final salt = _createSalt();
  final hash = _hashPassword(password, salt);
  final existing = await _db.query('users', columns: ['id'], where: 'email = ?', whereArgs: [email], limit: 1);
  
  int id;
  if (existing.isNotEmpty) {
    id = existing.first['id'] as int;
    await _db.update('users', {'name': name, 'password_hash': hash, 'password_salt': salt}, where: 'id = ?', whereArgs: [id]);
  } else {
    id = await _db.insert('users', {
      'name': name, 'email': email, 'password_hash': hash, 'password_salt': salt, 'created_at': DateTime.now().toIso8601String(),
    });
  }

  final token = _createToken();
  await _db.insert('sessions', {'token': token, 'user_id': id, 'created_at': DateTime.now().toIso8601String()});
  _jsonResponse(request, 201, {'token': token, 'user': {'id': id, 'name': name, 'email': email}});
}

Future<void> handleLogin(HttpRequest request) async {
  final json = await _readJson(request);
  if (json == null) return _jsonResponse(request, 400, {'error': 'JSON inválido.'});
  final email = (json['email'] as String?)?.trim().toLowerCase() ?? '';
  final password = (json['password'] as String?) ?? '';

  final rows = await _db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
  if (rows.isEmpty) return _jsonResponse(request, 401, {'error': 'E-mail ou senha incorretos.'});

  final row = rows.first;
  final salt = row['password_salt'] as String;
  if (_hashPassword(password, salt) != row['password_hash']) return _jsonResponse(request, 401, {'error': 'E-mail ou senha incorretos.'});

  final token = _createToken();
  await _db.insert('sessions', {'token': token, 'user_id': row['id'], 'created_at': DateTime.now().toIso8601String()});
  _jsonResponse(request, 200, {'token': token, 'user': {'id': row['id'], 'name': row['name'], 'email': row['email']}});
}

Future<void> handleLogout(HttpRequest request) async {
  final auth = request.headers.value('authorization');
  if (auth != null && auth.startsWith('Bearer ')) {
    await _db.delete('sessions', where: 'token = ?', whereArgs: [auth.substring(7)]);
  }
  _jsonResponse(request, 200, {'ok': true});
}

Future<void> handleMe(HttpRequest request) async {
  final userId = await _authenticate(request);
  if (userId == null) return _jsonResponse(request, 401, {'error': 'Não autenticado.'});
  final rows = await _db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
  if (rows.isEmpty) return _jsonResponse(request, 401, {'error': 'Usuário não encontrado.'});
  final u = rows.first;
  _jsonResponse(request, 200, {'user': {'id': u['id'], 'name': u['name'], 'email': u['email']}});
}

Future<void> handleGetPositions(HttpRequest request) async {
  final userId = await _authenticate(request);
  if (userId == null) return _jsonResponse(request, 401, {'error': 'Não autenticado.'});
  final rows = await _db.query('positions', where: 'user_id = ?', whereArgs: [userId], orderBy: 'purchased_at DESC');
  _jsonResponse(request, 200, {'positions': rows.map((r) => {'symbol': r['symbol'], 'quantity': r['quantity'], 'averagePrice': r['average_price']}).toList()});
}

Future<void> handleSavePosition(HttpRequest request) async {
  final userId = await _authenticate(request);
  if (userId == null) return _jsonResponse(request, 401, {'error': 'Não autenticado.'});
  final json = await _readJson(request);
  if (json == null) return _jsonResponse(request, 400, {'error': 'JSON inválido.'});
  await _db.insert('positions', {'user_id': userId, 'symbol': json['symbol'], 'quantity': json['quantity'], 'average_price': json['averagePrice'], 'purchased_at': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
  _jsonResponse(request, 200, {'ok': true});
}

Future<void> handleDeletePosition(HttpRequest request) async {
  final userId = await _authenticate(request);
  if (userId == null) return _jsonResponse(request, 401, {'error': 'Não autenticado.'});
  final symbol = request.uri.queryParameters['symbol'];
  if (symbol == null) return _jsonResponse(request, 400, {'error': 'Símbolo obrigatório.'});
  await _db.delete('positions', where: 'user_id = ? AND symbol = ?', whereArgs: [userId, symbol]);
  _jsonResponse(request, 200, {'ok': true});
}

Future<void> handleGetFavorites(HttpRequest request) async {
  final userId = await _authenticate(request);
  if (userId == null) return _jsonResponse(request, 401, {'error': 'Não autenticado.'});
  final rows = await _db.query('favorites', columns: ['symbol'], where: 'user_id = ?', whereArgs: [userId]);
  _jsonResponse(request, 200, {'favorites': rows.map((r) => r['symbol']).toList()});
}

Future<void> handleSetFavorite(HttpRequest request) async {
  final userId = await _authenticate(request);
  if (userId == null) return _jsonResponse(request, 401, {'error': 'Não autenticado.'});
  final json = await _readJson(request);
  if (json == null) return _jsonResponse(request, 400, {'error': 'JSON inválido.'});
  final symbol = json['symbol'] as String?;
  final favorite = json['favorite'] as bool? ?? true;
  if (symbol == null) return _jsonResponse(request, 400, {'error': 'Símbolo obrigatório.'});
  if (favorite) {
    await _db.insert('favorites', {'user_id': userId, 'symbol': symbol}, conflictAlgorithm: ConflictAlgorithm.ignore);
  } else {
    await _db.delete('favorites', where: 'user_id = ? AND symbol = ?', whereArgs: [userId, symbol]);
  }
  _jsonResponse(request, 200, {'ok': true});
}

Future<void> _proxyBrapi(HttpRequest request, String token) async {
  final target = Uri.https('brapi.dev', request.uri.path, request.uri.queryParameters);
  final client = HttpClient();
  try {
    final upstream = await client.getUrl(target);
    upstream.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    upstream.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await upstream.close();
    request.response.statusCode = response.statusCode;
    request.response.headers.contentType = ContentType.json;
    await response.pipe(request.response);
  } catch (error) {
    _jsonResponse(request, 502, {'error': 'Falha ao consultar a brapi.'});
  } finally {
    client.close();
  }
}

void _cors(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

Future<void> main() async {
  final file = File('.env');
  String token = '';
  if (await file.exists()) {
    for (final line in await file.readAsLines()) {
      if (line.trim().startsWith('BRAPI_TOKEN=')) token = line.trim().substring(12).trim();
    }
  }
  if (token.isEmpty) {
    stderr.writeln('BRAPI_TOKEN não foi preenchido no arquivo .env.');
    exitCode = 1;
    return;
  }

  await initDatabase();

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  stdout.writeln('Servidor Bolsa Fácil ativo em http://localhost:8080');
  await for (final request in server) {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      continue;
    }
    final path = request.uri.path;
    final method = request.method;
    try {
      if (path == '/auth/register' && method == 'POST') await handleRegister(request);
      else if (path == '/auth/login' && method == 'POST') await handleLogin(request);
      else if (path == '/auth/logout' && method == 'POST') await handleLogout(request);
      else if (path == '/auth/me' && method == 'GET') await handleMe(request);
      else if (path == '/data/positions' && method == 'GET') await handleGetPositions(request);
      else if (path == '/data/positions' && method == 'POST') await handleSavePosition(request);
      else if (path == '/data/positions' && method == 'DELETE') await handleDeletePosition(request);
      else if (path == '/data/favorites' && method == 'GET') await handleGetFavorites(request);
      else if (path == '/data/favorites' && method == 'POST') await handleSetFavorite(request);
      else if (path.startsWith('/api/')) await _proxyBrapi(request, token);
      else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      _jsonResponse(request, 500, {'error': 'Erro interno.'});
    }
  }
}
