import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carinderia_app/models/category.dart';
import 'package:carinderia_app/models/menu_item.dart';
import 'package:carinderia_app/models/cart_item.dart';
import 'package:carinderia_app/widgets/menu_grid_view.dart';
import 'package:carinderia_app/widgets/cart_panel.dart';

void main() {
  group('MenuGridView Widget Tests', () {
    testWidgets('Displays loading indicator when menu future is waiting', (
      WidgetTester tester,
    ) async {
      // Arrange: create a future that doesn't complete immediately
      final futureController = Future<List<Category>>.value([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuGridView(
              menuFuture: futureController,
              onAddToCart: (_) {},
            ),
          ),
        ),
      );

      // We let the future resolve, or check loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Displays categories and menu items when data loads', (
      WidgetTester tester,
    ) async {
      final mockCategories = [
        Category(
          id: 1,
          name: 'Main Dish',
          menuItems: [
            MenuItem(
              id: 101,
              categoryId: 1,
              name: 'Adobo',
              price: 95.0,
              isAvailableToday: true,
            ),
            MenuItem(
              id: 102,
              categoryId: 1,
              name: 'Sinigang',
              price: 110.0,
              isAvailableToday: false,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuGridView(
              menuFuture: Future.value(mockCategories),
              onAddToCart: (_) {},
            ),
          ),
        ),
      );

      // Allow the future to complete and rebuild
      await tester.pumpAndSettle();

      // Assert categories and items are rendered
      expect(find.text('Main Dish'), findsOneWidget);
      expect(find.text('Adobo'), findsOneWidget);
      expect(find.text('Sinigang'), findsOneWidget);
      expect(find.text('₱95.00'), findsOneWidget);
      expect(find.text('Sold Out'), findsOneWidget);
    });
  });

  group('CartPanel Widget Tests', () {
    testWidgets('Displays empty cart message when cart is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartPanel(
              cart: const {},
              cartTotal: 0.0,
              paymentMethod: 0,
              isSubmitting: false,
              onIncrement: (_) {},
              onDecrement: (_) {},
              onPaymentChanged: (_) {},
              onSubmitOrder: () {},
            ),
          ),
        ),
      );

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('₱0.00'), findsOneWidget);
    });

    testWidgets('Displays cart items, total amount, and triggers actions', (
      WidgetTester tester,
    ) async {
      final mockCart = {
        101: CartItem(
          menuItem: MenuItem(
            id: 101,
            categoryId: 1,
            name: 'Adobo',
            price: 95.0,
            isAvailableToday: true,
          ),
          quantity: 2,
        ),
      };

      bool orderSubmitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartPanel(
              cart: mockCart,
              cartTotal: 190.0,
              paymentMethod: 0,
              isSubmitting: false,
              onIncrement: (_) {},
              onDecrement: (_) {},
              onPaymentChanged: (_) {},
              onSubmitOrder: () {
                orderSubmitted = true;
              },
            ),
          ),
        ),
      );

      // Verify cart item details
      expect(find.text('Adobo'), findsOneWidget);
      expect(find.text('₱190.00'), findsNWidgets(2)); // Both item subtotal and grand total match/ Grand total display/ Grand total display

      // Tap Place Order button
      await tester.tap(find.text('Place Order (Send to Kitchen)'));
      expect(orderSubmitted, isTrue);
    });
  });
}
