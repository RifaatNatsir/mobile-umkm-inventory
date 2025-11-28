class SaleItem {
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  SaleItem({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      itemName: json['itemName'] ?? '',
      quantity: (json['quantity'] ?? 0) as int,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }
}

class Sale {
  final String id;
  final double totalPrice;
  final DateTime createdAt;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.totalPrice,
    required this.createdAt,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime created;

    if (rawCreatedAt is String) {
      created = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    final itemsJson = (json['items'] as List?) ?? [];
    final items = itemsJson
        .map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return Sale(
      id: json['id'] ?? '',
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      createdAt: created,
      items: items,
    );
  }
}