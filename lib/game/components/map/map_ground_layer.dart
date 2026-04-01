import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/game_config.dart';
import '../../rendering/sprite_cache.dart';

bool _isPathLike(CellType t) =>
    t == CellType.path || t == CellType.pathBuildable || t == CellType.spawn;

/// Renders the entire map ground as a single pre-rendered canvas.
///
/// Replaces per-cell ground rendering with seamless texture tiling,
/// terrain transitions, and atmospheric effects. The ground is rendered
/// once to a cached image and blitted each frame.
class MapGroundLayer extends PositionComponent {
  final List<List<CellType>> grid;
  final double cellSize;

  ui.Image? _cached;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.medium;
  double _time = 0;

  // Padding to extend grass beyond grid (covers ultrawide screens)
  static const double _padL = 350.0;
  static const double _padR = 350.0;
  static const double _padT = 110.0;
  static const double _padB = 110.0;

  MapGroundLayer({required this.grid, required this.cellSize}) {
    priority = -1;
  }

  @override
  Future<void> onLoad() async {
    final cache = SpriteCache.instance;
    if (cache.isInitialized) {
      await _buildCache(cache);
    }
  }

  Future<void> _buildCache(SpriteCache cache) async {
    final cols = GameConfig.gridColumns;
    final rows = GameConfig.gridRows;
    final mapW = cols * cellSize;
    final mapH = rows * cellSize;
    final totalW = mapW + _padL + _padR;
    final totalH = mapH + _padT + _padB;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Base grass tiled across ENTIRE padded area (extends beyond grid)
    _tileOrFill(canvas, cache.grassTexture,
        Rect.fromLTWH(0, 0, totalW, totalH),
        cache.currentBiome.groundBase);

    // Translate so grid content renders at padded offset
    canvas.save();
    canvas.translate(_padL, _padT);
    final mapRect = Rect.fromLTWH(0, 0, mapW, mapH);

    // 2. Blocked cells
    final blockedFallback =
        cache.currentBiome.decorationColors.isNotEmpty
            ? Color.lerp(cache.currentBiome.decorationColors[0],
                const Color(0xFF000000), 0.35)!
            : const Color(0xFF2B3A1E);
    _renderCellGroup(canvas, [CellType.blocked], cache.blockedTexture, mapW,
        mapH, blockedFallback);

    // 3. Path with rounded corners
    _renderPathGroup(canvas, cols, rows, cache, mapW, mapH);

    // 4. Spawn cells
    _renderCellGroup(canvas, [CellType.spawn], cache.spawnTexture, mapW, mapH,
        const Color(0xFF992222));

    // 5. Castle cells
    _renderCellGroup(canvas, [CellType.castle], cache.castleTexture, mapW,
        mapH, const Color(0xFFAA7520));

    // 6. PathBuildable green shimmer
    _renderPathBuildableTint(canvas);

    // 7. Path edge inner shadows
    _renderPathEdgeShadows(canvas, cols, rows);

    // 8. Path debris at terrain borders
    _renderPathDebris(canvas, cols, rows);

    // 9. Terrain transition feathering
    _renderTransitions(canvas, cols, rows);

    // 10. Blocked cell raised edges
    _renderBlockedEdges(canvas, cols, rows);

    // 11. Castle golden ambient glow
    _renderCastleGlow(canvas);

    // 12. Subtle vignette
    canvas.drawRect(
      mapRect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(mapW / 2, mapH / 2),
          math.max(mapW, mapH) * 0.65,
          [const Color(0x00000000), const Color(0x15000000)],
        ),
    );

    canvas.restore(); // undo translate for grid content

