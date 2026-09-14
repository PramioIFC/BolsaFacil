import 'package:bolsa_facil/database/app_database.dart';
import 'package:bolsa_facil/screens/auth_screen.dart';
import 'package:bolsa_facil/services/brapi_service.dart';
import 'package:bolsa_facil/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('exibe a identidade do aplicativo', (tester) async {
    sqfliteFfiInit();
    final state = AppState(
      BrapiService(),
      AppDatabase(
        factory: databaseFactoryFfi,
        databaseName: inMemoryDatabasePath,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(state: state)),
    );
    expect(find.text('Bolsa Fácil'), findsOneWidget);
  });
}
