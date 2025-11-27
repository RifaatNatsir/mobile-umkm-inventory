class Item {
  final String id;
  final String name;
  final String sku;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int stock;
  final int minStock;
  final String unit;

  Item({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    required this.minStock,
    required this.unit,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    num pBuy = json['purchasePrice'] ?? 0;
    num pSell = json['sellingPrice'] ?? 0;
    num stock = json['stock'] ?? 0;
    num minStock = json['minStock'] ?? 0;

    return Item(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sku: json['sku'] ?? '',
      category: json['category'] ?? '',
      purchasePrice: pBuy.toDouble(),
      sellingPrice: pSell.toDouble(),
      stock: stock.toInt(),
      minStock: minStock.toInt(),
      unit: json['unit'] ?? 'pcs',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "sku": sku,
      "category": category,
      "purchasePrice": purchasePrice,
      "sellingPrice": sellingPrice,
      "stock": stock,
      "minStock": minStock,
      "unit": unit,
    };
  }

  Item copyWith({
    String? name,
    String? sku,
    String? category,
    double? purchasePrice,
    double? sellingPrice,
    int? stock,
    int? minStock,
    String? unit,
  }) 
  {
    return Item(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
    );
  }
}