    final picture = recorder.endRecording();
    _cached = await picture.toImage(totalW.toInt(), totalH.toInt());
    picture.dispose();
  }

  // ─── Texture tiling ──────────────────────────────────────────────────────

  void _tileOrFill(Canvas canvas, ui.Image? tex, Rect area, Color fallback) {
    if (tex == null) {
      canvas.drawRect(area, Paint()..color = fallback);
      return;
    }
    final tw = tex.width.toDouble();
    final th = tex.height.toDouble();
    for (double y = area.top; y < area.bottom; y += th) {
      for (double x = area.left; x < area.right; x += tw) {
        final dstW = math.min(tw, area.right - x);
        final dstH = math.min(th, area.bottom - y);
        canvas.drawImageRect(
          tex,
          Rect.fromLTWH(0, 0, dstW, dstH),
          Rect.fromLTWH(x, y, dstW, dstH),
          _imgPaint,
        );
      }
    }
  }

  // ─── Cell group rendering ────────────────────────────────────────────────

  void _renderCellGroup(Canvas canvas, List<CellType> types,
      ui.Image? texture, double mapW, double mapH, Color fallback) {
    final path = Path();
    for (int r = 0; r < GameConfig.gridRows; r++) {
      for (int c = 0; c < GameConfig.gridColumns; c++) {
        if (types.contains(grid[r][c])) {
          path.addRect(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize));
        }
      }
    }
    if (path.getBounds().isEmpty) return;

    canvas.save();
    canvas.clipPath(path);
    // Tile from map origin so adjacent cells stay aligned
    _tileOrFill(canvas, texture, Rect.fromLTWH(0, 0, mapW, mapH), fallback);
    canvas.restore();
  }

  // ─── Path with rounded corners ───────────────────────────────────────────

  void _renderPathGroup(Canvas canvas, int cols, int rows, SpriteCache cache,
      double mapW, double mapH) {
    final pathPath = Path();
    final cr = cellSize * 0.3;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != CellType.path &&
            grid[r][c] != CellType.pathBuildable) {
          continue;
        }
        final x = c * cellSize;
        final y = r * cellSize;
        final top = r > 0 && _isPathLike(grid[r - 1][c]);
        final bottom = r < rows - 1 && _isPathLike(grid[r + 1][c]);
        final left = c > 0 && _isPathLike(grid[r][c - 1]);
        final right = c < cols - 1 && _isPathLike(grid[r][c + 1]);

        pathPath.addRRect(RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          topLeft: Radius.circular((!top && !left) ? cr : 0),
          topRight: Radius.circular((!top && !right) ? cr : 0),
          bottomLeft: Radius.circular((!bottom && !left) ? cr : 0),
          bottomRight: Radius.circular((!bottom && !right) ? cr : 0),
        ));
      }
    }
    if (pathPath.getBounds().isEmpty) return;

    canvas.save();
    canvas.clipPath(pathPath);
    _tileOrFill(canvas, cache.pathTexture,
        Rect.fromLTWH(0, 0, mapW, mapH), cache.currentBiome.pathBase);
    canvas.restore();
  }

  // ─── PathBuildable tint ──────────────────────────────────────────────────

  void _renderPathBuildableTint(Canvas canvas) {
    final paint = Paint()..color = const Color(0x1800FF44);
    for (int r = 0; r < GameConfig.gridRows; r++) {
      for (int c = 0; c < GameConfig.gridColumns; c++) {
        if (grid[r][c] == CellType.pathBuildable) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  // ─── Path edge inner shadows ─────────────────────────────────────────────

  void _renderPathEdgeShadows(Canvas canvas, int cols, int rows) {
    final edgePaint = Paint();
    final edgeW = cellSize * 0.18;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_isPathLike(grid[r][c])) continue;
        final x = c * cellSize;
        final y = r * cellSize;

        if (r == 0 || !_isPathLike(grid[r - 1][c])) {
          edgePaint.shader = ui.Gradient.linear(
              Offset(x, y), Offset(x, y + edgeW),
              [const Color(0x35000000), const Color(0x00000000)]);
          canvas.drawRect(
              Rect.fromLTWH(x, y, cellSize, edgeW), edgePaint);
        }
        if (r == rows - 1 || !_isPathLike(grid[r + 1][c])) {
          edgePaint.shader = ui.Gradient.linear(
              Offset(x, y + cellSize), Offset(x, y + cellSize - edgeW),
              [const Color(0x35000000), const Color(0x00000000)]);
          canvas.drawRect(
              Rect.fromLTWH(x, y + cellSize - edgeW, cellSize, edgeW),
              edgePaint);
        }
        if (c == 0 || !_isPathLike(grid[r][c - 1])) {
          edgePaint.shader = ui.Gradient.linear(
              Offset(x, y), Offset(x + edgeW, y),
              [const Color(0x35000000), const Color(0x00000000)]);
          canvas.drawRect(
              Rect.fromLTWH(x, y, edgeW, cellSize), edgePaint);
        }
        if (c == cols - 1 || !_isPathLike(grid[r][c + 1])) {
          edgePaint.shader = ui.Gradient.linear(
              Offset(x + cellSize, y), Offset(x + cellSize - edgeW, y),
              [const Color(0x35000000), const Color(0x00000000)]);
          canvas.drawRect(
              Rect.fromLTWH(x + cellSize - edgeW, y, edgeW, cellSize),
              edgePaint);
        }
      }
    }
  }

  // ─── Path debris ─────────────────────────────────────────────────────────

  void _renderPathDebris(Canvas canvas, int cols, int rows) {
    final rng = math.Random(73);
    const stoneColors = [
      Color(0xFF5A5550),
      Color(0xFF6A645A),
      Color(0xFF4A4540),
      Color(0xFF7A7468),
    ];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_isPathLike(grid[r][c])) continue;
        final x = c * cellSize;
        final y = r * cellSize;

        if (r > 0 && !_isPathLike(grid[r - 1][c])) {
          _scatterRubble(canvas, rng, stoneColors, x, y, cellSize, 0, -1);
        }
        if (r < rows - 1 && !_isPathLike(grid[r + 1][c])) {
          _scatterRubble(
              canvas, rng, stoneColors, x, y + cellSize, cellSize, 0, 1);
        }
        if (c > 0 && !_isPathLike(grid[r][c - 1])) {
          _scatterRubble(canvas, rng, stoneColors, x, y, cellSize, -1, 0);
        }
        if (c < cols - 1 && !_isPathLike(grid[r][c + 1])) {
          _scatterRubble(
              canvas, rng, stoneColors, x + cellSize, y, cellSize, 1, 0);
        }
      }
    }
  }

  void _scatterRubble(Canvas canvas, math.Random rng, List<Color> colors,
      double x, double y, double length, int dx, int dy) {
    final count = 2 + rng.nextInt(3);
    for (int i = 0; i < count; i++) {
      double ox, oy;
      if (dx == 0) {
        ox = x + rng.nextDouble() * length;
        oy = y + dy * rng.nextDouble() * cellSize * 0.35;
      } else {
        ox = x + dx * rng.nextDouble() * cellSize * 0.35;
        oy = y + rng.nextDouble() * length;
      }
      final w = 3 + rng.nextDouble() * 6;
      final h = 2 + rng.nextDouble() * 4;
      final angle = rng.nextDouble() * math.pi;
      final color = colors[rng.nextInt(colors.length)];

      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(ox + 1, oy + 1), width: w, height: h * 0.7),
        Paint()..color = const Color(0x25000000),
      );
      canvas.save();
      canvas.translate(ox, oy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Paint()..color = color.withAlpha(140),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(-w * 0.1, -h * 0.15),
            width: w * 0.5,
            height: h * 0.4),
        Paint()..color = const Color(0x18FFFFFF),
      );
      canvas.restore();
    }
  }

  // ─── Terrain transitions ─────────────────────────────────────────────────

  void _renderTransitions(Canvas canvas, int cols, int rows) {
    const feather = 8.0;
    final edgePaint = Paint();

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cat = _category(grid[r][c]);
        final x = c * cellSize;
        final y = r * cellSize;

        // Top
        if (r > 0 && _category(grid[r - 1][c]) != cat) {
          final alpha = grid[r - 1][c] == CellType.blocked ? 0x22 : 0x12;
          edgePaint.shader = ui.Gradient.linear(
            Offset(x, y),
            Offset(x, y + feather),
            [Color.fromARGB(alpha, 0, 0, 0), const Color(0x00000000)],
          );
          canvas.drawRect(
              Rect.fromLTWH(x, y, cellSize, feather), edgePaint);
        }
        // Bottom
        if (r < rows - 1 && _category(grid[r + 1][c]) != cat) {
          final alpha = grid[r + 1][c] == CellType.blocked ? 0x22 : 0x12;
          edgePaint.shader = ui.Gradient.linear(
            Offset(x, y + cellSize),
            Offset(x, y + cellSize - feather),
            [Color.fromARGB(alpha, 0, 0, 0), const Color(0x00000000)],
          );
          canvas.drawRect(
              Rect.fromLTWH(x, y + cellSize - feather, cellSize, feather),
              edgePaint);
        }
        // Left
        if (c > 0 && _category(grid[r][c - 1]) != cat) {
          final alpha = grid[r][c - 1] == CellType.blocked ? 0x22 : 0x12;
          edgePaint.shader = ui.Gradient.linear(
            Offset(x, y),
            Offset(x + feather, y),
            [Color.fromARGB(alpha, 0, 0, 0), const Color(0x00000000)],
          );
          canvas.drawRect(
              Rect.fromLTWH(x, y, feather, cellSize), edgePaint);
        }
        // Right
        if (c < cols - 1 && _category(grid[r][c + 1]) != cat) {
          final alpha = grid[r][c + 1] == CellType.blocked ? 0x22 : 0x12;
          edgePaint.shader = ui.Gradient.linear(
            Offset(x + cellSize, y),
            Offset(x + cellSize - feather, y),
            [Color.fromARGB(alpha, 0, 0, 0), const Color(0x00000000)],
          );
          canvas.drawRect(
              Rect.fromLTWH(x + cellSize - feather, y, feather, cellSize),
              edgePaint);
        }
      }
    }
  }

  // ─── Blocked cell edges ──────────────────────────────────────────────────

  void _renderBlockedEdges(Canvas canvas, int cols, int rows) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != CellType.blocked) continue;
        final x = c * cellSize;
        final y = r * cellSize;

        // South shadow
        if (r < rows - 1 && grid[r + 1][c] != CellType.blocked) {
          canvas.drawRect(
            Rect.fromLTWH(x, y + cellSize - 2, cellSize, 2),
            Paint()..color = const Color(0x20000000),
          );
        }
        // East shadow
        if (c < cols - 1 && grid[r][c + 1] != CellType.blocked) {
          canvas.drawRect(
            Rect.fromLTWH(x + cellSize - 2, y, 2, cellSize),
            Paint()..color = const Color(0x18000000),
          );
        }
        // Top highlight
        if (r > 0 && grid[r - 1][c] != CellType.blocked) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellSize, 2),
            Paint()..color = const Color(0x10FFFFFF),
          );
        }
      }
    }
  }

  // ─── Castle golden glow ──────────────────────────────────────────────────

  void _renderCastleGlow(Canvas canvas) {
    for (int r = 0; r < GameConfig.gridRows; r++) {
      for (int c = 0; c < GameConfig.gridColumns; c++) {
        if (grid[r][c] != CellType.castle) continue;
        final cx = c * cellSize + cellSize * 0.5;
        final cy = r * cellSize + cellSize * 0.5;
        final radius = cellSize * 1.2;

        canvas.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(cx, cy),
              radius,
              [const Color(0x18FFD700), const Color(0x00FFD700)],
            ),
        );
      }
    }
  }

  int _category(CellType t) {
    switch (t) {
      case CellType.buildable:
      case CellType.castle:
        return 0;
      case CellType.path:
      case CellType.pathBuildable:
        return 1;
      case CellType.blocked:
        return 2;
      case CellType.spawn:
        return 3;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (_cached != null) {
      canvas.drawImage(_cached!, const Offset(-_padL, -_padT), _imgPaint);

      // Animated spawn pulsing glow (rendered live, not cached)
      final pulse = (math.sin(_time * 2.5) * 0.5 + 0.5); // 0..1
      final alpha = (0x10 + (pulse * 0x18).toInt()).clamp(0, 255);
      for (int r = 0; r < GameConfig.gridRows; r++) {
        for (int c = 0; c < GameConfig.gridColumns; c++) {
          if (grid[r][c] != CellType.spawn) continue;
          final cx = c * cellSize + cellSize * 0.5;
          final cy = r * cellSize + cellSize * 0.5;
          final radius = cellSize * 0.6 + pulse * cellSize * 0.15;
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(cx, cy),
                radius,
                [
                  Color.fromARGB(alpha, 255, 30, 30),
                  const Color(0x00FF0000),
                ],
              ),
          );
        }
      }
      return;
    }
    // Fallback: flat colors while cache builds
    for (int r = 0; r < GameConfig.gridRows; r++) {
      for (int c = 0; c < GameConfig.gridColumns; c++) {
        final Color color;
        switch (grid[r][c]) {
          case CellType.buildable:
            color = const Color(0xFF3B7A35);
          case CellType.path:
            color = const Color(0xFF9B7D4B);
          case CellType.pathBuildable:
            color = const Color(0xFF8B7D3B);
          case CellType.blocked:
            color = const Color(0xFF2B3A1E);
          case CellType.spawn:
            color = const Color(0xFF992222);
          case CellType.castle:
            color = const Color(0xFF555577);
        }
        canvas.drawRect(
          Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
          Paint()..color = color,
        );
      }
    }
  }
}
