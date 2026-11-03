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

  Route<dynamic> _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    if (uri.pathSegments.length == 2) {
      int? tableNum = int.tryParse(uri.pathSegments[1]);

      if (tableNum != null && uri.pathSegments[0] == 'menu') {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => MenuScreen(tableNumber: tableNum),
        );
      }

      int? tableNumAlt = int.tryParse(uri.pathSegments[0]);

      if (tableNumAlt != null && uri.pathSegments[1] == 'menu') {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => MenuScreen(tableNumber: tableNumAlt),
        );
      }
    }

    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const MenuScreen(tableNumber: 1),
        );

      case '/kitchen':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const KitchenScreen(),
        );

      case '/cashier':
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const CashierScreen(),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carinderia Management System',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,

      // Generate only the requested initial route.
      onGenerateInitialRoutes: (initialRoute) {
        return [_generateRoute(RouteSettings(name: initialRoute))];
      },

      onGenerateRoute: _generateRoute,
    );
  }
}
