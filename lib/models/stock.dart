class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    this.logoUrl,
    this.currency = 'BRL',
    this.marketCap,
    this.history = const [],
  });

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final String? logoUrl;
  final String currency;
  final double? marketCap;
  final List<PricePoint> history;

  factory Stock.fromJson(Map<String, dynamic> json) {
    final historical = (json['historicalDataPrice'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PricePoint.fromJson)
        .where((point) => point.close > 0)
        .toList();
    return Stock(
      symbol: json['symbol']?.toString() ?? '',
      name: json['longName']?.toString() ?? json['shortName']?.toString() ?? '',
      price: (json['regularMarketPrice'] as num?)?.toDouble() ?? 0,
      changePercent:
          (json['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
      logoUrl: json['logourl']?.toString(),
      currency: json['currency']?.toString() ?? 'BRL',
      marketCap: (json['marketCap'] as num?)?.toDouble(),
      history: historical,
    );
  }
}

class PricePoint {
  const PricePoint({required this.date, required this.close});

  final DateTime date;
  final double close;

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
        date: DateTime.fromMillisecondsSinceEpoch(
          ((json['date'] as num?)?.toInt() ?? 0) * 1000,
        ),
        close: (json['close'] as num?)?.toDouble() ?? 0,
      );
}
