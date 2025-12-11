import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../models/item.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final _api = ApiClient();
  late Future<List<Item>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getItems();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getItems();
    });
  }

  Future<void> _openForm({Item? item}) async {
    final result = await showModalBottomSheet<_ItemFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ItemFormSheet(item: item);
      },
    );

    if (result == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      if (item == null) {
        // create
        await _api.createItem({
          'name': result.name,
          'sku': result.sku,
          'category': result.category,
          'purchasePrice': result.purchasePrice,
          'sellingPrice': result.sellingPrice,
          'stock': result.stock,
          'minStock': result.minStock,
          'unit': result.unit,
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('Barang berhasil ditambahkan')),
        );
      } else {
        // update
        await _api.updateItem(
          item.id,
          {
            'name': result.name,
            'sku': result.sku,
            'category': result.category,
            'purchasePrice': result.purchasePrice,
            'sellingPrice': result.sellingPrice,
            'stock': result.stock,
            'minStock': result.minStock,
            'unit': result.unit,
          },
        );

        messenger.showSnackBar(
          const SnackBar(content: Text('Barang berhasil diperbarui')),
        );
      }

      await _reload();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan data: $e')),
      );
    }
  }

  Future<void> _deleteItem(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus Barang'),
          content: Text('Yakin ingin menghapus "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await _api.deleteItem(item.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Barang berhasil dihapus')),
      );
      await _reload();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus barang: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Barang'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<List<Item>>(
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
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return const Center(
                  child: Text('Belum ada barang. Tambahkan barang terlebih dulu.'),
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final lowStock =
                      item.minStock != null && item.stock <= item.minStock;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar kecil huruf awal nama
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (item.name.isNotEmpty
                                      ? item.name[0]
                                      : '?')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (lowStock)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                          horizontal: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'Stok menipis',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SKU: ${item.sku}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _InfoChip(
                                      icon: Icons.category_outlined,
                                      label:
                                          item.category?.isNotEmpty == true
                                              ? item.category!
                                              : 'Tanpa kategori',
                                    ),
                                    _InfoChip(
                                      icon: Icons.storefront_outlined,
                                      label:
                                          'Stok: ${item.stock} ${item.unit ?? "pcs"}',
                                    ),
                                    _InfoChip(
                                      icon: Icons.sell_outlined,
                                      label:
                                          'Harga jual: Rp${item.sellingPrice.toStringAsFixed(0)}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openForm(item: item),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteItem(item),
                                tooltip: 'Hapus',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// ==== FORM BOTTOM SHEET ====

class _ItemFormResult {
  final String name;
  final String sku;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int stock;
  final int minStock;
  final String unit;

  _ItemFormResult({
    required this.name,
    required this.sku,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    required this.minStock,
    required this.unit,
  });
}

class _ItemFormSheet extends StatefulWidget {
  final Item? item;
  const _ItemFormSheet({this.item});

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameC;
  late final TextEditingController _skuC;
  late final TextEditingController _categoryC;
  late final TextEditingController _purchaseC;
  late final TextEditingController _sellingC;
  late final TextEditingController _stockC;
  late final TextEditingController _minStockC;
  late final TextEditingController _unitC;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameC = TextEditingController(text: item?.name ?? '');
    _skuC = TextEditingController(text: item?.sku ?? '');
    _categoryC = TextEditingController(text: item?.category ?? '');
    _purchaseC =
        TextEditingController(text: item?.purchasePrice.toString() ?? '');
    _sellingC =
        TextEditingController(text: item?.sellingPrice.toString() ?? '');
    _stockC =
        TextEditingController(text: item?.stock.toString() ?? '');
    _minStockC =
        TextEditingController(text: item?.minStock.toString() ?? '0');
    _unitC = TextEditingController(text: item?.unit ?? 'pcs');
  }

  @override
  void dispose() {
    _nameC.dispose();
    _skuC.dispose();
    _categoryC.dispose();
    _purchaseC.dispose();
    _sellingC.dispose();
    _stockC.dispose();
    _minStockC.dispose();
    _unitC.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final result = _ItemFormResult(
      name: _nameC.text.trim(),
      sku: _skuC.text.trim(),
      category: _categoryC.text.trim(),
      purchasePrice: double.tryParse(_purchaseC.text) ?? 0,
      sellingPrice: double.tryParse(_sellingC.text) ?? 0,
      stock: int.tryParse(_stockC.text) ?? 0,
      minStock: int.tryParse(_minStockC.text) ?? 0,
      unit: _unitC.text.trim().isEmpty ? 'pcs' : _unitC.text.trim(),
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

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
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 32,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Text(
                          isEdit ? 'Edit Barang' : 'Tambah Barang',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameC,
                          decoration: const InputDecoration(
                            labelText: 'Nama barang',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _skuC,
                          decoration: const InputDecoration(
                            labelText: 'SKU',
                            prefixIcon: Icon(Icons.confirmation_number_outlined),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _categoryC,
                          decoration: const InputDecoration(
                            labelText: 'Kategori (opsional)',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _purchaseC,
                                decoration: const InputDecoration(
                                  labelText: 'Harga beli',
                                  prefixIcon:
                                      Icon(Icons.shopping_cart_outlined),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _sellingC,
                                decoration: const InputDecoration(
                                  labelText: 'Harga jual',
                                  prefixIcon: Icon(Icons.sell_outlined),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Wajib';
                                  }
                                  if (double.tryParse(v) == null) {
                                    return 'Angka';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockC,
                                decoration: const InputDecoration(
                                  labelText: 'Stok awal',
                                  prefixIcon: Icon(Icons.inventory_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Wajib';
                                  }
                                  if (int.tryParse(v) == null) {
                                    return 'Angka';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _minStockC,
                                decoration: const InputDecoration(
                                  labelText: 'Stok minimum',
                                  prefixIcon:
                                      Icon(Icons.warning_amber_rounded),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _unitC,
                          decoration: const InputDecoration(
                            labelText: 'Satuan (mis: pcs, box)',
                            prefixIcon: Icon(Icons.straighten_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Barang'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}