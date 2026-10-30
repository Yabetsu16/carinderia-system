import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // Add this import

import 'screens/cashier_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/kitchen_screen.dart';

void main() {
  usePathUrlStrategy(); // Cleans up the URL (removes #/)
  runApp(const CarinderiaApp());
}

class CarinderiaApp extends StatelessWidget {
  const CarinderiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carinderia Management System',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      // Inside your MaterialApp routing configuration:
      onGenerateRoute: (settings) {
        // Matches patterns like /menu/1 or /1/menu
        Uri uri = Uri.parse(settings.name ?? '/');

        if (uri.pathSegments.length == 2) {
          // e.g. /menu/1 -> segment 0 is 'menu', segment 1 is '1'
          int? tableNum = int.tryParse(uri.pathSegments[1]);
          if (tableNum != null && uri.pathSegments[0] == 'menu') {
            return MaterialPageRoute(
              builder: (context) => MenuScreen(tableNumber: tableNum),
            );
          }

          // Alternative format: /1/menu -> segment 0 is '1', segment 1 is 'menu'
          int? tableNumAlt = int.tryParse(uri.pathSegments[0]);
          if (tableNumAlt != null && uri.pathSegments[1] == 'menu') {
            return MaterialPageRoute(
              builder: (context) => MenuScreen(tableNumber: tableNumAlt),
            );
          }
        }

        // Fallback / standard routes
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const MenuScreen(tableNumber: 1),
            ); // Default table 1 if none specified
          case '/kitchen':
            return MaterialPageRoute(
              builder: (context) => const KitchenScreen(),
            );
          case '/cashier':
            return MaterialPageRoute(
              builder: (context) => const CashierScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) =>
                  const Scaffold(body: Center(child: Text('Page not found'))),
            );
        }
      },
    );
  }
}
