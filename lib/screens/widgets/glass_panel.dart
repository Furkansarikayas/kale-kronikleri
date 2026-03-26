import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color borderColor;
  final double blur;

  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 12,
    this.borderColor = const Color(0x33D4A843),
    this.blur = 10,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xAA0D0D15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
