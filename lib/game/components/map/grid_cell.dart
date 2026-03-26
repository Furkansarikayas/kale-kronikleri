import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/game_config.dart';
import '../../rendering/sprite_cache.dart';

class GridCell extends RectangleComponent {
  final int col;
  final int row;
  final CellType cellType;
  bool highlighted = false;

  // Neighbor types for edge blending
  CellType _nTop = CellType.blocked;
  CellType _nBottom = CellType.blocked;
  CellType _nLeft = CellType.blocked;
  CellType _nRight = CellType.blocked;

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

  void setNeighbors({
    required CellType top,
    required CellType bottom,
    required CellType left,
    required CellType right,
  }) {
    _nTop = top;
    _nBottom = bottom;
    _nLeft = left;
    _nRight = right;
  }

  // --- Helpers ---
  bool _isGround(CellType t) => t == CellType.buildable;

  /// Reusable paint for drawing sprites (no allocations per frame).
  /// Medium filter quality for smooth downscaling from 128x128 to 40x40.
  static final Paint _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  /// Reusable paint for the pathBuildable overlay tint.
  static final Paint _pathBuildableOverlay = Paint()
    ..color = const Color(0x1800FF44);

  @override
  void render(Canvas canvas) {
    final s = size.x;
    final rect = Rect.fromLTWH(0, 0, s, s);
    final cache = SpriteCache.instance;

    if (!cache.isInitialized) {
      _renderFallback(canvas, rect);
    } else {
      _renderSprite(canvas, s, cache);
    }

    // Highlight on top of everything (always Canvas-drawn)
    if (highlighted) {
      _renderHighlight(canvas, s, rect);
    }
  }

  // ================================================================
  //  SPRITE-BASED RENDERING
  // ================================================================
  void _renderSprite(Canvas canvas, double s, SpriteCache cache) {
    switch (cellType) {
      case CellType.buildable:
        _drawBuildable(canvas, s, cache);
        break;
      case CellType.path:
        _drawPath(canvas, s, cache);
        break;
      case CellType.pathBuildable:
        _drawPathBuildable(canvas, s, cache);
        break;
      case CellType.blocked:
        _drawBlocked(canvas, s, cache);
        break;
      case CellType.spawn:
        _drawSpawn(canvas, s, cache);
        break;
      case CellType.castle:
        _drawCastleGround(canvas, s, cache);
        break;
    }

    // Terrain edge shadows only where different types meet
    _drawTerrainEdgeShadows(canvas, s);
  }

  /// Draws soft shadow edges ONLY where different terrain types meet.
  /// Same-type neighbors get no edge treatment (seamless).
  static final Paint _edgeShadowPaint = Paint();

  bool _isDarker(CellType t) => t == CellType.blocked;
  bool _isPath(CellType t) => t == CellType.path || t == CellType.pathBuildable;

