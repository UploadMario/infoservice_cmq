import 'package:flutter/material.dart';
import 'logo_widget.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;

  const CustomAppBar({super.key, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const LogoWidget(size: 32),
      centerTitle: true,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
