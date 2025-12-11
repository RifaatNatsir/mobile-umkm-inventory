import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/api_client.dart';
import '../../models/report_summary.dart';

enum ReportRange { today, week, month, all }

String formatNumber(double value) {
  if (value >= 1000000) return "${(value / 1000000).toStringAsFixed(1)}M";
  if (value >= 1000) return "${(value / 1000).toStringAsFixed(0)}k";
  return value.toStringAsFixed(0);
}

List<ReportPoint> normalizeSeries(List<ReportPoint> list) {
  if (list.isEmpty) return list;

  final start = list.first.date;
  final end = list.last.date;

  final map = {
    for (var p in list) DateTime(p.date.year, p.date.month, p.date.day): p,
  };

  final normalized = <ReportPoint>[];

  for (DateTime d = DateTime(start.year, start.month, start.day);
      !d.isAfter(DateTime(end.year, end.month, end.day));
      d = d.add(const Duration(days: 1))) {
    final key = DateTime(d.year, d.month, d.day);
    if (map.containsKey(key)) {
      normalized.add(map[key]!);
    } else {
      normalized.add(ReportPoint(date: key, revenue: 0, profit: 0));
    }
  }

  return normalized;
}

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
      from = today.subtract(const Duration(days: 6)); // 7 hari terakhir
      break;
    case ReportRange.month:
      from = today.subtract(const Duration(days: 29)); // 30 hari terakhir
      break;
    case ReportRange.all:
      return all;
  }

    return all.where((p) {
    final d = DateTime(p.date.year, p.date.month, p.date.day);
    return !d.isBefore(from) && !d.isAfter(today);
  }).toList();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Usaha'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: FutureBuilder<ReportSummary>(
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
            return const Center(child: Text('Tidak ada data laporan'));
          }

          final report = snap.data!;
          final filtered = filterByRange(report.series, _range);
          final points = normalizeSeries(filtered);
          final totalRevenue = points.fold<double>(0, (sum, p) => sum + p.revenue);
          final totalProfit = points.fold<double>(0, (sum, p) => sum + p.profit);
          final maxX = points.isEmpty ? 0.0 : (points.length - 1).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kartu total omset & laba
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Omset',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rp${report.totalRevenue.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Laba',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rp${report.totalProfit.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ChoiceChip(
                      label: const Text('7 hari'),
                      selected: _range == ReportRange.week,
                      onSelected: (_) => setState(() => _range = ReportRange.week),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('30 hari'),
                      selected: _range == ReportRange.month,
                      onSelected: (_) => setState(() => _range = ReportRange.month),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _range == ReportRange.all,
                      onSelected: (_) => setState(() => _range = ReportRange.all),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  'Grafik Omset per Hari',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (points.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Belum ada transaksi penjualan'),
                  )
                else
                  SizedBox(
                    height: 260,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: maxX,
                        minY: 0, // ⬅️ supaya garis tidak turun di bawah sumbu X
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  formatNumber(value),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1, // ⬅️ STEP 1 HARI
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
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: false, // ⬅️ biar garis tidak “melengkung keluar” sumbu
                            dotData: FlDotData(show: false),
                            spots: List.generate(
                              points.length,
                              (i) => FlSpot(i.toDouble(), points[i].revenue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Ringkasan per Hari',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...points.map((p) {
                  final d =
                      '${p.date.day}-${p.date.month}-${p.date.year}';
                  return ListTile(
                    title: Text(d),
                    subtitle: Text(
                      'Omset: Rp${totalRevenue.toStringAsFixed(0)}\n'
                      'Laba: Rp${totalProfit.toStringAsFixed(0)}',
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}