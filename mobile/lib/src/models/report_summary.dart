class ReportPoint {
  final DateTime date;
  final double revenue;
  final double profit;

  ReportPoint({
    required this.date,
    required this.revenue,
    required this.profit,
  });

  factory ReportPoint.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    return ReportPoint(
      date: date,
      revenue: (json['revenue'] ?? 0).toDouble(),
      profit: (json['profit'] ?? 0).toDouble(),
    );
  }
}

class ReportSummary {
  final double totalRevenue;
  final double totalProfit;
  final List<ReportPoint> series;

  ReportSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.series,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    final list = (json['series'] as List? ?? [])
        .map((e) => ReportPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ReportSummary(
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalProfit: (json['totalProfit'] ?? 0).toDouble(),
      series: list,
    );
  }
}