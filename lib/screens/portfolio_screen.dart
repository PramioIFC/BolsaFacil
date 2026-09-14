import 'package:flutter/material.dart';

import '../models/portfolio_item.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stock_tile.dart';
import 'stock_details_screen.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final invested = state.portfolio.fold(0.0, (sum, item) => sum + item.invested);
          final current = state.portfolio.fold(0.0, (sum, item) => sum + (state.stockFor(item.symbol)?.price ?? item.averagePrice) * item.quantity);
          final profit = current - invested;
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(onPressed: () => _positionDialog(context), icon: const Icon(Icons.add), label: const Text('Adicionar')),
            body: Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Carteira simulada', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink)),
              const SizedBox(height: 18),
              _Summary(invested: invested, current: current, profit: profit),
              const SizedBox(height: 24),
              const Text('Suas posições', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 12),
              Expanded(child: state.portfolio.isEmpty ? const _EmptyPortfolio() : ListView.separated(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: state.portfolio.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _PositionCard(
                  item: state.portfolio[i],
                  state: state,
                  onEdit: () => _positionDialog(context, state.portfolio[i]),
                  onTap: () => _openDetails(context, state.portfolio[i]),
                ),
              )),
            ])),
          );
        },
      );

  Future<void> _openDetails(
    BuildContext context,
    PortfolioItem item,
  ) async {
    try {
      final stock = state.stockFor(item.symbol) ?? await state.search(item.symbol);
      if (!context.mounted || stock == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StockDetailsScreen(
            state: state,
            initialStock: stock,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _positionDialog(BuildContext context, [PortfolioItem? existing]) async {
    final symbol = TextEditingController(text: existing?.symbol ?? '');
    final quantity = TextEditingController(text: existing?.quantity.toString() ?? '');
    final price = TextEditingController(text: existing?.averagePrice.toStringAsFixed(2).replaceAll('.', ',') ?? '');
    final result = await showDialog<PortfolioItem>(context: context, builder: (context) => AlertDialog(
      title: Text(existing == null ? 'Nova posição' : 'Editar posição'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: symbol, enabled: existing == null, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Código da ação', hintText: 'PETR4')),
        const SizedBox(height: 12),
        TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantidade')),
        const SizedBox(height: 12),
        TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço médio de compra', prefixText: 'R\$ ')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () {
        final qty = double.tryParse(quantity.text.replaceAll(',', '.'));
        final avg = double.tryParse(price.text.replaceAll(',', '.'));
        final ticker = symbol.text.trim().toUpperCase();
        if (ticker.isNotEmpty && qty != null && qty > 0 && avg != null && avg > 0) Navigator.pop(context, PortfolioItem(symbol: ticker, quantity: qty, averagePrice: avg));
      }, child: const Text('Salvar'))],
    ));
    symbol.dispose(); quantity.dispose(); price.dispose();
    if (result != null) await state.savePosition(result);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.invested, required this.current, required this.profit});
  final double invested, current, profit;
  @override
  Widget build(BuildContext context) {
    final up = profit >= 0;
    return Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6558F5), Color(0xFF887DF8)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: primary.withValues(alpha: .24), blurRadius: 24, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Valor atual', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 5),
      Text(money(current), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _WhiteMetric(label: 'Investido', value: money(invested))), Expanded(child: _WhiteMetric(label: up ? 'Lucro' : 'Prejuízo', value: '${up ? '+' : ''}${money(profit)}'))]),
    ]));
  }
}

class _WhiteMetric extends StatelessWidget {
  const _WhiteMetric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]);
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.item,
    required this.state,
    required this.onEdit,
    required this.onTap,
  });
  final PortfolioItem item;
  final AppState state;
  final VoidCallback onEdit;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final price = state.stockFor(item.symbol)?.price ?? item.averagePrice;
    final result = (price - item.averagePrice) * item.quantity;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.symbol, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: ink)), const SizedBox(height: 5), Text('${item.quantity.toStringAsFixed(2)} ações • PM ${money(item.averagePrice)}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12))])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(money(price * item.quantity), style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), Text('${result >= 0 ? '+' : ''}${money(result)}', style: TextStyle(color: result >= 0 ? positive : negative, fontWeight: FontWeight.w700))]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
            PopupMenuButton<String>(onSelected: (value) => value == 'edit' ? onEdit() : state.removePosition(item.symbol), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'remove', child: Text('Remover'))]),
          ]),
        ),
      ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.only(bottom: 60), child: Text('Sua simulação começa aqui.\nAdicione uma posição para acompanhar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, height: 1.5))));
}
