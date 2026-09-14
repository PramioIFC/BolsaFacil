import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'portfolio_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});
  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(state: widget.state),
      FavoritesScreen(state: widget.state),
      PortfolioScreen(state: widget.state),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.candlestick_chart_outlined), selectedIcon: Icon(Icons.candlestick_chart), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.star_outline_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Favoritas'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Carteira'),
        ],
      ),
    );
  }
}
