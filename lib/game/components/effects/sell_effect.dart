import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Brief dissolve effect when a tower is sold.
/// Contracting ring + gold center flash + rising gold dust.
class SellEffect extends PositionComponent {
  final Color _color;
  final double _cellSize;
  double _life;
  static const double _maxLife = 0.3;

  // Cached paints — single-threaded render, safe to reuse
  static final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _flashPaint = Paint();
  static final Paint _dustPaint = Paint();

  SellEffect({
    required Vector2 pos,
    required double cellSize,
    required Color color,
  })  : _color = color,
        _cellSize = cellSize,
        _life = _maxLife,
        super(position: pos, anchor: Anchor.topLeft);

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _maxLife).clamp(0.0, 1.0); // 1→0
    final progress = 1.0 - t; // 0→1
    final cx = _cellSize / 2;
    final cy = _cellSize / 2;

    // Contracting ring (starts wide, shrinks inward)
    final ringRadius = _cellSize * (0.7 - 0.5 * progress);
    final ringAlpha = (t * 150).round().clamp(0, 255);
    _ringPaint.color = _color.withAlpha(ringAlpha);
    _ringPaint.strokeWidth = 2.0 * t;
    canvas.drawCircle(Offset(cx, cy), ringRadius, _ringPaint);

    // Gold center flash (fades quickly)
    if (t > 0.4) {
      final flashT = (t - 0.4) / 0.6;
      final flashAlpha = (flashT * 100).round().clamp(0, 255);
      _flashPaint.color = Color.fromARGB(flashAlpha, 255, 215, 50);
      canvas.drawCircle(
        Offset(cx, cy), _cellSize * 0.25 * flashT, _flashPaint,
      );
    }

    // Rising gold dust (3 small dots drifting up)
    for (int i = 0; i < 3; i++) {
      final dustX = cx + (i - 1) * _cellSize * 0.2;
      final dustY = cy - progress * _cellSize * 0.6 - i * 4;
      final dustAlpha = (t * 180).round().clamp(0, 255);
      _dustPaint.color = Color.fromARGB(dustAlpha, 255, 220, 80);
      canvas.drawCircle(Offset(dustX, dustY), 1.8 * t, _dustPaint);
    }
  }
}
