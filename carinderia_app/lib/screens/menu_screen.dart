import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/create_order_item.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';
import '../widgets/menu_grid_view.dart';
import '../widgets/cart_panel.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Category>> _menuFuture;

  // Local Cart State
  final Map<int, CartItem> _cart = {};
  int _tableNumber = 1;
  int _paymentMethod = 0; // 0 = Cash, 1 = QRCode
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _menuFuture = _apiService.getActiveMenu();
  }

  void _addToCart(MenuItem item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.quantity++;
      } else {
        _cart[item.id] = CartItem(menuItem: item);
      }
    });
  }

  void _removeFromCart(int itemId) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        if (_cart[itemId]!.quantity > 1) {
          _cart[itemId]!.quantity--;
        } else {
          _cart.remove(itemId);
        }
      }
    });
  }

  double get _cartTotal {
    return _cart.values.fold(0, (sum, item) => sum + item.totalPrice);
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) return;

    setState(() => _isSubmitting = true);

    final List<CreateOrderItem> itemsPayload = _cart.values.map((cartItem) {
      return CreateOrderItem(
        menuItemId: cartItem.menuItem.id,
        quantity: cartItem.quantity,
        specialInstruction: cartItem.specialInstruction,
      );
    }).toList();

    bool success = await _apiService.placeOrder(
      tableNumber: _tableNumber,
      paymentMethod: _paymentMethod,
      items: itemsPayload,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Order Placed Successfully!'),
          content: Text(
            'Table #$_tableNumber order has been sent straight to the kitchen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _cart.clear());
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to submit order. Please check backend connection.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karenderya Menu'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: DropdownButton<int>(
                value: _tableNumber,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                items: List.generate(10, (index) => index + 1)
                    .map(
                      (table) => DropdownMenuItem(
                        value: table,
                        child: Text('Table $table'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _tableNumber = val ?? 1),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Side: Menu Grid
          Expanded(
            flex: 3,
            child: MenuGridView(
              menuFuture: _menuFuture,
              onAddToCart: _addToCart,
            ),
          ),

          // Right Side: Cart & Checkout Panel
          Expanded(
            flex: 2,
            child: CartPanel(
              cart: _cart,
              cartTotal: _cartTotal,
              paymentMethod: _paymentMethod,
              isSubmitting: _isSubmitting,
              onIncrement: _addToCart,
              onDecrement: _removeFromCart,
              onPaymentChanged: (val) => setState(() => _paymentMethod = val),
              onSubmitOrder: _submitOrder,
            ),
          ),
        ],
      ),
    );
  }
}
