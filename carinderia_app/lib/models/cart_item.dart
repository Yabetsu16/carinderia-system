import 'package:carinderia_app/models/menu_item.dart';

class CartItem {
  final MenuItem menuItem;
  int quantity;
  String specialInstruction;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.specialInstruction = '',
  });

  double get totalPrice => menuItem.price * quantity;
}
