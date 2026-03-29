import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/game_config.dart';

/// Grid cell component for tap detection and placement highlight.
///
/// Ground rendering is handled by [MapGroundLayer].
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
          paint: Paint()..color = const Color(0x00000000),
        );

  @override
  void render(Canvas canvas) {
    if (highlighted) {
      final s = size.x;
      final rect = Rect.fromLTWH(0, 0, s, s);

      final highlightGrad = ui.Gradient.radial(
        Offset(s * 0.5, s * 0.5),
        s * 0.65,
        [
          const Color(0x3300FF44),
          const Color(0x2200CC33),
          const Color(0x0A00AA22),
          const Color(0x00008800),
        ],
        [0.0, 0.4, 0.7, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = highlightGrad);

      canvas.drawCircle(
        Offset(s * 0.5, s * 0.5),
        s * 0.3,
        Paint()..color = const Color(0x1800FF66),
      );

      canvas.drawRect(
        Rect.fromLTWH(1, 1, s - 2, s - 2),
        Paint()
          ..color = const Color(0x3300FF44)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }
}
