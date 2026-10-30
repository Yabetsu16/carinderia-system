import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/create_order_item.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';

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
          // Left Side: Menu Grid / Categories
          Expanded(
            flex: 3,
            child: FutureBuilder<List<Category>>(
              future: _menuFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No active menu available today.'),
                  );
                }

                final categories = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, catIndex) {
                    final category = categories[catIndex];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 3 / 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: category.menuItems.length,
                          itemBuilder: (context, itemIndex) {
                            final menuItem = category.menuItems[itemIndex];
                            return Card(
                              elevation: 2,
                              child: InkWell(
                                onTap: menuItem.isAvailableToday
                                    ? () => _addToCart(menuItem)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        menuItem.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: menuItem.isAvailableToday
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '₱${menuItem.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                      if (!menuItem.isAvailableToday)
                                        const Text(
                                          'Sold Out',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Right Side: Current Cart & Checkout Panel
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black12,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Current Order',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Your cart is empty'))
                        : ListView(
                            children: _cart.values.map((cartItem) {
                              return ListTile(
                                title: Text(cartItem.menuItem.name),
                                subtitle: Text(
                                  '₱${cartItem.totalPrice.toStringAsFixed(2)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      onPressed: () =>
                                          _removeFromCart(cartItem.menuItem.id),
                                    ),
                                    Text(
                                      '${cartItem.quantity}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      onPressed: () =>
                                          _addToCart(cartItem.menuItem),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const Divider(),

                  // Total Amount
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₱${_cartTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Payment Method Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Cash'),
                        selected: _paymentMethod == 0,
                        onSelected: (selected) =>
                            setState(() => _paymentMethod = 0),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('QR Code'),
                        selected: _paymentMethod == 1,
                        onSelected: (selected) =>
                            setState(() => _paymentMethod = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: ChoiceChip(
                            label: const Text('Cash'),
                            selected: _paymentMethod == 0,
                            onSelected: (selected) =>
                                setState(() => _paymentMethod = 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Center(
                          child: ChoiceChip(
                            label: const Text('QR Code'),
                            selected: _paymentMethod == 1,
                            onSelected: (selected) =>
                                setState(() => _paymentMethod = 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: (_isSubmitting || _cart.isEmpty)
                        ? null
                        : _submitOrder,
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Place Order (Send to Kitchen)',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
