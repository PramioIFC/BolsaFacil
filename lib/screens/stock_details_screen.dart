import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stock_tile.dart';

class StockDetailsScreen extends StatefulWidget {
  const StockDetailsScreen({super.key, required this.state, required this.initialStock});
  final AppState state;
  final Stock initialStock;

  @override
  State<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends State<StockDetailsScreen> {
  Stock? stock;
  String? error;

  @override
  void initState() {
    super.initState();
    stock = widget.initialStock;
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.state.api.getQuote(widget.initialStock.symbol);
      if (mounted) setState(() => stock = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = stock!;
    final up = current.changePercent >= 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(current.symbol),
        actions: [AnimatedBuilder(animation: widget.state, builder: (_, __) => IconButton(
          onPressed: () => widget.state.toggleFavorite(current.symbol),
          icon: Icon(widget.state.favorites.contains(current.symbol) ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFB020)),
        )), const SizedBox(width: 8)],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
        Text(current.name, style: const TextStyle(color: Colors.blueGrey, fontSize: 15)),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(current.price), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: ink, letterSpacing: -1)),
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: (up ? positive : negative).withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
            child: Text('${up ? '+' : ''}${current.changePercent.toStringAsFixed(2)}%', style: TextStyle(color: up ? positive : negative, fontWeight: FontWeight.w800)),
          )),
        ]),
        const SizedBox(height: 26),
        Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Histórico • 3 meses', style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 24),
          SizedBox(height: 230, child: current.history.isEmpty ? _ChartLoading(error: error) : _PriceChart(stock: current)),
        ]))),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Expanded(child: _Metric(label: 'Moeda', value: current.currency)),
          Container(width: 1, height: 38, color: Colors.blueGrey.shade100),
          Expanded(child: _Metric(label: 'Valor de mercado', value: current.marketCap == null ? '—' : _compact(current.marketCap!))),
        ]))),
      ]),
    );
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.stock});
  final Stock stock;
  @override
  Widget build(BuildContext context) {
    final spots = [for (var i = 0; i < stock.history.length; i++) FlSpot(i.toDouble(), stock.history[i].close)];
    final rising = stock.history.last.close >= stock.history.first.close;
    final color = rising ? positive : negative;
    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFFEFF1F7), strokeWidth: 1)),
      titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => ink, getTooltipItems: (items) => items.map((item) => LineTooltipItem(money(item.y), const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))).toList())),
      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, curveSmoothness: .2, color: color, barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)])))],
    ));
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading({this.error});
  final String? error;
  @override
  Widget build(BuildContext context) => Center(child: error == null ? const CircularProgressIndicator() : Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)), const SizedBox(height: 5), Text(value, style: const TextStyle(color: ink, fontWeight: FontWeight.w800))]);
}

String _compact(double value) {
  if (value >= 1e12) return 'R\$ ${(value / 1e12).toStringAsFixed(1)} tri';
  if (value >= 1e9) return 'R\$ ${(value / 1e9).toStringAsFixed(1)} bi';
  return money(value);
}
