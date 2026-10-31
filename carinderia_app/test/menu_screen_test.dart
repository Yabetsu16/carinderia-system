import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carinderia_app/screens/menu_screen.dart';

void main() {
  testWidgets('MenuScreen displays title, table number, and empty cart', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    // Reset the view bounds after the test completes
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build MenuScreen passing the required tableNumber parameter
    await tester.pumpWidget(
      const MaterialApp(home: MenuScreen(tableNumber: 1)),
    );

    // Verify that the AppBar title is displayed.
    expect(find.text('Carinderia Menu'), findsOneWidget);

    // Verify that the table number is reflected in the UI
    expect(find.textContaining('Table #1'), findsWidgets);

    // Verify that the empty cart state message is shown initially.
    expect(find.text('Your cart is empty'), findsOneWidget);
  });
}
