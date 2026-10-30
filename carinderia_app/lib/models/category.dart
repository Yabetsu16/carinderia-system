import 'menu_item.dart';

class Category {
  final int id;
  final String name;
  final List<MenuItem> menuItems;

  Category({required this.id, required this.name, required this.menuItems});

  factory Category.fromJson(Map<String, dynamic> json) {
    var list = json['menuItems'] as List? ?? [];
    List<MenuItem> itemsList = list
        .map((i) => MenuItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return Category(id: json['id'], name: json['name'], menuItems: itemsList);
  }
}
