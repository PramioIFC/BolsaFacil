import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'services/brapi_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BolsaFacilApp());
}

class BolsaFacilApp extends StatefulWidget {
  const BolsaFacilApp({super.key});

  @override
  State<BolsaFacilApp> createState() => _BolsaFacilAppState();
}

class _BolsaFacilAppState extends State<BolsaFacilApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState(BrapiService());
    state.initialize();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bolsa Fácil',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: AppShell(state: state),
      );
}
