import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/menu_item.dart';

class MenuGridView extends StatelessWidget {
  final Future<List<Category>> menuFuture;
  final Function(MenuItem) onAddToCart;

  const MenuGridView({
    super.key,
    required this.menuFuture,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: menuFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No active menu available today.'));
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                            ? () => onAddToCart(menuItem)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    );
  }
}
