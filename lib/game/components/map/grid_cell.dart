import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/game_config.dart';

class GridCell extends RectangleComponent {
  final int col;
  final int row;
  final CellType cellType;
  bool highlighted = false;

  GridCell({
    required this.col,
    required this.row,
    required this.cellType,
    required double cellSize,
  }) : super(
    position: Vector2(col * cellSize, row * cellSize),
    size: Vector2.all(cellSize),
    paint: Paint()..color = _colorFor(cellType, col, row),
  );

  static Color _colorFor(CellType type, int col, int row) {
    // Add subtle variation based on position for natural look
    final variation = ((col * 7 + row * 13) % 5) * 3;
    switch (type) {
      case CellType.path:
        return Color.fromARGB(255, 107 + variation, 90 + variation, 62);
      case CellType.buildable:
        final green = 109 + variation;
        return Color.fromARGB(255, 59 - (variation ~/ 2), green.clamp(0, 255), 17);
      case CellType.blocked:
        return Color.fromARGB(255, 85 + variation, 85 + variation, 85 + variation);
      case CellType.castle:
        return const Color(0xFFBA7517);
      case CellType.spawn:
        return const Color(0xFF8B2020);
      case CellType.pathBuildable:
        return Color.fromARGB(255, 122 + variation, 107 + variation, 78);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Placement highlight
    if (highlighted) {
      canvas.drawRect(
        Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
        Paint()
          ..color = const Color(0x3300FF00)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
        Paint()
          ..color = const Color(0x6600FF00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Grid line (subtle)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..color = const Color(0x0AFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Spawn point marker
    if (cellType == CellType.spawn) {
      final center = Offset(size.x / 2, size.y / 2);
      // Arrow pointing right
      final arrowPaint = Paint()
        ..color = const Color(0xAAFF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(center.dx - size.x * 0.2, center.dy),
        Offset(center.dx + size.x * 0.2, center.dy),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(center.dx + size.x * 0.1, center.dy - size.y * 0.15),
        Offset(center.dx + size.x * 0.2, center.dy),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(center.dx + size.x * 0.1, center.dy + size.y * 0.15),
        Offset(center.dx + size.x * 0.2, center.dy),
        arrowPaint,
      );
    }

    // Buildable tile: subtle grass dot pattern
    if (cellType == CellType.buildable) {
      final rng = math.Random(col * 100 + row);
      final dotPaint = Paint()..color = const Color(0x1500FF00);
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(rng.nextDouble() * size.x, rng.nextDouble() * size.y),
          1.0,
          dotPaint,
        );
      }
    }

    // Path buildable: diagonal lines to indicate spike wall placement
    if (cellType == CellType.pathBuildable) {
      final linePaint = Paint()
        ..color = const Color(0x15FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawLine(Offset(0, size.y), Offset(size.x, 0), linePaint);
    }
  }
}
