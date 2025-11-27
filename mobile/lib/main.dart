import 'package:flutter/material.dart';
import 'src/models/item.dart';
import 'src/services/api_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UMKM Inventory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ItemsPage(),
    );
  }
}

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
    final purchasePriceController = TextEditingController(
        text: existing != null ? existing.purchasePrice.toString() : '');
    final sellingPriceController = TextEditingController(
        text: existing != null ? existing.sellingPrice.toString() : '');
    final stockController = TextEditingController(
        text: existing != null ? existing.stock.toString() : '');
    final minStockController = TextEditingController(
        text: existing != null ? existing.minStock.toString() : '');
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
                  decoration: const InputDecoration(labelText: 'Kode / SKU'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                ),
                TextField(
                  controller: purchasePriceController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Harga beli (Rp)'),
                ),
                TextField(
                  controller: sellingPriceController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Harga jual (Rp)'),
                ),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok awal'),
                ),
                TextField(
                  controller: minStockController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Stok minimal'),
                ),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isEdit ? 'Simpan' : 'Tambah'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      if (nameController.text.isEmpty || skuController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama dan SKU wajib diisi')),
        );
        return;
      }

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
          SnackBar(content: Text('Gagal menyimpan barang: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(Item item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Barang'),
        content: Text('Yakin ingin menghapus "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (result == true) {
      final messenger = ScaffoldMessenger.of(context);

      try {
        await _apiClient.deleteItem(item.id);
        await _reload();

        // SnackBar dengan UNDO
        messenger.showSnackBar(
          SnackBar(
            content: Text('Barang "${item.name}" dihapus'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                try {
                  // buat lagi item yang sama (id baru, data sama)
                  await _apiClient.createItem(
                    item.copyWith(),
                  );
                  await _reload();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Gagal mengembalikan barang: $e'),
                    ),
                  );
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal menghapus barang: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Barang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: _futureItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('Belum ada barang'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  'SKU: ${item.sku}\n'
                  'Stok: ${item.stock} ${item.unit} (min ${item.minStock})\n'
                  'Harga: Rp${item.sellingPrice.toStringAsFixed(0)}',
                ),
                isThreeLine: true,
                // tombol edit + hapus di sebelah kanan
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}