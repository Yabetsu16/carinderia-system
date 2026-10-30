import 'package:carinderia_app/models/menu_item.dart';
import 'package:flutter/material.dart';

import '../models/cart_item.dart';

class CartPanel extends StatelessWidget {
  final Map<int, CartItem> cart;
  final double cartTotal;
  final int paymentMethod;
  final bool isSubmitting;
  final Function(MenuItem) onIncrement;
  final Function(int) onDecrement;
  final Function(int) onPaymentChanged;
  final VoidCallback onSubmitOrder;

  const CartPanel({
    super.key,
    required this.cart,
    required this.cartTotal,
    required this.paymentMethod,
    required this.isSubmitting,
    required this.onIncrement,
    required this.onDecrement,
    required this.onPaymentChanged,
    required this.onSubmitOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: cart.isEmpty
                ? const Center(child: Text('Your cart is empty'))
                : ListView(
                    children: cart.values.map((cartItem) {
                      return ListTile(
                        title: Text(cartItem.menuItem.name),
                        subtitle: Text(
                          '₱${cartItem.totalPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  onDecrement(cartItem.menuItem.id),
                            ),
                            Text(
                              '${cartItem.quantity}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => onIncrement(cartItem.menuItem),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const Divider(),

          // Total Amount Display
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Total Amount:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '₱${cartTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ),

          // Clean Payment Method Selector (Fixed overflow & duplication)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Cash')),
                  selected: paymentMethod == 0,
                  onSelected: (selected) => onPaymentChanged(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('QR Code')),
                  selected: paymentMethod == 1,
                  onSelected: (selected) => onPaymentChanged(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Place Order Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: (isSubmitting || cart.isEmpty) ? null : onSubmitOrder,
            child: isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Place Order (Send to Kitchen)',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
