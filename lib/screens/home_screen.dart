import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stock_tile.dart';
import 'stock_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = TextEditingController();
  bool searching = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (controller.text.trim().isEmpty) return;
    setState(() => searching = true);
    try {
      final stock = await widget.state.search(controller.text);
      if (mounted && stock != null) _open(stock);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  void _open(Stock stock) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StockDetailsScreen(state: widget.state, initialStock: stock),
      ));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => RefreshIndicator(
          onRefresh: widget.state.refresh,
          child: CustomScrollView(slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 6),
              sliver: SliverToBoxAdapter(child: _Header()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Buscar ação, ex: PETR4',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searching ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Ações em destaque', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
                  Text('B3 • agora', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12)),
                ]),
              ),
            ),
            if (widget.state.loading && widget.state.stocks.isEmpty)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (widget.state.error != null && widget.state.stocks.isEmpty)
              SliverFillRemaining(child: _ErrorState(message: widget.state.error!, retry: widget.state.refresh))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                sliver: SliverList.separated(
                  itemCount: widget.state.stocks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final stock = widget.state.stocks[i];
                    return StockTile(stock: stock, isFavorite: widget.state.favorites.contains(stock.symbol), onTap: () => _open(stock), onFavorite: () => widget.state.toggleFavorite(stock.symbol));
                  },
                ),
              ),
          ]),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.trending_up_rounded, color: Colors.white)),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bolsa Fácil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink)),
          Text('Invista conhecimento primeiro', style: TextStyle(color: Colors.blueGrey)),
        ]),
      ]);
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.blueGrey),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
      ])));
}
