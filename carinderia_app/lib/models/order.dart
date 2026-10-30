class OrderItem {
  final int id;
  final String menuItemName;
  final int quantity;
  final String? specialInstruction;

  OrderItem({
    required this.id,
    required this.menuItemName,
    required this.quantity,
    this.specialInstruction,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      menuItemName: json['menuItemName'] ?? json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      specialInstruction: json['specialInstruction'],
    );
  }
}

class Order {
  final int id;
  final int tableNumber;
  final int paymentMethod; // 0 = Cash, 1 = QRCode
  final String status; // 'Pending', 'Preparing', 'Ready', 'Completed'
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.tableNumber,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<OrderItem> parsedItems = rawItems
        .map((i) => OrderItem.fromJson(i))
        .toList();

    return Order(
      id: json['id'] ?? 0,
      tableNumber: json['tableNumber'] ?? 1,
      paymentMethod: json['paymentMethod'] ?? 0,
      status: json['status'] ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      items: parsedItems,
    );
  }
}
