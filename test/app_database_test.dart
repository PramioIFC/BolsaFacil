import 'package:bolsa_facil/database/app_database.dart';
import 'package:bolsa_facil/models/portfolio_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('separa posições por usuário e restaura a sessão', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
    final first = await database.register(
      name: 'Ana',
      email: 'ana@example.com',
      password: 'senha123',
    );
    await database.savePosition(
      first.id,
      const PortfolioItem(
        symbol: 'PETR4',
        quantity: 10,
        averagePrice: 35,
      ),
    );
    await database.logout();

    final second = await database.register(
      name: 'Bruno',
      email: 'bruno@example.com',
      password: 'senha456',
    );
    expect(await database.positionsFor(second.id), isEmpty);

    final loggedUser = await database.login('ana@example.com', 'senha123');
    expect(loggedUser.id, first.id);
    expect((await database.positionsFor(loggedUser.id)).single.symbol, 'PETR4');
    expect((await database.restoreSession())?.email, 'ana@example.com');
  });

  test('não aceita senha incorreta', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      databaseName: inMemoryDatabasePath,
    );
    await database.register(
      name: 'Ana',
      email: 'outra.ana@example.com',
      password: 'senha123',
    );
    expect(
      () => database.login('outra.ana@example.com', 'incorreta'),
      throwsA(isA<AuthException>()),
    );
  });
}
