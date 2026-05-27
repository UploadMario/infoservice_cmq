import 'package:flutter/material.dart';
import '../data/cart_service.dart';

class CartBadgeIcon extends StatelessWidget {
  final VoidCallback onTap;

  const CartBadgeIcon({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.itemCount;
        return IconButton(
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          onPressed: onTap,
        );
      },
    );
  }
}
