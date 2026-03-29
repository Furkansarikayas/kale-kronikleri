import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/game_config.dart';
import '../../rendering/sprite_cache.dart';

/// Scatters procedural decorations (trees, rocks, flowers) on the map.
///
/// Rendered once to a cached image, drawn as a single blit each frame.
/// Uses deterministic RNG per cell so decorations are stable across rebuilds.
class MapDecorationLayer extends PositionComponent {
  final List<List<CellType>> grid;
  final double cellSize;

  ui.Image? _cached;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.medium;

  MapDecorationLayer({required this.grid, required this.cellSize}) {
    priority = 1; // Above ground layer, below towers/enemies
  }

  @override
  Future<void> onLoad() async {
    if (SpriteCache.instance.isInitialized) {
      await _buildCache();
    }
  }

  Future<void> _buildCache() async {
    final cols = GameConfig.gridColumns;
    final rows = GameConfig.gridRows;
    final mapW = cols * cellSize;
    final mapH = rows * cellSize;
    final biome = SpriteCache.instance.currentBiome;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        final rng = math.Random(c * 7 + r * 13 + 37);
        final cx = c * cellSize;
        final cy = r * cellSize;

        if (cell == CellType.blocked) {
          _drawBlockedDecorations(canvas, rng, cx, cy, biome);
        } else if (cell == CellType.buildable) {
          _drawBuildableDecorations(canvas, rng, cx, cy, biome);
        }
      }
    }

    final picture = recorder.endRecording();
    _cached = await picture.toImage(mapW.toInt(), mapH.toInt());
    picture.dispose();
  }

  // ─── Blocked cell decorations: trees + rocks ─────────────────────────────

  void _drawBlockedDecorations(
      Canvas canvas, math.Random rng, double cx, double cy, biome) {
    final roll = rng.nextDouble();

    if (roll < 0.45) {
      // Pine tree
      final tx = cx + cellSize * (0.25 + rng.nextDouble() * 0.5);
      final ty = cy + cellSize * (0.2 + rng.nextDouble() * 0.4);
      _drawPineTree(canvas, tx, ty, rng, biome);
    } else if (roll < 0.75) {
      // Rock cluster
      final rx = cx + cellSize * (0.2 + rng.nextDouble() * 0.6);
      final ry = cy + cellSize * (0.3 + rng.nextDouble() * 0.5);
      _drawRockCluster(canvas, rx, ry, rng);
    } else if (roll < 0.88) {
      // Small bush
      final bx = cx + cellSize * (0.25 + rng.nextDouble() * 0.5);
      final by = cy + cellSize * (0.35 + rng.nextDouble() * 0.45);
      _drawBush(canvas, bx, by, rng, biome);
    }
    // 12% chance: empty (variety)
  }

  void _drawPineTree(
      Canvas canvas, double x, double y, math.Random rng, biome) {
    final scale = 0.7 + rng.nextDouble() * 0.5;
    final trunkH = cellSize * 0.2 * scale;
    final trunkW = cellSize * 0.06 * scale;
    final canopyW = cellSize * 0.35 * scale;
    final canopyH = cellSize * 0.25 * scale;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x + 2, y + trunkH + 2),
          width: canopyW * 0.7,
          height: canopyW * 0.25),
      Paint()..color = const Color(0x20000000),
    );

    // Trunk
    final trunkColor =
        Color.lerp(const Color(0xFF5A3A20), const Color(0xFF7A5030),
            rng.nextDouble())!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, y + trunkH * 0.3),
            width: trunkW,
            height: trunkH),
        Radius.circular(trunkW * 0.3),
      ),
      Paint()..color = trunkColor,
    );

    // Three layered canopy triangles (bottom to top, each smaller)
    final darkGreen = biome.decorationColors.isNotEmpty
        ? biome.decorationColors[1]
        : const Color(0xFF2A6A25);
    final midGreen = biome.decorationColors.isNotEmpty
        ? biome.decorationColors[0]
        : const Color(0xFF4A8A40);
    final lightGreen = biome.decorationColors.length > 2
        ? biome.decorationColors[2]
        : const Color(0xFF6AAA55);

    for (int layer = 0; layer < 3; layer++) {
      final f = 1.0 - layer * 0.28;
      final w = canopyW * f;
      final h = canopyH * f;
      final yOff = -layer * canopyH * 0.35;

      final color = layer == 0
          ? darkGreen
          : (layer == 1 ? midGreen : lightGreen);

      final path = Path();
      path.moveTo(x, y + yOff - h);
      path.lineTo(x - w * 0.5, y + yOff);
      path.lineTo(x + w * 0.5, y + yOff);
      path.close();
      canvas.drawPath(path, Paint()..color = color);

      // Subtle highlight on left side of each layer
      final hlPath = Path();
      hlPath.moveTo(x, y + yOff - h);
      hlPath.lineTo(x - w * 0.5, y + yOff);
      hlPath.lineTo(x - w * 0.15, y + yOff);
      hlPath.close();
      canvas.drawPath(hlPath, Paint()..color = const Color(0x0DFFFFFF));
    }
  }

  void _drawRockCluster(Canvas canvas, double x, double y, math.Random rng) {
    final count = 2 + rng.nextInt(3);
    const rockColors = [
      Color(0xFF6A6560),
      Color(0xFF7A7570),
      Color(0xFF5A5550),
      Color(0xFF8A8580),
    ];

    for (int i = 0; i < count; i++) {
      final rx = x + (rng.nextDouble() - 0.5) * cellSize * 0.3;
      final ry = y + (rng.nextDouble() - 0.5) * cellSize * 0.2;
      final rw = cellSize * (0.08 + rng.nextDouble() * 0.12);
      final rh = rw * (0.6 + rng.nextDouble() * 0.4);
      final color = rockColors[rng.nextInt(rockColors.length)];

      // Shadow
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(rx + 1.5, ry + rh * 0.3),
            width: rw * 1.1,
            height: rh * 0.4),
        Paint()..color = const Color(0x18000000),
      );

      // Rock body
      canvas.drawOval(
        Rect.fromCenter(center: Offset(rx, ry), width: rw, height: rh),
        Paint()..color = color,
      );

      // Highlight
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(rx - rw * 0.15, ry - rh * 0.2),
            width: rw * 0.45,
            height: rh * 0.35),
        Paint()..color = const Color(0x15FFFFFF),
      );
    }
  }

  void _drawBush(
      Canvas canvas, double x, double y, math.Random rng, biome) {
    final bw = cellSize * (0.2 + rng.nextDouble() * 0.15);
    final bh = bw * (0.5 + rng.nextDouble() * 0.3);

    final color = biome.decorationColors.isNotEmpty
        ? biome.decorationColors[rng.nextInt(biome.decorationColors.length)]
        : const Color(0xFF4A8A40);
    final darker = Color.lerp(color, const Color(0xFF000000), 0.25)!;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x + 1.5, y + bh * 0.3),
          width: bw * 0.8,
          height: bh * 0.25),
      Paint()..color = const Color(0x18000000),
    );

    // Bush shape: overlapping circles
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: bw, height: bh),
      Paint()..color = darker,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x - bw * 0.2, y - bh * 0.1),
          width: bw * 0.7,
          height: bh * 0.7),
      Paint()..color = color,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x + bw * 0.15, y - bh * 0.15),
          width: bw * 0.5,
          height: bh * 0.5),
      Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.15)!,
    );
  }

  // ─── Buildable cell decorations: grass tufts, tiny flowers ───────────────

  void _drawBuildableDecorations(
      Canvas canvas, math.Random rng, double cx, double cy, biome) {
    // 40% chance of grass tuft
    if (rng.nextDouble() < 0.4) {
      final gx = cx + cellSize * (0.15 + rng.nextDouble() * 0.7);
      final gy = cy + cellSize * (0.3 + rng.nextDouble() * 0.6);
      _drawGrassTuft(canvas, gx, gy, rng, biome);
    }

    // 20% chance of tiny flower
    if (rng.nextDouble() < 0.2) {
      final fx = cx + cellSize * (0.2 + rng.nextDouble() * 0.6);
      final fy = cy + cellSize * (0.25 + rng.nextDouble() * 0.6);
      _drawTinyFlower(canvas, fx, fy, rng);
    }
  }

  void _drawGrassTuft(
      Canvas canvas, double x, double y, math.Random rng, biome) {
    final bladeCount = 3 + rng.nextInt(3);
    final grassColor = biome.decorationColors.isNotEmpty
        ? Color.lerp(biome.decorationColors[0], biome.groundAccent, 0.3)!
        : const Color(0xFF5AAA40);
    final darkGrass = Color.lerp(grassColor, const Color(0xFF000000), 0.2)!;

    for (int i = 0; i < bladeCount; i++) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 0.8;
      final h = cellSize * (0.1 + rng.nextDouble() * 0.08);
      final endX = x + math.cos(angle) * h;
      final endY = y + math.sin(angle) * h;
      final color = i % 2 == 0 ? grassColor : darkGrass;

      canvas.drawLine(
        Offset(x, y),
        Offset(endX, endY),
        Paint()
          ..color = color.withAlpha(120)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawTinyFlower(Canvas canvas, double x, double y, math.Random rng) {
    const flowerColors = [
      Color(0xFFFF6688), // Pink
      Color(0xFFFFCC44), // Yellow
      Color(0xFFAA88FF), // Purple
      Color(0xFFFFFFFF), // White
      Color(0xFF88CCFF), // Blue
    ];

    final color = flowerColors[rng.nextInt(flowerColors.length)];
    final r = cellSize * 0.025;

    // Stem
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + cellSize * 0.06),
      Paint()
        ..color = const Color(0x6038802A)
        ..strokeWidth = 0.8,
    );

    // Petals (4-5 small dots around center)
    final petalCount = 4 + rng.nextInt(2);
    for (int i = 0; i < petalCount; i++) {
      final a = i * (2 * math.pi / petalCount);
      canvas.drawCircle(
        Offset(x + math.cos(a) * r * 1.3, y + math.sin(a) * r * 1.3),
        r * 0.7,
        Paint()..color = color.withAlpha(140),
      );
    }

    // Center
    canvas.drawCircle(
      Offset(x, y),
      r * 0.5,
      Paint()..color = const Color(0x90FFEE44),
    );
  }

  @override
  void render(Canvas canvas) {
    if (_cached != null) {
      canvas.drawImage(_cached!, Offset.zero, _imgPaint);
    }
  }
}
