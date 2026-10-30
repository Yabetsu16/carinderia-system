import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carinderia_app/screens/menu_screen.dart';

void main() {
  testWidgets('MenuScreen displays title, table number, and empty cart', (
    WidgetTester tester,
  ) async {
    // Build MenuScreen passing the required tableNumber parameter
    await tester.pumpWidget(
      const MaterialApp(home: MenuScreen(tableNumber: 1)),
    );

    // Verify that the AppBar title is displayed.
    expect(find.text('Carinderia Menu'), findsOneWidget);

    // Verify that the table number is reflected in the UI or app bar (if displayed)
    // If you display the table number in the title/subtitle, verify it here:
    expect(find.textContaining('Table #1'), findsWidgets);

    // Verify that the empty cart state message is shown initially.
    expect(find.text('Your cart is empty'), findsOneWidget);
  });
}
