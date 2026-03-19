import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/game_config.dart';

class GridCell extends RectangleComponent {
  final int col;
  final int row;
  final CellType cellType;

  GridCell({
    required this.col,
    required this.row,
    required this.cellType,
    required double cellSize,
  }) : super(
    // Rows along x-axis (short), cols along y-axis (long) for landscape
    position: Vector2(row * cellSize, col * cellSize),
    size: Vector2.all(cellSize),
    paint: Paint()..color = _colorFor(cellType),
  );

  static Color _colorFor(CellType type) {
    switch (type) {
      case CellType.path: return const Color(0xFF6B5A3E);
      case CellType.buildable: return const Color(0xFF3B6D11);
      case CellType.blocked: return const Color(0xFF555555);
      case CellType.castle: return const Color(0xFFBA7517);
      case CellType.spawn: return const Color(0xFF8B2020);
      case CellType.pathBuildable: return const Color(0xFF7A6B4E);
    }
  }
}
