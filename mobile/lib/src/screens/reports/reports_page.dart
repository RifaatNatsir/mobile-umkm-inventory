import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/api_client.dart';
import '../../models/report_summary.dart';

enum ReportRange { today, week, month, all }

String formatNumber(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.toStringAsFixed(0);
}

/// Normalisasi agar setiap hari di dalam range muncul 1x,
/// hari tanpa transaksi -> revenue & profit = 0.
List<ReportPoint> normalizeSeries(List<ReportPoint> list) {
  if (list.isEmpty) return list;

  final start = DateTime(
    list.first.date.year,
    list.first.date.month,
    list.first.date.day,
  );
  final end = DateTime(
    list.last.date.year,
    list.last.date.month,
    list.last.date.day,
  );

  final map = {
    for (var p in list)
      DateTime(p.date.year, p.date.month, p.date.day): p,
  };

  final normalized = <ReportPoint>[];

  for (DateTime d = start;
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))) {
    final key = DateTime(d.year, d.month, d.day);
    if (map.containsKey(key)) {
      normalized.add(map[key]!);
    } else {
      normalized.add(ReportPoint(
        date: key,
        revenue: 0,
        profit: 0,
      ));
    }
  }

  return normalized;
}

/// Filter berdasarkan rentang (hari ini, 7 hari, 30 hari, semua)
List<ReportPoint> filterByRange(List<ReportPoint> all, ReportRange range) {
  if (all.isEmpty || range == ReportRange.all) return all;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime from;

  switch (range) {
    case ReportRange.today:
      from = today;
      break;
    case ReportRange.week:
      from = today.subtract(const Duration(days: 6));
      break;
    case ReportRange.month:
      from = today.subtract(const Duration(days: 29));
      break;
    case ReportRange.all:
      return all;
  }

  return all.where((p) {
    final d = DateTime(p.date.year, p.date.month, p.date.day);
    return !d.isBefore(from) && !d.isAfter(today);
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _api = ApiClient();
  late Future<ReportSummary> _future;

  ReportRange _range = ReportRange.all;

  @override
  void initState() {
    super.initState();
    _future = _api.getReportSummary();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getReportSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Usaha'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<ReportSummary>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text('Error: ${snap.error}'),
                );
              }
              if (!snap.hasData) {
                return const Center(
                  child: Text('Tidak ada data laporan.'),
                );
              }

              final report = snap.data!;

              // 1. filter + normalisasi
              var series = report.series.toList()
                ..sort((a, b) => a.date.compareTo(b.date));
              series = filterByRange(series, _range);
              series = normalizeSeries(series);

              if (series.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilterChips(
                      range: _range,
                      onChanged: (r) => setState(() => _range = r),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Tidak ada transaksi pada rentang waktu ini.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                );
              }

              // 2. hitung total berdasarkan data terfilter
              final totalRevenue = series
                  .fold<double>(0, (sum, p) => sum + p.revenue);
              final totalProfit = series
                  .fold<double>(0, (sum, p) => sum + p.profit);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ringkasan omzet & laba
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Omzet',
                          value: 'Rp${totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.payments_outlined,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Laba',
                          value: 'Rp${totalProfit.toStringAsFixed(0)}',
                          icon: Icons.trending_up_outlined,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter chips
                  _FilterChips(
                    range: _range,
                    onChanged: (r) => setState(() => _range = r),
                  ),
                  const SizedBox(height: 12),

                  // Card grafik
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Grafik Omzet Harian',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Menampilkan total omzet per hari pada rentang waktu terpilih.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 220,
                              child: _RevenueChart(points: series),
                            ),
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Ringkasan harian',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: series.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  final p = series[index];
                                  final d = p.date;
                                  final dateLabel =
                                      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dateLabel,
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Omzet: Rp${p.revenue.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Laba: Rp${p.profit.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final ReportRange range;
  final ValueChanged<ReportRange> onChanged;

  const _FilterChips({
    required this.range,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('7 hari'),
            selected: range == ReportRange.week,
            onSelected: (_) => onChanged(ReportRange.week),
          ),
          ChoiceChip(
            label: const Text('30 hari'),
            selected: range == ReportRange.month,
            onSelected: (_) => onChanged(ReportRange.month),
          ),
          ChoiceChip(
            label: const Text('Semua'),
            selected: range == ReportRange.all,
            onSelected: (_) => onChanged(ReportRange.all),
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<ReportPoint> points;

  const _RevenueChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada data.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    final maxX = (points.length - 1).toDouble();
    double maxY = 0;
    for (final p in points) {
      if (p.revenue > maxY) maxY = p.revenue;
    }
    if (maxY == 0) maxY = 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: Colors.black12),
            bottom: BorderSide(color: Colors.black12),
            right: BorderSide(color: Colors.transparent),
            top: BorderSide(color: Colors.transparent),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                return Text(
                  formatNumber(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: false,
            barWidth: 2,
            dotData: FlDotData(show: false),
            spots: List.generate(
              points.length,
              (i) => FlSpot(i.toDouble(), points[i].revenue),
            ),
          ),
        ],
      ),
    );
  }
}