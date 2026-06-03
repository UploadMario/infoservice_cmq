import 'package:flutter/material.dart';
import 'package:infoservice_cmq/features/products/presentation/products_screen.dart';
import 'package:infoservice_cmq/features/cart/presentation/purchase_history_screen.dart';
import 'package:infoservice_cmq/features/about/presentation/about_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildPage()),
        NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Productos',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.info_outline_rounded),
              selectedIcon: Icon(Icons.info_rounded),
              label: 'Nosotros',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPage() {
    switch (_currentIndex) {
      case 0:
        return const ProductsScreen();
      case 1:
        return const PurchaseHistoryScreen();
      case 2:
        return const AboutScreen();
      default:
        return const ProductsScreen();
    }
  }
}
