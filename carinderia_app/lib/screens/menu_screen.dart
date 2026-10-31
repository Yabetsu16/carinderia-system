import 'dart:async';

import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/create_order_item.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
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
  int _paymentMethod = 0; // 0 = Cash, 1 = QRCode
  bool _isSubmitting = false;

  // SignalR & Active Orders State
  late SignalRService _signalRService;
  List<Order> _myActiveOrders = [];

  @override
  void initState() {
    super.initState();
    _menuFuture = _apiService.getActiveMenu();
    _initSignalR();
    _fetchInitialOrders();
  }

  @override
  void dispose() {
    _signalRService.disconnect();
    super.dispose();
  }

  Future<void> _initSignalR() async {
    _signalRService = SignalRService();

    // Connect and bind the listener simultaneously before the handshake finishes
    await _signalRService.connect(
      ApiService.serverRootUrl,
      onOrderUpdate: (arguments) {
        debugPrint("SignalR RAW callback fired! Arguments: $arguments");
        if (mounted) {
          _fetchInitialOrders(); // Instantly refresh UI when broadcast hits
        }
      },
    );
  }

  Future<void> _fetchInitialOrders() async {
    try {
      // Fetch orders specifically for this table using the new method
      List<Order> tableOrders = await _apiService.getTableOrders(
        widget.tableNumber,
      );

      setState(() {
        _myActiveOrders = tableOrders
            .where((o) => o.status != 'Completed')
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching table orders: $e');
    }
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
                ? 'QR Order placed! Please show your payment confirmation to the cashier.'
                : 'Table #${widget.tableNumber} order has been sent straight to the kitchen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _cart.clear());
                _fetchInitialOrders();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Widget to render persistent live status cards for active orders
  Widget _buildActiveOrdersStatusWidget() {
    if (_myActiveOrders.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.shade900.withValues(alpha: .25)
            : Colors.orange.shade50,
        border: Border.all(
          color: isDark ? Colors.orange.shade700 : Colors.orange.shade300,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_filled,
                color: isDark ? Colors.orangeAccent : Colors.deepOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Live Order Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.orangeAccent : Colors.deepOrange,
                ),
              ),
            ],
          ),
          Divider(
            height: 12,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
          ..._myActiveOrders.map((order) {
            Color statusColor = Colors.orange;
            String statusText = order.status;

            if (order.status == 'Ready') {
              statusColor = Colors.green.shade600;
              statusText = '🎉 READY FOR PICKUP!';
            } else if (order.status == 'Preparing') {
              statusColor = Colors.blue.shade600;
              statusText = '👨‍🍳 Preparing in Kitchen';
            } else if (order.status == 'PendingPayment') {
              statusColor = Colors.amber.shade800;
              statusText = '⏳ Awaiting Cashier Payment';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id} (${order.items.length} items)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  Chip(
                    label: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: statusColor,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Carinderia Menu - Table #${widget.tableNumber}'),
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
          // Right Side: Persistent Status Widget + Cart & Checkout Panel
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildActiveOrdersStatusWidget(), // Pinned live status container
                Expanded(
                  child: CartPanel(
                    cart: _cart,
                    cartTotal: _cartTotal,
                    paymentMethod: _paymentMethod,
                    isSubmitting: _isSubmitting,
                    onIncrement: _addToCart,
                    onDecrement: _removeFromCart,
                    onPaymentChanged: (val) =>
                        setState(() => _paymentMethod = val),
                    onSubmitOrder: _submitOrder,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
