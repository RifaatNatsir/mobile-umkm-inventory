import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../models/item.dart';
import '../../models/sale.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _api = ApiClient();

  late Future<void> _initFuture;
  List<Item> _items = [];
  List<Sale> _sales = [];
  final List<_CartItem> _cart = [];

  @override
  void initState() {
    super.initState();
    _initFuture = _loadData();
  }

  Future<void> _loadData() async {
    _items = await _api.getItems();
    _sales = await _api.getSales();
  }

  Future<void> _reload() async {
    setState(() {
      _initFuture = _loadData();
    });
  }

  void _addToCart(Item item) {
    final idx = _cart.indexWhere((c) => c.item.id == item.id);
    if (idx >= 0) {
      setState(() {
        _cart[idx].quantity++;
      });
    } else {
      setState(() {
        _cart.add(_CartItem(item: item, quantity: 1));
      });
    }
  }

  void _removeFromCart(_CartItem cartItem) {
    setState(() {
      _cart.remove(cartItem);
    });
  }

  void _changeQty(_CartItem cartItem, int delta) {
    setState(() {
      final newQty = cartItem.quantity + delta;
      if (newQty <= 0) {
        _cart.remove(cartItem);
      } else {
        cartItem.quantity = newQty;
      }
    });
  }

  void _showLowStockSheet(List<dynamic> lowStock) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LowStockSheet(lowStock: lowStock),
    );
  }

  double get _cartTotal {
    double sum = 0;
    for (final c in _cart) {
      sum += (c.item.sellingPrice ?? 0) * c.quantity;
    }
    return sum;
  }

  void _openSaleDetail(Sale sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _SaleDetailSheet(sale: sale);
      },
    );
  }


  Future<void> _submitCart() async {
    if (_cart.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final itemsPayload = _cart
          .map((c) => {
                'itemId': c.item.id,
                'quantity': c.quantity,
              })
          .toList();

      final res = await _api.createSale(itemsPayload);

      final lowStock = (res['lowStockItems'] as List?) ?? [];

      setState(() {
        _cart.clear();
        _initFuture = _loadData();
      });

      if (lowStock.isNotEmpty) {
        _showLowStockSheet(lowStock);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil disimpan')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
      );
    }
  }

  Future<void> _openSelectItem() async {
    final Item? selected = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectItemSheet(items: _items),
    );

    if (selected != null) {
      _addToCart(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Penjualan'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text('Error: ${snap.error}'),
              );
            }

            return Column(
              children: [
                // Section keranjang
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Keranjang',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _openSelectItem,
                            icon: const Icon(Icons.add_shopping_cart_outlined),
                            label: const Text('Tambah barang'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_cart.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Belum ada barang di keranjang.\nTap "Tambah barang" untuk memilih.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      else
                        Column(
                          children: [
                            ..._cart.map(
                              (c) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: _CartItemTile(
                                  cartItem: c,
                                  onInc: () => _changeQty(c, 1),
                                  onDec: () => _changeQty(c, -1),
                                  onRemove: () => _removeFromCart(c),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Rp${_cartTotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submitCart,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Selesaikan transaksi'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Riwayat Transaksi',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Riwayat transaksi list
                Expanded(
                  child: _sales.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada transaksi penjualan.',
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _sales.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final sale = _sales[index];
                            final date = _parseDate(sale.createdAt);
                            final itemCount = sale.items.length;

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: scheme.primary.withOpacity(0.12),
                                  child: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'Rp${sale.totalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_formatDateTime(date)} • $itemCount item',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                onTap: () => _openSaleDetail(sale),   // ⬅️ ini yang bikin bisa diklik
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  DateTime _parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _formatDateTime(DateTime d) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// ===== MODEL KERANJANG LOKAL =====

class _CartItem {
  final Item item;
  int quantity;

  _CartItem({
    required this.item,
    this.quantity = 1,
  });
}

/// ====== WIDGET CART ITEM TILE ======

class _CartItemTile extends StatelessWidget {
  final _CartItem cartItem;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.cartItem,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final price = cartItem.item.sellingPrice ?? 0;
    final total = price * cartItem.quantity;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rp${price.toStringAsFixed(0)} / ${cartItem.item.unit ?? "pcs"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal: Rp${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onDec,
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Kurangi',
                ),
                Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: onInc,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Tambah',
                ),
              ],
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Hapus dari keranjang',
            ),
          ],
        ),
      ),
    );
  }
}

/// ====== SHEET PILIH BARANG ======

class _SelectItemSheet extends StatefulWidget {
  final List<Item> items;
  const _SelectItemSheet({required this.items});

  @override
  State<_SelectItemSheet> createState() => _SelectItemSheetState();
}

class _SelectItemSheetState extends State<_SelectItemSheet> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    final filtered = widget.items.where((item) {
      final q = _searchC.text.toLowerCase();
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
          item.sku.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Text(
                      'Pilih Barang',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchC,
                      decoration: const InputDecoration(
                        hintText: 'Cari nama / SKU barang...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada barang yang cocok.',
                                style: TextStyle(fontSize: 12),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    title: Text(item.name),
                                    subtitle: Text(
                                      'SKU: ${item.sku} • Stok: ${item.stock} ${item.unit ?? "pcs"}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Text(
                                      'Rp${(item.sellingPrice ?? 0).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onTap: () =>
                                        Navigator.pop<Item>(context, item),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaleDetailSheet extends StatelessWidget {
  final Sale sale;
  const _SaleDetailSheet({required this.sale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = _parseDateStatic(sale.createdAt);

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Text(
                      'Detail Transaksi',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTimeStatic(date),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // List item transaksi
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        itemCount: sale.items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = sale.items[index];
                          final qty = item.quantity;
                          final unitPrice = item.unitPrice;
                          final total = item.totalPrice;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Qty: $qty • Rp${unitPrice.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rp${total.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Total
                    Row(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Rp${sale.totalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper statis karena kita di Stateless dan di luar _SalesPageState
  static DateTime _parseDateStatic(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static String _formatDateTimeStatic(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _LowStockSheet extends StatelessWidget {
  final List<dynamic> lowStock;

  const _LowStockSheet({required this.lowStock});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stok barang menipis',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Beberapa barang sudah mencapai atau di bawah stok minimum:',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        itemCount: lowStock.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final data = lowStock[index] as Map<String, dynamic>;
                          final name = data['itemName'] ?? 'Tanpa nama';
                          final currentStock = data['currentStock'] ?? 0;
                          final minStock = data['minStock'] ?? 0;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: scheme.error.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      size: 18,
                                      color: scheme.error,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Stok: $currentStock • Minimum: $minStock',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Mengerti'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}