import 'package:flutter/material.dart';
import '../../models/item.dart';
import '../../services/api_client.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Item>> _futureItems;

  @override
  void initState() {
    super.initState();
    _futureItems = _apiClient.getItems();
  }

  Future<void> _reload() async {
    setState(() {
      _futureItems = _apiClient.getItems();
    });
  }

  Future<void> _showItemDialog({Item? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final skuController = TextEditingController(text: existing?.sku ?? '');
    final categoryController =
        TextEditingController(text: existing?.category ?? '');
    final purchasePriceController =
        TextEditingController(text: existing?.purchasePrice.toString() ?? '');
    final sellingPriceController =
        TextEditingController(text: existing?.sellingPrice.toString() ?? '');
    final stockController =
        TextEditingController(text: existing?.stock.toString() ?? '');
    final minStockController =
        TextEditingController(text: existing?.minStock.toString() ?? '');
    final unitController =
        TextEditingController(text: existing?.unit ?? 'pcs');

    final isEdit = existing != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return SingleChildScrollView(
          child: AlertDialog(
            title: Text(isEdit ? 'Edit Barang' : 'Tambah Barang'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama barang'),
                ),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                ),
                TextField(
                  controller: purchasePriceController,
                  decoration: const InputDecoration(labelText: 'Harga beli'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: sellingPriceController,
                  decoration: const InputDecoration(labelText: 'Harga jual'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stok'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: minStockController,
                  decoration: const InputDecoration(labelText: 'Stok minimal'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Satuan'),
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
                child: Text(isEdit ? "Simpan" : "Tambah"),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      double parseDouble(String text) =>
          double.tryParse(text.trim()) ?? 0.0;
      int parseInt(String text) => int.tryParse(text.trim()) ?? 0;

      final item = Item(
        id: existing?.id ?? '',
        name: nameController.text.trim(),
        sku: skuController.text.trim(),
        category: categoryController.text.trim(),
        purchasePrice: parseDouble(purchasePriceController.text),
        sellingPrice: parseDouble(sellingPriceController.text),
        stock: parseInt(stockController.text),
        minStock: parseInt(minStockController.text),
        unit: unitController.text.trim().isEmpty
            ? 'pcs'
            : unitController.text.trim(),
      );

      try {
        if (isEdit) {
          await _apiClient.updateItem(item);
        } else {
          await _apiClient.createItem(item);
        }
        await _reload();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan barang: $e")),
        );
      }
    }
  }

  Future<void> _confirmDelete(Item item) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus barang"),
        content: Text("Yakin ingin menghapus ${item.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiClient.deleteItem(item.id);
        await _reload();

        messenger.showSnackBar(
          SnackBar(
            content: Text("Barang ${item.name} dihapus"),
            action: SnackBarAction(
              label: "UNDO",
              onPressed: () async {
                await _apiClient.createItem(item.copyWith());
                await _reload();
              },
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text("Gagal menghapus: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manajemen Barang")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Item>>(
        future: _futureItems,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;

          if (items.isEmpty) {
            return const Center(child: Text("Belum ada barang"));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final isLowStock = item.stock <= item.minStock;
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  "SKU: ${item.sku}\nStok: ${item.stock} ${item.unit}"
                  "${isLowStock ? " • STOK MENIPIS" : ""}",
                ),
                subtitleTextStyle: TextStyle(
                  color: isLowStock ? Colors.red : null,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showItemDialog(existing: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDelete(item),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}