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
    // Extract name from the nested 'menuItem' object sent by C# EF Core
    final menuItemObj = json['menuItem'] as Map<String, dynamic>?;
    final extractedName =
        menuItemObj?['name'] ?? json['menuItemName'] ?? json['name'] ?? 'Item';

    return OrderItem(
      id: json['id'] ?? 0,
      menuItemName: extractedName,
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
    var rawStatus = json['status'];
    String statusString;

    if (rawStatus is int) {
      switch (rawStatus) {
        case 0:
          statusString = 'Pending';
          break;
        case 1:
          statusString = 'Preparing';
          break;
        case 2:
          statusString = 'Ready';
          break;
        case 3:
          statusString = 'Completed';
          break;
        default:
          statusString = 'Unknown';
      }
    } else {
      statusString = rawStatus?.toString() ?? 'Preparing';
    }

    // C# serializes OrderItems as 'orderItems' (camelCase)
    var rawItems = json['orderItems'] ?? json['items'] as List? ?? [];
    List<OrderItem> parsedItems = (rawItems as List)
        .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return Order(
      id: json['id'] ?? 0,
      tableNumber: json['tableNumber'] ?? 1,
      paymentMethod: json['paymentMethod'] ?? 0,
      status: statusString,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      items: parsedItems,
    );
  }
}
