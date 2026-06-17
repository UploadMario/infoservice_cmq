import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;

  const CustomAppBar({super.key, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Image.asset('assets/icono.png', height: 36),
      centerTitle: false,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
