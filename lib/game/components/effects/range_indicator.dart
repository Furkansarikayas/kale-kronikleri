import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Pulsing range indicator shown when placing towers.
class RangeIndicator extends PositionComponent {
  final double range;
  double _pulse = 0;

  RangeIndicator({
    required Vector2 pos,
    required this.range,
  }) : super(position: pos.clone(), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 3;
    if (_pulse > 6.283) _pulse -= 6.283;
  }

  @override
  void render(Canvas canvas) {
    final pulseScale = 1.0 + 0.03 * (_pulse * 1.0).abs();
    final r = range * pulseScale;

    // Fill
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..color = const Color(0x15FFFFFF)
        ..style = PaintingStyle.fill,
    );
    // Border
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }
}
