import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory createDatabaseFactory() {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}
