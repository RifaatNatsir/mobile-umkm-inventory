import 'package:flutter/material.dart';
import 'items/items_page.dart';
import 'sales/sales_page.dart';
import 'reports/reports_page.dart';
import 'auth/login_page.dart';
import '../models/app_user.dart';

class HomePage extends StatelessWidget {
  final AppUser user;

  const HomePage({super.key, required this.user});

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOwner = user.role == 'owner';
    // final isOwner = false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UMKM Inventory'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Salam
              Text(
                'Halo, ${user.name.isNotEmpty ? user.name : "Pengguna"} 👋',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                isOwner
                    ? 'Anda login sebagai Pemilik Toko.'
                    : 'Anda login sebagai Kasir. Akses dibatasi ke pencatatan transaksi.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 16),

              // Info kecil
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOwner
                            ? 'Gunakan menu di bawah untuk mengelola stok, transaksi, dan laporan.'
                            : 'Kasir hanya dapat mencatat transaksi penjualan.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Menu',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView(
                  children: [
                    // MENU YANG SELALU ADA (PEMILIK & KASIR)
                    _SmallMenuCard(
                      icon: Icons.point_of_sale_rounded,
                      iconColor: scheme.tertiary,
                      title: 'Transaksi Penjualan',
                      subtitle: 'Catat penjualan dengan keranjang belanja',
                      onTap: () => _goTo(context, const SalesPage()),
                    ),

                    // MENU KHUSUS PEMILIK
                    if (isOwner) ...[
                      _SmallMenuCard(
                        icon: Icons.inventory_2_rounded,
                        iconColor: scheme.primary,
                        title: 'Manajemen Barang',
                        subtitle: 'Tambah, edit, dan pantau stok barang',
                        onTap: () => _goTo(context, const ItemsPage()),
                      ),
                      _SmallMenuCard(
                        icon: Icons.bar_chart_rounded,
                        iconColor: Colors.green,
                        title: 'Laporan Usaha',
                        subtitle: 'Lihat omset, laba, dan grafik penjualan',
                        onTap: () => _goTo(context, const ReportsPage()),
                      ),
                    ],

                    const SizedBox(height: 8),
                    _SmallMenuCard(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.redAccent,
                      title: 'Logout',
                      subtitle: 'Keluar dari akun ini',
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallMenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SmallMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}