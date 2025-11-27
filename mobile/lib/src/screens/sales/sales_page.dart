import 'package:flutter/material.dart';
import '../../models/item.dart';
import '../../models/sale.dart';
import '../../services/api_client.dart';

class CartItem {
  final Item item;
  int quantity;

  CartItem({
    required this.item,
    required this.quantity,
  });

  double get total => item.sellingPrice * quantity;
}

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final ApiClient _apiClient = ApiClient();

  late Future<List<Sale>> _futureSales;
  final List<CartItem> _cart = [];

  double get cartTotal =>
      _cart.fold(0, (sum, c) => sum + c.total);

  @override
  void initState() {
    super.initState();
    _futureSales = _apiClient.getSales();
  }

  Future<void> _reloadSales() async {
    setState(() {
      _futureSales = _apiClient.getSales();
    });
  }

  Future<void> _showAddSaleDialog() async {
    final quantityController = TextEditingController();
    Item? selectedItem;

    List<Item> items;
    try {
      items = await _apiClient.getItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat daftar barang: $e')),
      );
      return;
    }

    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada barang untuk dijual')),
      );
      return;
    }

    List<Item> filtered = List.from(items);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Tambah ke Keranjang'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Cari barang',
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        filtered = items
                            .where((i) => i.name
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Item>(
                    decoration:
                        const InputDecoration(labelText: "Pilih barang"),
                    items: filtered.map((i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text("${i.name} (Stok: ${i.stock})"),
                      );
                    }).toList(),
                    onChanged: (val) => selectedItem = val,
                  ),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jumlah'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Tambah"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selectedItem != null) {
      final qty = int.tryParse(quantityController.text) ?? 0;
      if (qty <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Jumlah tidak valid")),
        );
        return;
      }

      setState(() {
        _cart.add(CartItem(item: selectedItem!, quantity: qty));
      });
    }
  }

  Future<void> _submitCart() async {
    if (_cart.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      for (final c in _cart) {
        await _apiClient.createSale(
          itemId: c.item.id,
          quantity: c.quantity,
        );
      }

      setState(() {
        _cart.clear();
        _futureSales = _apiClient.getSales();
      });

      messenger.showSnackBar(
        const SnackBar(content: Text("Transaksi berhasil disimpan")),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Gagal menyimpan transaksi: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaksi Penjualan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadSales,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSaleDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // List transaksi
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: _futureSales,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final sales = snapshot.data ?? [];

                if (sales.isEmpty) {
                  return const Center(
                      child: Text("Belum ada transaksi"));
                }

                return ListView.separated(
                  itemCount: sales.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = sales[index];
                    final date = s.createdAt;
                    final dateText =
                        "${date.day}-${date.month}-${date.year}";

                    return ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(s.itemName),
                      subtitle: Text(
                        "Qty: ${s.quantity} x Rp${s.unitPrice.toStringAsFixed(0)}\n"
                        "Total: Rp${s.totalPrice.toStringAsFixed(0)}",
                      ),
                      trailing: Text(
                        dateText,
                        style:
                            const TextStyle(color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Keranjang kasir
          if (_cart.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const Text(
                    "Keranjang",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._cart.map(
                    (c) => ListTile(
                      title: Text(c.item.name),
                      subtitle: Text(
                        "Qty: ${c.quantity} x Rp${c.item.sellingPrice.toStringAsFixed(0)}",
                      ),
                      trailing: Text(
                        "Rp${c.total.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Total: Rp${cartTotal.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _submitCart,
                    icon: const Icon(Icons.check),
                    label: const Text("Selesaikan Transaksi"),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}