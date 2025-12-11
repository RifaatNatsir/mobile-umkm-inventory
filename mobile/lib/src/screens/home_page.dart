import 'package:flutter/material.dart';
import 'items/items_page.dart';
import 'sales/sales_page.dart';
import 'reports/reports_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("UMKM Inventory")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text("Manajemen Barang"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ItemsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text("Transaksi Penjualan"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart),
            title: const Text("Laporan Usaha"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}