  void _drawTerrainEdgeShadows(Canvas canvas, double s) {
    const w = 3.5;

    // Grass bordering blocked → subtle shadow from forest
    if (cellType == CellType.buildable || _isPath(cellType)) {
      if (_isDarker(_nTop)) {
        canvas.drawRect(Rect.fromLTWH(0, 0, s, w),
            _edgeShadowPaint..color = const Color(0x14000000));
      }
      if (_isDarker(_nBottom)) {
        canvas.drawRect(Rect.fromLTWH(0, s - w, s, w),
            _edgeShadowPaint..color = const Color(0x14000000));
      }
      if (_isDarker(_nLeft)) {
        canvas.drawRect(Rect.fromLTWH(0, 0, w, s),
            _edgeShadowPaint..color = const Color(0x14000000));
      }
      if (_isDarker(_nRight)) {
        canvas.drawRect(Rect.fromLTWH(s - w, 0, w, s),
            _edgeShadowPaint..color = const Color(0x14000000));
      }
    }

    // Blocked bordering grass → subtle green light spill
    if (_isDarker(cellType)) {
      if (_isGround(_nTop) || _isPath(_nTop)) {
        canvas.drawRect(Rect.fromLTWH(0, 0, s, w * 1.5),
            _edgeShadowPaint..color = const Color(0x0A2A6A18));
      }
      if (_isGround(_nBottom) || _isPath(_nBottom)) {
        canvas.drawRect(Rect.fromLTWH(0, s - w * 1.5, s, w * 1.5),
            _edgeShadowPaint..color = const Color(0x0A2A6A18));
      }
      if (_isGround(_nLeft) || _isPath(_nLeft)) {
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 1.5, s),
            _edgeShadowPaint..color = const Color(0x0A2A6A18));
      }
      if (_isGround(_nRight) || _isPath(_nRight)) {
        canvas.drawRect(Rect.fromLTWH(s - w * 1.5, 0, w * 1.5, s),
            _edgeShadowPaint..color = const Color(0x0A2A6A18));
      }
    }
  }

  // ----------------------------------------------------------------
  //  Buildable (grass) -- 6 variants
  // ----------------------------------------------------------------
  void _drawBuildable(Canvas canvas, double s, SpriteCache cache) {
    final variant = (col * 7 + row * 13) % 6;
    final image = cache.getTile('grass_$variant');
    if (image != null) {
      _blitImage(canvas, image, s);
    } else {
      _fillColor(canvas, s, const Color(0xFF3AAF28));
    }
  }

  // ----------------------------------------------------------------
  //  Path -- 4 variants + edge overlays
  // ----------------------------------------------------------------
  void _drawPath(Canvas canvas, double s, SpriteCache cache) {
    final variant = (col * 3 + row * 11) % 4;
    final image = cache.getTile('path_$variant');
    if (image != null) {
      _blitImage(canvas, image, s);
    } else {
      _fillColor(canvas, s, const Color(0xFF9B7D4B));
    }
    _drawPathEdges(canvas, s, cache);
  }

  // ----------------------------------------------------------------
  //  PathBuildable -- path sprite + subtle green overlay
  // ----------------------------------------------------------------
  void _drawPathBuildable(Canvas canvas, double s, SpriteCache cache) {
    // Draw the base path tile first
    final variant = (col * 3 + row * 11) % 4;
    final image = cache.getTile('path_$variant');
    if (image != null) {
      _blitImage(canvas, image, s);
    } else {
      _fillColor(canvas, s, const Color(0xFF9B7D4B));
    }
    _drawPathEdges(canvas, s, cache);

    // Subtle green tint overlay to distinguish from pure path
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), _pathBuildableOverlay);
  }

  // ----------------------------------------------------------------
  //  Blocked (rocks / forest) -- 4 variants
  // ----------------------------------------------------------------
  void _drawBlocked(Canvas canvas, double s, SpriteCache cache) {
    final variant = (col * 3 + row * 7) % 4;
    final image = cache.getTile('blocked_$variant');
    if (image != null) {
      _blitImage(canvas, image, s);
    } else {
      _fillColor(canvas, s, const Color(0xFF2B3A1E));
    }
  }

  // ----------------------------------------------------------------
  //  Spawn
  // ----------------------------------------------------------------
  void _drawSpawn(Canvas canvas, double s, SpriteCache cache) {
    final image = cache.getTile('spawn');
    if (image != null) {
      _blitImage(canvas, image, s);
    } else {
      _fillColor(canvas, s, const Color(0xFF992222));
    }
  }

  // ----------------------------------------------------------------
  //  Castle ground
  // ----------------------------------------------------------------
  void _drawCastleGround(Canvas canvas, double s, SpriteCache cache) {
    final image = cache.getTile('castle_ground');
    if (image != null) {
      _blitImage(canvas, image, s);
    } else {
      _fillColor(canvas, s, const Color(0xFF555577));
    }
  }

  // ----------------------------------------------------------------
  //  Path edge overlays -- grass-to-path transitions
  // ----------------------------------------------------------------
  void _drawPathEdges(Canvas canvas, double s, SpriteCache cache) {
    // Draw edge overlay sprites on sides that border grass (buildable)
    if (_isGround(_nTop)) {
      final edge = cache.getTile('path_edge_top');
      if (edge != null) _blitImage(canvas, edge, s);
    }
    if (_isGround(_nBottom)) {
      final edge = cache.getTile('path_edge_bottom');
      if (edge != null) _blitImage(canvas, edge, s);
    }
    if (_isGround(_nLeft)) {
      final edge = cache.getTile('path_edge_left');
      if (edge != null) _blitImage(canvas, edge, s);
    }
    if (_isGround(_nRight)) {
      final edge = cache.getTile('path_edge_right');
      if (edge != null) _blitImage(canvas, edge, s);
    }
  }

  // ================================================================
  //  IMAGE DRAWING HELPER
  // ================================================================
  /// Draws [image] scaled from its native size (e.g. 80x80) to the cell
  /// size [s] x [s] using drawImageRect for efficient GPU scaling.
  void _blitImage(Canvas canvas, ui.Image image, double s) {
    final src = Rect.fromLTWH(
      0, 0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, s, s);
    canvas.drawImageRect(image, src, dst, _spritePaint);
  }

  // ================================================================
  //  FLAT COLOR FALLBACK
  // ================================================================
  void _renderFallback(Canvas canvas, Rect rect) {
    final Color color;
    switch (cellType) {
      case CellType.buildable:
        color = const Color(0xFF3AAF28);
        break;
      case CellType.path:
        color = const Color(0xFF9B7D4B);
        break;
      case CellType.pathBuildable:
        color = const Color(0xFF8B7D3B);
        break;
      case CellType.blocked:
        color = const Color(0xFF2B3A1E);
        break;
      case CellType.spawn:
        color = const Color(0xFF992222);
        break;
      case CellType.castle:
        color = const Color(0xFF555577);
        break;
    }
    canvas.drawRect(rect, Paint()..color = color);
  }

  // ================================================================
  //  PLACEMENT HIGHLIGHT - glowing green radial (Canvas-drawn)
  // ================================================================
  void _renderHighlight(Canvas canvas, double s, Rect rect) {
    final highlightGrad = ui.Gradient.radial(
      Offset(s * 0.5, s * 0.5),
      s * 0.65,
      [
        const Color(0x5500FF44),
        const Color(0x3300CC33),
        const Color(0x1100AA22),
        const Color(0x00008800),
      ],
      [0.0, 0.4, 0.7, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = highlightGrad);

    canvas.drawCircle(
      Offset(s * 0.5, s * 0.5), s * 0.3,
      Paint()..color = const Color(0x2200FF66),
    );

    canvas.drawRect(
      Rect.fromLTWH(1, 1, s - 2, s - 2),
      Paint()
        ..color = const Color(0xAA00FF44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x3300FF33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  /// Helper to fill the cell with a flat color.
  void _fillColor(Canvas canvas, double s, Color color) {
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = color);
  }
}
