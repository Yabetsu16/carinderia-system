class MenuItem {
  final int id;
  final String name;
  final String? description;
  final double price;
  final bool isAvailableToday;
  final int categoryId;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.isAvailableToday,
    required this.categoryId,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      isAvailableToday: json['isAvailableToday'],
      categoryId: json['categoryId'],
    );
  }
}
