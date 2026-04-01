import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/map/biome_data.dart';
import 'perlin_noise.dart';

/// High-quality smooth sprite generator and cache.
///
/// Generates terrain tiles at 128x128 using smooth Canvas primitives
/// (gradients, circles, paths) — no pixel grid. Displayed at 40x40 for crisp,
/// modern visuals.
class SpriteCache {
  static final SpriteCache instance = SpriteCache._();
  SpriteCache._();

  final Map<String, ui.Image> _cache = {};
  bool _initialized = false;
  bool get isInitialized => _initialized;

  BiomeData _currentBiome = BiomeData.forest;
  BiomeData get currentBiome => _currentBiome;

  late final PerlinNoise _perlin;

  // Terrain textures (512x512) for MapGroundLayer tiling
  static const int terrainSize = 512;
  ui.Image? _grassTexture;
  ui.Image? _pathTexture;
  ui.Image? _blockedTexture;
  ui.Image? _spawnTexture;
  ui.Image? _castleTexture;

  ui.Image? get grassTexture => _grassTexture;
  ui.Image? get pathTexture => _pathTexture;
  ui.Image? get blockedTexture => _blockedTexture;
  ui.Image? get spawnTexture => _spawnTexture;
  ui.Image? get castleTexture => _castleTexture;

