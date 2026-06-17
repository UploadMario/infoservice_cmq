import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key, this.size = 120, this.backgroundColor});

  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF165DFF),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      padding: EdgeInsets.all(size * 0.15),
      child: Image.asset(
        'assets/logo blanco roboto.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
