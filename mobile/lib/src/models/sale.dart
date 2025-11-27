class Sale {
  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.createdAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];

    DateTime created;
    if (rawCreatedAt is String) {
      created = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return Sale(
      id: json['id'] ?? '',
      itemId: json['itemId'] ?? '',
      itemName: json['itemName'] ?? '',
      quantity: (json['quantity'] ?? 0) as int,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      createdAt: created,
    );
  }

}