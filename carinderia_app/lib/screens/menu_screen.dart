import 'dart:async';

import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/create_order_item.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/menu_grid_view.dart';
import '../widgets/cart_panel.dart';

class MenuScreen extends StatefulWidget {
  final int tableNumber;
  const MenuScreen({super.key, required this.tableNumber});

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

  // Add inside _MenuScreenState
  Timer? _statusPollingTimer;
  List<Order> _myActiveOrders = [];
  final Map<int, String> _lastKnownStatuses = {};

  @override
  void initState() {
    super.initState();
    _menuFuture = _apiService.getActiveMenu();
    _startOrderPolling();
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    super.dispose();
  }

  void _startOrderPolling() {
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      try {
        List<Order> orders = await _apiService.getActiveKitchenOrders();

        var tableOrders = orders
            .where((o) => o.tableNumber == _tableNumber)
            .toList();

        for (var order in tableOrders) {
          String oldStatus = _lastKnownStatuses[order.id] ?? '';

          if (oldStatus != order.status && order.status == 'Ready') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🎉 Order #${order.id} for Table #${order.tableNumber} is READY!',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
          _lastKnownStatuses[order.id] == order.status;
        }

        setState(() {
          _myActiveOrders = tableOrders;
        });
      } catch (e) {
        debugPrint('Error polling order statuses: $e');
      }
    });
  }

  void _showActiveOrdersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Table #$_tableNumber Orders'),
        content: SizedBox(
          width: 400,
          child: _myActiveOrders.isEmpty
              ? const Text('No active orders for this table.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _myActiveOrders.length,
                  itemBuilder: (context, index) {
                    final order = _myActiveOrders[index];
                    return ListTile(
                      title: Text(
                        'Order #${order.id} ₱${order.items.length} items',
                      ),
                      subtitle: Text('Status: ${order.status}'),
                      trailing: Chip(
                        label: Text(order.status),
                        backgroundColor: order.status == 'Ready'
                            ? Colors.green[800]
                            : Colors.orange[800],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
      tableNumber: widget.tableNumber,
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
            _paymentMethod == 1
                ? 'QR Order placed! Please show your payment confirmation to the cashier so it can be sent to the kitchen.'
                : 'Table #$_tableNumber order has been sent straight to the kitchen.',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carinderia Menu'),
        actions: [
          IconButton(
            icon: const Badge(
              label: Text('active'),
              child: Icon(Icons.receipt_long),
            ),
            onPressed: () => _showActiveOrdersDialog(),
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
