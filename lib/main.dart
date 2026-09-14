import 'package:flutter/material.dart';

import 'database/app_database.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
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
    state = AppState(BrapiService(), AppDatabase());
    state.initialize();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bolsa Fácil',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            if (state.initializing) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return state.isAuthenticated
                ? AppShell(state: state)
                : AuthScreen(state: state);
          },
        ),
      );
}
