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

  void _showQrPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Scan QR Code to Pay',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total Amount: ₱${cartTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/my_qr_code.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please scan using your e-wallet and show the payment confirmation to the counter staff.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () {
              Navigator.of(ctx).pop();
              onSubmitOrder(); // Submits order to backend
            },
            child: const Text(
              'Place Order',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

          // Dynamic Action Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: (isSubmitting || cart.isEmpty)
                ? null
                : () {
                    if (paymentMethod == 1) {
                      _showQrPaymentDialog(context);
                    } else {
                      onSubmitOrder();
                    }
                  },
            child: isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    paymentMethod == 1
                        ? 'Pay with QR Code'
                        : 'Place Order (Send to Kitchen)',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