  static const int spriteSize = 128;
  static const double _s = 128.0;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize({BiomeData? biome}) async {
    _currentBiome = biome ?? BiomeData.forest;

    // Clear existing cache when re-initializing with a new biome
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _initialized = false;

    // Load terrain textures from assets, fall back to procedural generation
    _perlin = PerlinNoise(seed: 42);
    final biomeName = _currentBiome.type.name; // forest, desert, etc.
    _grassTexture = await _loadTerrainAsset('$biomeName/grass.webp') ??
        await _renderTerrainTile(terrainSize, _paintTerrainGrass);
    _pathTexture = await _loadTerrainAsset('$biomeName/path.webp') ??
        await _renderTerrainTile(terrainSize, _paintTerrainPath);
    _blockedTexture = await _loadTerrainAsset('$biomeName/blocked.webp') ??
        await _renderTerrainTile(terrainSize, _paintTerrainBlocked);
    _spawnTexture = await _loadTerrainAsset('$biomeName/spawn.webp') ??
        await _renderTerrainTile(256, _paintTerrainSpawn);
    _castleTexture = await _loadTerrainAsset('$biomeName/castle.webp') ??
        await _renderTerrainTile(terrainSize, _paintTerrainCastle);

    for (int v = 0; v < 6; v++) {
      _cache['grass_$v'] = await _renderTile((c) => _paintGrass(c, v));
    }
    for (int v = 0; v < 4; v++) {
      _cache['path_$v'] = await _renderTile((c) => _paintPath(c, v));
    }
    for (final dir in ['top', 'bottom', 'left', 'right']) {
      _cache['path_edge_$dir'] = await _renderTile((c) => _paintPathEdge(c, dir));
    }
    for (int v = 0; v < 4; v++) {
      _cache['blocked_$v'] = await _renderTile((c) => _paintBlocked(c, v));
    }
    _cache['spawn'] = await _renderTile(_paintSpawn);
    _cache['castle_ground'] = await _renderTile(_paintCastleGround);

    _initialized = true;
  }

  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _grassTexture?.dispose();
    _pathTexture?.dispose();
    _blockedTexture?.dispose();
    _spawnTexture?.dispose();
    _castleTexture?.dispose();
    _grassTexture = null;
    _pathTexture = null;
    _blockedTexture = null;
    _spawnTexture = null;
    _castleTexture = null;
    _initialized = false;
  }

  ui.Image? getTile(String key) => _cache[key];

  // ---------------------------------------------------------------------------
  // Rendering helper
  // ---------------------------------------------------------------------------

  Future<ui.Image> _renderTile(void Function(Canvas c) painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(spriteSize, spriteSize);
    picture.dispose();
    return image;
  }

  // =========================================================================
  //  Value noise for organic textures
  // =========================================================================

  /// Simple value noise: returns 0..1 for any (x, y) with given seed.
  static double _noise(double x, double y, int seed) {
    // Hash-based pseudo-random
    int h = seed;
    h ^= (x * 374761.0).toInt();
    h ^= (y * 668265.0).toInt();
    h = ((h >> 13) ^ h) * 1274126177;
    h = ((h >> 13) ^ h);
    return (h & 0x7FFFFFFF) / 0x7FFFFFFF;
  }

  /// Smooth interpolated noise (bilinear between grid points).
  static double _smoothNoise(double x, double y, int seed, {double scale = 16}) {
    final sx = x / scale;
    final sy = y / scale;
    final ix = sx.floor();
    final iy = sy.floor();
    final fx = sx - ix;
    final fy = sy - iy;

    final n00 = _noise(ix.toDouble(), iy.toDouble(), seed);
    final n10 = _noise(ix + 1.0, iy.toDouble(), seed);
    final n01 = _noise(ix.toDouble(), iy + 1.0, seed);
    final n11 = _noise(ix + 1.0, iy + 1.0, seed);

    // Smoothstep
    final u = fx * fx * (3 - 2 * fx);
    final v = fy * fy * (3 - 2 * fy);

    final top = n00 + (n10 - n00) * u;
    final bot = n01 + (n11 - n01) * u;
    return top + (bot - top) * v;
  }

  /// Fractal brownian motion (2 octaves for performance).
  static double _fbm(double x, double y, int seed) {
    return _smoothNoise(x, y, seed, scale: 20) * 0.6 +
        _smoothNoise(x, y, seed + 999, scale: 8) * 0.3 +
        _smoothNoise(x, y, seed + 1777, scale: 4) * 0.1;
  }

  // =========================================================================
  //  GRASS TILES (6 variants)
  // =========================================================================

  void _paintGrass(Canvas c, int variant) {
    final rng = math.Random(variant * 997 + 42);
    final seed = variant * 31 + 7;

    // Base gradient — biome ground colors
    final baseGrad = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(_s, _s),
      [_currentBiome.groundBase, _currentBiome.groundAccent, _currentBiome.groundBase],
      [0.0, 0.5, 1.0],
    );
    c.drawRect(Rect.fromLTWH(0, 0, _s, _s), Paint()..shader = baseGrad);

    // Organic noise texture — overlapping soft circles for natural look
    // Softened contrast (~20% less) to keep background subordinate to towers
    final darkGround = Color.lerp(_currentBiome.groundBase, const Color(0xFF000000), 0.06)!;
    final midGround = Color.lerp(_currentBiome.groundAccent, _currentBiome.groundBase, 0.15)!;
    final lightGround = Color.lerp(_currentBiome.groundAccent, const Color(0xFFFFFFFF), 0.08)!;
    for (int i = 0; i < 150; i++) {
      final px = rng.nextDouble() * _s;
      final py = rng.nextDouble() * _s;
      final n = _fbm(px, py, seed);
      final r = 2.5 + n * 4.5;

      Color col;
      if (n < 0.25) {
        col = darkGround.withAlpha((10 + rng.nextInt(8)).clamp(0, 255));
      } else if (n < 0.55) {
        col = midGround.withAlpha((14 + rng.nextInt(10)).clamp(0, 255));
      } else {
        col = lightGround.withAlpha((12 + rng.nextInt(10)).clamp(0, 255));
      }
      c.drawCircle(Offset(px, py), r, Paint()..color = col);
    }

    // Grass blades — thin curved lines (reduced alpha for softer background)
    for (int i = 0; i < 14; i++) {
      final bx = rng.nextDouble() * _s;
      final by = rng.nextDouble() * _s;
      final h = 4.0 + rng.nextDouble() * 8.0;
      final lean = (rng.nextDouble() - 0.5) * 5;
      final bladeColor = Color.lerp(
        _currentBiome.groundBase,
        _currentBiome.groundAccent,
        rng.nextDouble(),
      )!.withAlpha(85);

      final path = Path()
        ..moveTo(bx, by)
        ..quadraticBezierTo(bx + lean * 0.5, by - h * 0.6, bx + lean, by - h);
      c.drawPath(
        path,
        Paint()
          ..color = bladeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Variant-specific decorations — only subtle flowers, no dark objects
    switch (variant) {
      case 1:
        _drawSmoothFlower(c, rng.nextDouble() * 60 + 30, rng.nextDouble() * 60 + 30,
            const Color(0xFFCC3333), rng);
        break;
      case 2:
        _drawSmoothFlower(c, rng.nextDouble() * 60 + 30, rng.nextDouble() * 60 + 30,
            const Color(0xFFDDCC22), rng);
        break;
      case 3:
        _drawSmoothFlower(c, rng.nextDouble() * 60 + 30, rng.nextDouble() * 60 + 30,
            const Color(0xFF5599DD), rng);
        break;
      // variant 4 (mushroom) and 5 (rocks) removed — too dark on grass
    }

    // Subtle top-left lighting (reduced for softer background)
    c.drawRect(
      Rect.fromLTWH(0, 0, _s, _s),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(_s, _s),
          [const Color(0x06FFFFFF), const Color(0x00000000), const Color(0x04000000)],
          [0.0, 0.4, 1.0],
        ),
    );
  }

  void _drawSmoothFlower(Canvas c, double x, double y, Color petalColor, math.Random rng) {
    // Stem
    final stemPath = Path()
      ..moveTo(x, y + 4)
      ..quadraticBezierTo(x - 1, y + 1, x, y - 2);
    c.drawPath(stemPath, Paint()
      ..color = const Color(0xFF2A6A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round);
    // Petals
    for (int i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 - math.pi / 2;
      final px = x + math.cos(angle) * 3.5;
      final py = y - 3 + math.sin(angle) * 3.5;
      c.drawCircle(Offset(px, py), 2.2, Paint()..color = petalColor.withAlpha(200));
    }
    // Center
    c.drawCircle(Offset(x, y - 3), 1.5, Paint()..color = const Color(0xFFEEDD44));
  }

  void _drawSmoothMushroom(Canvas c, double x, double y) {
    // Stem
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 2), width: 4, height: 6), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFFDDCCBB),
    );
    // Cap
    c.drawArc(Rect.fromCenter(center: Offset(x, y - 1), width: 12, height: 10), math.pi, math.pi, true,
        Paint()..color = const Color(0xFF994422));
    // Cap highlight
    c.drawCircle(Offset(x - 1, y - 3), 1.5, Paint()..color = const Color(0xFFEEDDCC));
  }

  void _drawSmoothRock(Canvas c, double x, double y, double r) {
    // Shadow
    c.drawOval(Rect.fromCenter(center: Offset(x + 1, y + r * 0.4), width: r * 2.2, height: r * 0.8),
        Paint()..color = const Color(0x30000000));
    // Body
    final rockGrad = ui.Gradient.radial(
      Offset(x - r * 0.3, y - r * 0.3), r * 1.5,
      [const Color(0xFF888888), const Color(0xFF666666), const Color(0xFF444444)],
      [0.0, 0.5, 1.0],
    );
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 1.4),
        Paint()..shader = rockGrad);
    // Highlight
    c.drawOval(Rect.fromCenter(center: Offset(x - r * 0.2, y - r * 0.15), width: r * 0.8, height: r * 0.5),
        Paint()..color = const Color(0x20FFFFFF));
  }

  // =========================================================================
  //  PATH TILES (4 variants — smooth cobblestone)
  // =========================================================================

  void _paintPath(Canvas c, int variant) {
    final rng = math.Random(variant * 1301 + 77);

    // Warm earth base — biome path color
    c.drawRect(Rect.fromLTWH(0, 0, _s, _s),
        Paint()..color = _currentBiome.pathBase);

    // Cobblestone pattern with smooth rounded rects
    _drawSmoothCobbles(c, variant, rng);

    // Subtle wear/dirt overlay
    final dirtColor = Color.lerp(_currentBiome.pathBase, const Color(0xFF000000), 0.2)!;
    for (int i = 0; i < 40; i++) {
      final px = rng.nextDouble() * _s;
      final py = rng.nextDouble() * _s;
      c.drawCircle(Offset(px, py), 1.5 + rng.nextDouble() * 3,
          Paint()..color = dirtColor.withAlpha(15 + rng.nextInt(15)));
    }

    // Center-lighter / edges-darker for path depth
    c.drawRect(
      Rect.fromLTWH(0, 0, _s, _s),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, _s),
          [const Color(0x12000000), const Color(0x08FFFFFF), const Color(0x12000000)],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  void _drawSmoothCobbles(Canvas c, int variant, math.Random rng) {
    final stoneColors = [
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.15)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.25)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.30)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.20)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.40)!,
    ];

    double y = -2.0;
    int rowIdx = 0;
    while (y < _s + 5) {
      final stoneH = 10.0 + (rowIdx % 3) * 2;
      final xOffset = (rowIdx % 2 == 0) ? 0.0 : (12.0 + variant * 3);
      double x = -xOffset;
      int colIdx = 0;
      while (x < _s + 5) {
        final stoneW = 18.0 + ((colIdx + rowIdx + variant) % 4) * 4;
        final color = stoneColors[(colIdx + rowIdx * 3 + variant) % stoneColors.length];

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1.2, y + 1.2, stoneW - 2.4, stoneH - 2.4),
          Radius.circular(2.5 + rng.nextDouble()),
        );

        // Stone body with gradient (3D look)
        final stoneGrad = ui.Gradient.linear(
          Offset(x, y),
          Offset(x + stoneW, y + stoneH),
          [
            Color.lerp(color, Colors.white, 0.12)!,
            color,
            Color.lerp(color, Colors.black, 0.15)!,
          ],
          [0.0, 0.4, 1.0],
        );
        c.drawRRect(rect, Paint()..shader = stoneGrad);

        // Subtle inner texture
        for (int t = 0; t < 3; t++) {
          final tx = x + 3 + rng.nextDouble() * (stoneW - 6);
          final ty = y + 3 + rng.nextDouble() * (stoneH - 6);
          c.drawCircle(Offset(tx, ty), 1.0 + rng.nextDouble() * 1.5,
              Paint()..color = Color.lerp(color, Colors.black, 0.08)!.withAlpha(40));
        }

        x += stoneW;
        colIdx++;
      }
      y += stoneH;
      rowIdx++;
    }

    // Mortar lines (dark gaps between stones)
    y = -2.0;
    rowIdx = 0;
    while (y < _s + 5) {
      final stoneH = 10.0 + (rowIdx % 3) * 2;
      // Horizontal mortar
      c.drawLine(
        Offset(0, y + stoneH),
        Offset(_s, y + stoneH),
        Paint()
          ..color = Color.lerp(_currentBiome.pathBase, const Color(0xFF000000), 0.3)!
          ..strokeWidth = 2.0,
      );
      // Vertical mortar lines
      final xOffset = (rowIdx % 2 == 0) ? 0.0 : (12.0 + variant * 3);
      double x = -xOffset;
      int colIdx = 0;
      while (x < _s + 5) {
        final stoneW = 18.0 + ((colIdx + rowIdx + variant) % 4) * 4;
        c.drawLine(
          Offset(x + stoneW, y),
          Offset(x + stoneW, y + stoneH),
          Paint()
            ..color = Color.lerp(_currentBiome.pathBase, const Color(0xFF000000), 0.3)!
            ..strokeWidth = 1.8,
        );
        x += stoneW;
        colIdx++;
      }
      y += stoneH;
      rowIdx++;
    }
  }

  // =========================================================================
  //  PATH EDGE TILES (grass-to-path transition)
  // =========================================================================

  void _paintPathEdge(Canvas c, String direction) {
    final rng = math.Random(direction.hashCode + 55);

    // Draw full path base
    _paintPath(c, 0);

    // Organic grass intrusion from one side
    for (int i = 0; i < 300; i++) {
      double px, py;
      double maxDepth;

      switch (direction) {
        case 'top':
          px = rng.nextDouble() * _s;
          maxDepth = 15 + rng.nextDouble() * 25 + math.sin(px * 0.15) * 10;
          py = rng.nextDouble() * maxDepth;
          break;
        case 'bottom':
          px = rng.nextDouble() * _s;
          maxDepth = 15 + rng.nextDouble() * 25 + math.sin(px * 0.15) * 10;
          py = _s - rng.nextDouble() * maxDepth;
          break;
        case 'left':
          py = rng.nextDouble() * _s;
          maxDepth = 15 + rng.nextDouble() * 25 + math.sin(py * 0.15) * 10;
          px = rng.nextDouble() * maxDepth;
          break;
        case 'right':
          py = rng.nextDouble() * _s;
          maxDepth = 15 + rng.nextDouble() * 25 + math.sin(py * 0.15) * 10;
          px = _s - rng.nextDouble() * maxDepth;
          break;
        default:
          px = rng.nextDouble() * _s;
          py = rng.nextDouble() * 30;
      }

      // Distance from edge (0=edge, 1=deep)
      double edgeDist;
      switch (direction) {
        case 'top':
          edgeDist = py / 40;
          break;
        case 'bottom':
          edgeDist = (_s - py) / 40;
          break;
        case 'left':
          edgeDist = px / 40;
          break;
        case 'right':
          edgeDist = (_s - px) / 40;
          break;
        default:
          edgeDist = py / 40;
      }
      edgeDist = edgeDist.clamp(0.0, 1.0);

      final r = 2.0 + rng.nextDouble() * 5.0;
      final alpha = (80 + edgeDist * 120).round().clamp(0, 255);
      final edgeColor = Color.lerp(
        _currentBiome.groundBase,
        _currentBiome.groundAccent,
        edgeDist,
      )!.withAlpha(alpha);
      c.drawCircle(
        Offset(px, py),
        r,
        Paint()..color = edgeColor,
      );
    }

    // Grass blades near edge
    for (int i = 0; i < 8; i++) {
      double bx, by;
      switch (direction) {
        case 'top':
          bx = rng.nextDouble() * _s;
          by = rng.nextDouble() * 20;
          break;
        case 'bottom':
          bx = rng.nextDouble() * _s;
          by = _s - rng.nextDouble() * 20;
          break;
        case 'left':
          bx = rng.nextDouble() * 20;
          by = rng.nextDouble() * _s;
          break;
        case 'right':
          bx = _s - rng.nextDouble() * 20;
          by = rng.nextDouble() * _s;
          break;
        default:
          bx = rng.nextDouble() * _s;
          by = rng.nextDouble() * 20;
      }
      final h = 4.0 + rng.nextDouble() * 8;
      final lean = (rng.nextDouble() - 0.5) * 5;
      final edgeBladeColor = Color.lerp(
        _currentBiome.groundBase,
        _currentBiome.groundAccent,
        rng.nextDouble(),
      )!.withAlpha(150);
      c.drawPath(
        Path()
          ..moveTo(bx, by)
          ..quadraticBezierTo(bx + lean * 0.5, by - h * 0.6, bx + lean, by - h),
        Paint()
          ..color = edgeBladeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // =========================================================================
  //  BLOCKED TILES (4 variants — forest/rocks)
  // =========================================================================

  void _paintBlocked(Canvas c, int variant) {
    final rng = math.Random(variant * 503 + 31);
    final seed = variant * 41 + 3;

    // Forest base gradient — biome decoration colors
    final blockedBase = _currentBiome.decorationColors.isNotEmpty
        ? _currentBiome.decorationColors[0]
        : _currentBiome.groundBase;
    final blockedDark = Color.lerp(blockedBase, const Color(0xFF000000), 0.3)!;
    final blockedDarker = Color.lerp(blockedBase, const Color(0xFF000000), 0.5)!;
    final baseGrad = ui.Gradient.radial(
      Offset(_s * 0.5, _s * 0.5), _s * 0.8,
      [blockedBase, blockedDark, blockedDarker],
      [0.0, 0.6, 1.0],
    );
    c.drawRect(Rect.fromLTWH(0, 0, _s, _s), Paint()..shader = baseGrad);

    // Richer organic noise with more contrast
    for (int i = 0; i < 140; i++) {
      final px = rng.nextDouble() * _s;
      final py = rng.nextDouble() * _s;
      final n = _fbm(px, py, seed);
      final r = 2.0 + n * 5.0;
      final brightness = (25 + n * 45).round().clamp(0, 255);
      c.drawCircle(Offset(px, py), r,
          Paint()..color = Color.fromARGB(45, brightness, brightness + 25, brightness - 5));
    }

    switch (variant) {
      case 0:
        _drawSmoothPineTree(c, _s * 0.5, _s * 0.8, 38, rng);
        break;
      case 1:
        _drawSmoothRock(c, _s * 0.35, _s * 0.55, 16);
        _drawSmoothRock(c, _s * 0.65, _s * 0.45, 12);
        _drawSmoothRock(c, _s * 0.5, _s * 0.7, 9);
        break;
      case 2:
        _drawSmoothBushCluster(c, rng);
        break;
      case 3:
        _drawSmoothDeadTree(c, _s * 0.5, _s * 0.85, rng);
        break;
    }

    // Dark vignette for depth
    c.drawRect(
      Rect.fromLTWH(0, 0, _s, _s),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(_s * 0.5, _s * 0.5), _s * 0.7,
          [const Color(0x00000000), const Color(0x25000000)],
        ),
    );
  }

  void _drawSmoothPineTree(Canvas c, double cx, double baseY, double height, math.Random rng) {
    // Shadow
    c.drawOval(
      Rect.fromCenter(center: Offset(cx + 2, baseY), width: height * 0.5, height: height * 0.12),
      Paint()..color = const Color(0x30000000),
    );

    // Trunk
    final trunkW = height * 0.08;
    final trunkH = height * 0.35;
    final trunkGrad = ui.Gradient.linear(
      Offset(cx - trunkW, 0), Offset(cx + trunkW, 0),
      [const Color(0xFF4A3015), const Color(0xFF6A4520), const Color(0xFF3A2510)],
      [0.0, 0.4, 1.0],
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, baseY - trunkH * 0.5), width: trunkW * 2, height: trunkH),
        Radius.circular(trunkW * 0.3),
      ),
      Paint()..shader = trunkGrad,
    );

    // Canopy — 3 triangular layers with gradients
    for (int layer = 0; layer < 3; layer++) {
      final layerY = baseY - trunkH * 0.6 - layer * height * 0.2;
      final layerW = height * (0.45 - layer * 0.08);
      final layerH = height * 0.3;

      final canopy = Path()
        ..moveTo(cx - layerW, layerY)
        ..lineTo(cx, layerY - layerH)
        ..lineTo(cx + layerW, layerY)
        ..close();

      final canopyBase = _currentBiome.decorationColors.isNotEmpty
          ? _currentBiome.decorationColors[0]
          : _currentBiome.groundBase;
      final canopyLight = _currentBiome.decorationColors.length > 2
          ? _currentBiome.decorationColors[2]
          : _currentBiome.groundAccent;
      final canopyGrad = ui.Gradient.linear(
        Offset(cx - layerW, layerY), Offset(cx + layerW, layerY),
        [
          canopyBase,
          canopyLight,
          canopyBase,
        ],
        [0.0, 0.5, 1.0],
      );
      c.drawPath(canopy, Paint()..shader = canopyGrad);

      // Edge highlight
      c.drawPath(canopy, Paint()
        ..color = Color.lerp(canopyLight, const Color(0xFFFFFFFF), 0.2)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);

      // Snow/light on tips
      c.drawCircle(Offset(cx, layerY - layerH + 2), 2,
          Paint()..color = const Color(0x40DDEECC));
    }
  }

  void _drawSmoothBushCluster(Canvas c, math.Random rng) {
    final bushPositions = [
      [_s * 0.3, _s * 0.55, 18.0],
      [_s * 0.6, _s * 0.45, 15.0],
      [_s * 0.45, _s * 0.7, 16.0],
      [_s * 0.7, _s * 0.65, 12.0],
    ];

    for (final b in bushPositions) {
      final bx = b[0], by = b[1], br = b[2];

      // Shadow
      c.drawOval(
        Rect.fromCenter(center: Offset(bx + 1, by + br * 0.3), width: br * 2, height: br * 0.5),
        Paint()..color = const Color(0x25000000),
      );

      // Bush body
      final bushLight = _currentBiome.decorationColors.length > 2
          ? _currentBiome.decorationColors[2]
          : _currentBiome.groundAccent;
      final bushMid = _currentBiome.decorationColors.isNotEmpty
          ? _currentBiome.decorationColors[0]
          : _currentBiome.groundBase;
      final bushDark = _currentBiome.decorationColors.length > 1
          ? _currentBiome.decorationColors[1]
          : Color.lerp(_currentBiome.groundBase, const Color(0xFF000000), 0.2)!;
      final bushGrad = ui.Gradient.radial(
        Offset(bx - br * 0.2, by - br * 0.2), br * 1.2,
        [bushLight, bushMid, bushDark],
        [0.0, 0.5, 1.0],
      );
      c.drawCircle(Offset(bx, by), br, Paint()..shader = bushGrad);

      // Highlight
      c.drawCircle(Offset(bx - br * 0.25, by - br * 0.3), br * 0.35,
          Paint()..color = bushLight.withAlpha(0x25));

      // Leaf texture bumps
      final leafColor = _currentBiome.decorationColors.isNotEmpty
          ? _currentBiome.decorationColors[0]
          : _currentBiome.groundAccent;
      for (int i = 0; i < 5; i++) {
        final lx = bx + (rng.nextDouble() - 0.5) * br * 1.2;
        final ly = by + (rng.nextDouble() - 0.5) * br * 1.2;
        if (math.sqrt(math.pow(lx - bx, 2) + math.pow(ly - by, 2)) < br * 0.9) {
          c.drawCircle(Offset(lx, ly), 2 + rng.nextDouble() * 3,
              Paint()..color = leafColor.withAlpha(30));
        }
      }
    }
  }

  void _drawSmoothDeadTree(Canvas c, double cx, double baseY, math.Random rng) {
    // Shadow
    c.drawOval(
      Rect.fromCenter(center: Offset(cx + 2, baseY), width: 30, height: 6),
      Paint()..color = const Color(0x30000000),
    );

    // Trunk
    final trunkPath = Path()
      ..moveTo(cx - 4, baseY)
      ..quadraticBezierTo(cx - 3, baseY - 25, cx - 1, baseY - 50)
      ..lineTo(cx + 1, baseY - 50)
      ..quadraticBezierTo(cx + 3, baseY - 25, cx + 4, baseY)
      ..close();
    final trunkGrad = ui.Gradient.linear(
      Offset(cx - 5, 0), Offset(cx + 5, 0),
      [const Color(0xFF5A3A20), const Color(0xFF7A5530), const Color(0xFF3A2510)],
      [0.0, 0.35, 1.0],
    );
    c.drawPath(trunkPath, Paint()..shader = trunkGrad);

    // Root flare
    for (int i = -1; i <= 1; i += 2) {
      final rootPath = Path()
        ..moveTo(cx + i * 3, baseY)
        ..quadraticBezierTo(cx + i * 10, baseY - 3, cx + i * 14, baseY + 1);
      c.drawPath(rootPath, Paint()
        ..color = const Color(0xFF5A3A20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round);
    }

    // Branches
    final branches = [
      [cx + 0.0, baseY - 40.0, cx + 18.0, baseY - 52.0, cx + 25.0, baseY - 48.0],
      [cx + 0.0, baseY - 35.0, cx - 15.0, baseY - 45.0, cx - 22.0, baseY - 42.0],
      [cx + 0.0, baseY - 25.0, cx + 12.0, baseY - 32.0, cx + 18.0, baseY - 30.0],
      [cx + 0.0, baseY - 20.0, cx - 10.0, baseY - 25.0, cx - 15.0, baseY - 22.0],
    ];

    for (final br in branches) {
      final branchPath = Path()
        ..moveTo(br[0], br[1])
        ..quadraticBezierTo(br[2], br[3], br[4], br[5]);
      c.drawPath(branchPath, Paint()
        ..color = const Color(0xFF5A3A20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);
    }
  }

  // =========================================================================
  //  SPAWN TILE
  // =========================================================================

  void _paintSpawn(Canvas c) {
    // Dark red radial gradient
    final baseGrad = ui.Gradient.radial(
      Offset(_s * 0.5, _s * 0.5), _s * 0.7,
      [const Color(0xFFBB3030), const Color(0xFF8A2020), const Color(0xFF551515)],
      [0.0, 0.5, 1.0],
    );
    c.drawRect(Rect.fromLTWH(0, 0, _s, _s), Paint()..shader = baseGrad);

    // Rune circle
    final center = Offset(_s * 0.5, _s * 0.5);
    c.drawCircle(center, _s * 0.38, Paint()
      ..color = const Color(0x55FF5555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0);
    c.drawCircle(center, _s * 0.28, Paint()
      ..color = const Color(0x44FF7777)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Cross
    c.drawLine(Offset(_s * 0.2, _s * 0.5), Offset(_s * 0.8, _s * 0.5),
        Paint()..color = const Color(0x66FF6666)..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    c.drawLine(Offset(_s * 0.5, _s * 0.2), Offset(_s * 0.5, _s * 0.8),
        Paint()..color = const Color(0x66FF6666)..strokeWidth = 2.0..strokeCap = StrokeCap.round);

    // Diagonal lines
    c.drawLine(Offset(_s * 0.25, _s * 0.25), Offset(_s * 0.75, _s * 0.75),
        Paint()..color = const Color(0x33FF5555)..strokeWidth = 1.2);
    c.drawLine(Offset(_s * 0.75, _s * 0.25), Offset(_s * 0.25, _s * 0.75),
        Paint()..color = const Color(0x33FF5555)..strokeWidth = 1.2);

    // Center glow
    final glowGrad = ui.Gradient.radial(
      center, _s * 0.15,
      [const Color(0x66FFAAAA), const Color(0x00FF0000)],
    );
    c.drawCircle(center, _s * 0.15, Paint()..shader = glowGrad);

    // Corner rune marks
    for (final corner in [
      Offset(_s * 0.12, _s * 0.12),
      Offset(_s * 0.88, _s * 0.12),
      Offset(_s * 0.12, _s * 0.88),
      Offset(_s * 0.88, _s * 0.88),
    ]) {
      c.drawCircle(corner, 4, Paint()..color = const Color(0x55DD4444));
      c.drawCircle(corner, 2, Paint()..color = const Color(0x77FF6666));
    }

    // Smoke/particle texture
    final rng = math.Random(666);
    for (int i = 0; i < 30; i++) {
      final px = rng.nextDouble() * _s;
      final py = rng.nextDouble() * _s;
      c.drawCircle(Offset(px, py), 1.5 + rng.nextDouble() * 2,
          Paint()..color = Color.fromARGB(15 + rng.nextInt(20), 40, 0, 0));
    }
  }

  // =========================================================================
  //  CASTLE GROUND TILE
  // =========================================================================

  void _paintCastleGround(Canvas c) {
    // Warm golden base
    c.drawRect(Rect.fromLTWH(0, 0, _s, _s),
        Paint()..color = const Color(0xFFAA7520));

    // Stone brick pattern
    final brickColors = [
      const Color(0xFFD4A843),
      const Color(0xFFC49838),
      const Color(0xFFDDB853),
      const Color(0xFFBA8A30),
    ];

    double y = -1;
    int rowIdx = 0;
    while (y < _s + 5) {
      final brickH = 12.0 + (rowIdx % 2) * 2;
      final xOff = (rowIdx % 2 == 0) ? 0.0 : 14.0;
      double x = -xOff;
      int colIdx = 0;
      while (x < _s + 5) {
        final brickW = 22.0 + (colIdx % 3) * 4;
        final color = brickColors[(colIdx + rowIdx) % brickColors.length];

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, y + 1, brickW - 2, brickH - 2),
          const Radius.circular(1.5),
        );

        // Brick gradient
        final grad = ui.Gradient.linear(
          Offset(x, y), Offset(x, y + brickH),
          [Color.lerp(color, Colors.white, 0.1)!, color, Color.lerp(color, Colors.black, 0.1)!],
          [0.0, 0.4, 1.0],
        );
        c.drawRRect(rect, Paint()..shader = grad);

        x += brickW;
        colIdx++;
      }
      y += brickH;
      rowIdx++;
    }

    // Mortar lines
    y = -1;
    rowIdx = 0;
    while (y < _s + 5) {
      final brickH = 12.0 + (rowIdx % 2) * 2;
      c.drawLine(Offset(0, y + brickH), Offset(_s, y + brickH),
          Paint()..color = const Color(0xFF7A5510)..strokeWidth = 1.5);
      final xOff = (rowIdx % 2 == 0) ? 0.0 : 14.0;
      double x = -xOff;
      int colIdx = 0;
      while (x < _s + 5) {
        final brickW = 22.0 + (colIdx % 3) * 4;
        c.drawLine(Offset(x + brickW, y), Offset(x + brickW, y + brickH),
            Paint()..color = const Color(0xFF7A5510)..strokeWidth = 1.2);
        x += brickW;
        colIdx++;
      }
      y += brickH;
      rowIdx++;
    }

    // Royal crest overlay
    final center = Offset(_s * 0.5, _s * 0.5);
    // Shield shape
    final shield = Path()
      ..moveTo(center.dx - 14, center.dy - 16)
      ..lineTo(center.dx + 14, center.dy - 16)
      ..lineTo(center.dx + 14, center.dy + 4)
      ..quadraticBezierTo(center.dx + 14, center.dy + 14, center.dx, center.dy + 20)
      ..quadraticBezierTo(center.dx - 14, center.dy + 14, center.dx - 14, center.dy + 4)
      ..close();
    c.drawPath(shield, Paint()..color = const Color(0x30000000)); // shadow
    c.drawPath(shield, Paint()..color = const Color(0x338A6A20));
    c.drawPath(shield, Paint()
      ..color = const Color(0x55DDB853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Cross on shield
    c.drawLine(Offset(center.dx, center.dy - 10), Offset(center.dx, center.dy + 10),
        Paint()..color = const Color(0x44FFDD88)..strokeWidth = 3..strokeCap = StrokeCap.round);
    c.drawLine(Offset(center.dx - 8, center.dy), Offset(center.dx + 8, center.dy),
        Paint()..color = const Color(0x44FFDD88)..strokeWidth = 3..strokeCap = StrokeCap.round);

    // Golden sheen
    c.drawRect(
      Rect.fromLTWH(0, 0, _s, _s),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(_s, _s),
          [const Color(0x0AFFFFFF), const Color(0x00000000), const Color(0x06000000)],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  // =========================================================================
  //  TERRAIN TEXTURES (512x512, for MapGroundLayer)
  // =========================================================================

  /// Tries to load a terrain texture from assets. Returns null if not found.
  Future<ui.Image?> _loadTerrainAsset(String name) async {
    try {
      final data = await rootBundle.load('assets/images/textures/$name');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      debugPrint('SpriteCache: Loaded texture asset: $name');
      return frame.image;
    } catch (_) {
      debugPrint('SpriteCache: Asset not found: $name, using procedural fallback');
      return null;
    }
  }

  Future<ui.Image> _renderTerrainTile(
      int sz, void Function(Canvas c, int size) painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas, sz);
    final picture = recorder.endRecording();
    final image = await picture.toImage(sz, sz);
    picture.dispose();
    return image;
  }

  void _paintTerrainGrass(Canvas c, int sz) {
    final s = sz.toDouble();
    final rng = math.Random(42);

    c.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = _currentBiome.groundBase);

    // Softened contrast (~20% less) to keep background subordinate to towers
    final darkGround =
        Color.lerp(_currentBiome.groundBase, const Color(0xFF000000), 0.05)!;
    final midGround = Color.lerp(_currentBiome.groundAccent, _currentBiome.groundBase, 0.15)!;
    final lightGround =
        Color.lerp(_currentBiome.groundAccent, const Color(0xFFFFFFFF), 0.08)!;

    for (int i = 0; i < 550; i++) {
      final px = rng.nextDouble() * s;
      final py = rng.nextDouble() * s;
      final n = _perlin.fbm(px / 80, py / 80, octaves: 4);
      final r = 3.0 + n * 8.0;

      Color col;
      if (n < 0.25) {
        col = darkGround.withAlpha((8 + rng.nextInt(8)).clamp(0, 255));
      } else if (n < 0.55) {
        col = midGround.withAlpha((12 + rng.nextInt(10)).clamp(0, 255));
      } else {
        col = lightGround.withAlpha((10 + rng.nextInt(10)).clamp(0, 255));
      }
      c.drawCircle(Offset(px, py), r, Paint()..color = col);
    }

    // Grass blades (reduced for softer background)
    for (int i = 0; i < 50; i++) {
      final bx = rng.nextDouble() * s;
      final by = rng.nextDouble() * s;
      final h = 5.0 + rng.nextDouble() * 10.0;
      final lean = (rng.nextDouble() - 0.5) * 6;
      final bladeColor = Color.lerp(
        _currentBiome.groundBase,
        _currentBiome.groundAccent,
        rng.nextDouble(),
      )!
          .withAlpha(70);

      c.drawPath(
        Path()
          ..moveTo(bx, by)
          ..quadraticBezierTo(
              bx + lean * 0.5, by - h * 0.6, bx + lean, by - h),
        Paint()
          ..color = bladeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    c.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(s, s),
          [
            const Color(0x04FFFFFF),
            const Color(0x00000000),
            const Color(0x04000000),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  void _paintTerrainPath(Canvas c, int sz) {
    final s = sz.toDouble();
    final rng = math.Random(77);

    c.drawRect(
        Rect.fromLTWH(0, 0, s, s), Paint()..color = _currentBiome.pathBase);

    final stoneColors = [
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.15)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.25)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.30)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.20)!,
      Color.lerp(_currentBiome.pathAccent, const Color(0xFFFFFFFF), 0.40)!,
    ];

    double y = -2.0;
    int rowIdx = 0;
    while (y < s + 5) {
      final stoneH = 14.0 + (rowIdx % 3) * 3;
      final xOffset = (rowIdx % 2 == 0) ? 0.0 : 16.0;
      double x = -xOffset;
      int colIdx = 0;
      while (x < s + 5) {
        final stoneW = 24.0 + ((colIdx + rowIdx) % 4) * 5;
        final color = stoneColors[(colIdx + rowIdx * 3) % stoneColors.length];
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1.5, y + 1.5, stoneW - 3, stoneH - 3),
          Radius.circular(2.5 + rng.nextDouble()),
        );
        final stoneGrad = ui.Gradient.linear(
          Offset(x, y),
          Offset(x + stoneW, y + stoneH),
          [
            Color.lerp(color, Colors.white, 0.12)!,
            color,
            Color.lerp(color, Colors.black, 0.15)!,
          ],
          [0.0, 0.4, 1.0],
        );
        c.drawRRect(rect, Paint()..shader = stoneGrad);

        for (int t = 0; t < 3; t++) {
          final tx = x + 4 + rng.nextDouble() * (stoneW - 8);
          final ty = y + 4 + rng.nextDouble() * (stoneH - 8);
          c.drawCircle(
            Offset(tx, ty),
            1.0 + rng.nextDouble() * 1.5,
            Paint()
              ..color =
                  Color.lerp(color, Colors.black, 0.08)!.withAlpha(40),
          );
        }

        x += stoneW;
        colIdx++;
      }
      y += stoneH;
      rowIdx++;
    }

    // Mortar lines
    final mortarColor =
        Color.lerp(_currentBiome.pathBase, const Color(0xFF000000), 0.3)!;
    y = -2.0;
    rowIdx = 0;
    while (y < s + 5) {
      final stoneH = 14.0 + (rowIdx % 3) * 3;
      c.drawLine(
        Offset(0, y + stoneH),
        Offset(s, y + stoneH),
        Paint()
          ..color = mortarColor
          ..strokeWidth = 2.2,
      );
      final xOffset = (rowIdx % 2 == 0) ? 0.0 : 16.0;
      double x = -xOffset;
      int colIdx = 0;
      while (x < s + 5) {
        final stoneW = 24.0 + ((colIdx + rowIdx) % 4) * 5;
        c.drawLine(
          Offset(x + stoneW, y),
          Offset(x + stoneW, y + stoneH),
          Paint()
            ..color = mortarColor
            ..strokeWidth = 1.8,
        );
        x += stoneW;
        colIdx++;
      }
      y += stoneH;
      rowIdx++;
    }

    // Wear overlay
    final dirtColor =
        Color.lerp(_currentBiome.pathBase, const Color(0xFF000000), 0.2)!;
    for (int i = 0; i < 80; i++) {
      c.drawCircle(
        Offset(rng.nextDouble() * s, rng.nextDouble() * s),
        1.5 + rng.nextDouble() * 3,
        Paint()..color = dirtColor.withAlpha(12 + rng.nextInt(12)),
      );
    }

    // Center-lighter / edges-darker gradient for path depth
    c.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, s),
          [
            const Color(0x14000000), // top edge darker
            const Color(0x08FFFFFF), // center lighter
            const Color(0x14000000), // bottom edge darker
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  void _paintTerrainBlocked(Canvas c, int sz) {
    final s = sz.toDouble();
    final rng = math.Random(31);

    final blockedBase = _currentBiome.decorationColors.isNotEmpty
        ? _currentBiome.decorationColors[0]
        : _currentBiome.groundBase;
    final blockedDark =
        Color.lerp(blockedBase, const Color(0xFF000000), 0.35)!;

    c.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = blockedDark);

    for (int i = 0; i < 600; i++) {
      final px = rng.nextDouble() * s;
      final py = rng.nextDouble() * s;
      final n = _perlin.fbm(px / 60, py / 60, octaves: 4);
      final r = 2.5 + n * 8.0;
      final brightness = (20 + n * 40).round().clamp(0, 255);
      c.drawCircle(
        Offset(px, py),
        r,
        Paint()
          ..color = Color.fromARGB(
              40, brightness, (brightness + 20).clamp(0, 255), (brightness - 5).clamp(0, 255)),
      );
    }

    // Moss patches
    for (int i = 0; i < 30; i++) {
      final px = rng.nextDouble() * s;
      final py = rng.nextDouble() * s;
      final n = _perlin.fbm(px / 40 + 100, py / 40 + 100, octaves: 3);
      if (n > 0.55) {
        c.drawCircle(
          Offset(px, py),
          4 + rng.nextDouble() * 8,
          Paint()
            ..color = Color.lerp(
                    blockedBase, _currentBiome.groundBase, 0.5)!
                .withAlpha(30),
        );
      }
    }

    c.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(s * 0.5, s * 0.5),
          s * 0.7,
          [const Color(0x00000000), const Color(0x20000000)],
        ),
    );
  }

  void _paintTerrainSpawn(Canvas c, int sz) {
    final s = sz.toDouble();
    final rng = math.Random(666);

    c.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(s * 0.5, s * 0.5),
          s * 0.7,
          [
            const Color(0xFFBB3030),
            const Color(0xFF8A2020),
            const Color(0xFF551515),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    final center = Offset(s * 0.5, s * 0.5);
    c.drawCircle(
      center,
      s * 0.38,
      Paint()
        ..color = const Color(0x55FF5555)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    c.drawCircle(
      center,
      s * 0.28,
      Paint()
        ..color = const Color(0x44FF7777)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    c.drawLine(
      Offset(s * 0.2, s * 0.5),
      Offset(s * 0.8, s * 0.5),
      Paint()
        ..color = const Color(0x66FF6666)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      Offset(s * 0.5, s * 0.2),
      Offset(s * 0.5, s * 0.8),
      Paint()
        ..color = const Color(0x66FF6666)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    c.drawCircle(
      center,
      s * 0.15,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          s * 0.15,
          [const Color(0x66FFAAAA), const Color(0x00FF0000)],
        ),
    );

    for (int i = 0; i < 50; i++) {
      c.drawCircle(
        Offset(rng.nextDouble() * s, rng.nextDouble() * s),
        1.5 + rng.nextDouble() * 2,
        Paint()
          ..color = Color.fromARGB(12 + rng.nextInt(18), 40, 0, 0),
      );
    }
  }

  void _paintTerrainCastle(Canvas c, int sz) {
    final s = sz.toDouble();
    c.drawRect(
        Rect.fromLTWH(0, 0, s, s), Paint()..color = const Color(0xFFAA7520));

    final brickColors = [
      const Color(0xFFD4A843),
      const Color(0xFFC49838),
      const Color(0xFFDDB853),
      const Color(0xFFBA8A30),
    ];

    double y = -1;
    int rowIdx = 0;
    while (y < s + 5) {
      final brickH = 14.0 + (rowIdx % 2) * 3;
      final xOff = (rowIdx % 2 == 0) ? 0.0 : 18.0;
      double x = -xOff;
      int colIdx = 0;
      while (x < s + 5) {
        final brickW = 28.0 + (colIdx % 3) * 5;
        final color = brickColors[(colIdx + rowIdx) % brickColors.length];
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, y + 1, brickW - 2, brickH - 2),
            const Radius.circular(1.5),
          ),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x, y),
              Offset(x, y + brickH),
              [
                Color.lerp(color, Colors.white, 0.1)!,
                color,
                Color.lerp(color, Colors.black, 0.1)!,
              ],
              [0.0, 0.4, 1.0],
            ),
        );
        x += brickW;
        colIdx++;
      }
      y += brickH;
      rowIdx++;
    }

    // Mortar lines
    y = -1;
    rowIdx = 0;
    while (y < s + 5) {
      final brickH = 14.0 + (rowIdx % 2) * 3;
      c.drawLine(
        Offset(0, y + brickH),
        Offset(s, y + brickH),
        Paint()
          ..color = const Color(0xFF7A5510)
          ..strokeWidth = 1.8,
      );
      final xOff = (rowIdx % 2 == 0) ? 0.0 : 18.0;
      double x = -xOff;
      int colIdx = 0;
      while (x < s + 5) {
        final brickW = 28.0 + (colIdx % 3) * 5;
        c.drawLine(
          Offset(x + brickW, y),
          Offset(x + brickW, y + brickH),
          Paint()
            ..color = const Color(0xFF7A5510)
            ..strokeWidth = 1.5,
        );
        x += brickW;
        colIdx++;
      }
      y += brickH;
      rowIdx++;
    }

    c.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(s, s),
          [
            const Color(0x08FFFFFF),
            const Color(0x00000000),
            const Color(0x05000000),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }
}
