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
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(child: _buildPage()),
        Material(
          elevation: 2,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Container(
          padding: EdgeInsets.only(top: 8, bottom: bottom + 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2,
                label: 'Productos',
              ),
              _NavItem(
                isSelected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Historial',
              ),
              _NavItem(
                isSelected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
                icon: Icons.info_outline_rounded,
                selectedIcon: Icons.info_rounded,
                label: 'Nosotros',
              ),
            ],
          ),
        ),
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

class _NavItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                isSelected ? selectedIcon : icon,
                size: 24,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
