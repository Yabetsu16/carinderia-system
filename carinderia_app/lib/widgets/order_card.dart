import 'package:flutter/material.dart';

import '../models/order.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final Function(int orderId, String newStatus) onStatusChanged;

  const OrderCard({
    super.key,
    required this.order,
    required this.onStatusChanged,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orangeAccent;
      case 'preparing':
        return Colors.blueAccent;
      case 'ready':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Table Number & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Table #${order.tableNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order.status)),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            // Order Items List
            Expanded(
              child: ListView.builder(
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${item.quantity}x ${item.menuItemName}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.specialInstruction != null &&
                            item.specialInstruction!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0, top: 2),
                            child: Text(
                              'Note: ${item.specialInstruction}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),

            // Action Buttons based on current status
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (order.status.toLowerCase() == 'pending')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: () => onStatusChanged(order.id, 'Preparing'),
                    icon: const Icon(Icons.restaurant, color: Colors.white),
                    label: const Text(
                      'Start Prep',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (order.status.toLowerCase() == 'preparing')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => onStatusChanged(order.id, 'Ready'),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'Mark Ready',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (order.status.toLowerCase() == 'ready')
                  OutlinedButton(
                    onPressed: () => onStatusChanged(order.id, 'Completed'),
                    child: const Text('Complete / Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
