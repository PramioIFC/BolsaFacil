class PortfolioItem {
  const PortfolioItem({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });

  final String symbol;
  final double quantity;
  final double averagePrice;

  double get invested => quantity * averagePrice;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'quantity': quantity,
        'averagePrice': averagePrice,
      };

  factory PortfolioItem.fromJson(Map<String, dynamic> json) => PortfolioItem(
        symbol: json['symbol'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        averagePrice: (json['averagePrice'] as num).toDouble(),
      );
}
