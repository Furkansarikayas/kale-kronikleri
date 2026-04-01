import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tower_data.dart';
import '../../data/t4_branch_data.dart';

/// Procedural sprite generator for all tower types and tiers.
///
/// Generates 12 tower types x 4 tiers = 48 sprites at 256x256 resolution,
/// cached as [ui.Image] for fast rendering via `drawImageRect`.
///
/// Dark-fantasy style with neon glow accents, detailed texturing,
/// and distinct silhouettes per tower type.
class TowerSpriteGenerator {
  static final TowerSpriteGenerator instance = TowerSpriteGenerator._();
  TowerSpriteGenerator._();

  final Map<String, ui.Image> _cache = {};
  static const int spriteSize = 256;
  static const double _s = 256.0;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    for (final type in TowerType.values) {
      for (int tier = 1; tier <= 4; tier++) {
        final key = _cacheKey(type, tier);
        // Try loading PNG asset first
        final pngPath = 'assets/images/towers/${type.name}_t$tier.webp';
        final pngImage = await _tryLoadPng(pngPath);
        if (pngImage != null) {
          _cache[key] = pngImage;
        } else {
          // Fallback to procedural generation
          _cache[key] = await _renderSprite((canvas) {
            _paintTower(canvas, type, tier);
          });
        }
      }
      // Load T4 branch variants (pathA / pathB)
      for (final branch in ['a', 'b']) {
        final branchKey = '${type.name}_t4$branch';
        final branchPath = 'assets/images/towers/${type.name}_t4$branch.webp';
        final branchImage = await _tryLoadPng(branchPath);
        if (branchImage != null) {
          _cache[branchKey] = branchImage;
        }
      }
    }

    _initialized = true;
  }

  /// Attempts to load a PNG image from the asset bundle.
  /// Returns the decoded [ui.Image] scaled to 256x256, or `null` if the asset
  /// does not exist or cannot be decoded.
  Future<ui.Image?> _tryLoadPng(String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: spriteSize,
        targetHeight: spriteSize,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  ui.Image? getSprite(TowerType type, int tier, [T4BranchPath branch = T4BranchPath.none]) {
    // If T4 with a branch selected, try branch-specific sprite first
    if (tier == 4 && branch != T4BranchPath.none) {
      final suffix = branch == T4BranchPath.pathA ? 'a' : 'b';
      final branchKey = '${type.name}_t4$suffix';
      final branchSprite = _cache[branchKey];
      if (branchSprite != null) return branchSprite;
    }
    return _cache[_cacheKey(type, tier)];
  }

  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _initialized = false;
  }

  String _cacheKey(TowerType type, int tier) => '${type.name}_$tier';

  Future<ui.Image> _renderSprite(void Function(Canvas c) painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(spriteSize, spriteSize);
    picture.dispose();
    return image;
  }

  // ---------------------------------------------------------------------------
  // Color helpers
  // ---------------------------------------------------------------------------

  static Color _lighten(Color c, double amount) {
    final r = (c.red + (255 - c.red) * amount).round().clamp(0, 255);
    final g = (c.green + (255 - c.green) * amount).round().clamp(0, 255);
    final b = (c.blue + (255 - c.blue) * amount).round().clamp(0, 255);
    return Color.fromARGB(c.alpha, r, g, b);
  }

  static Color _darken(Color c, double amount) {
    final r = (c.red * (1 - amount)).round().clamp(0, 255);
    final g = (c.green * (1 - amount)).round().clamp(0, 255);
    final b = (c.blue * (1 - amount)).round().clamp(0, 255);
    return Color.fromARGB(c.alpha, r, g, b);
  }

  // ---------------------------------------------------------------------------
  // Shared drawing helpers
  // ---------------------------------------------------------------------------

  /// Draws stone/brick texture inside a rectangular region.
  void _drawBrickTexture(Canvas canvas, Rect area, Color baseColor,
      {double brickH = 12, double brickW = 24, double mortarWidth = 1.0}) {
    final mortar = Paint()
      ..color = _darken(baseColor, 0.25).withAlpha(60)
      ..strokeWidth = mortarWidth;
    final highlight = Paint()
      ..color = _lighten(baseColor, 0.15).withAlpha(25)
      ..strokeWidth = 0.5;

    int row = 0;
    for (double y = area.top; y < area.bottom; y += brickH) {
      // Horizontal mortar
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), mortar);
      // Staggered vertical mortar
      final off = (row % 2 == 0) ? 0.0 : brickW * 0.5;
      for (double x = area.left + off; x < area.right; x += brickW) {
        canvas.drawLine(
            Offset(x, y), Offset(x, (y + brickH).clamp(y, area.bottom)), mortar);
        // Per-brick subtle highlight on top-left
        canvas.drawLine(
            Offset(x + 2, y + 1),
            Offset(x + brickW * 0.6, y + 1),
            highlight);
      }
      row++;
    }
  }

  /// Draws glowing runic circle (for tier 3-4).
  void _drawRunicCircle(Canvas canvas, Offset center, double radius,
      Color glowCol, int tier) {
    if (tier < 3) return;
    final segments = 8 + tier * 4;
    final runeP = Paint()
      ..color = glowCol.withAlpha(tier == 4 ? 180 : 100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tier == 4 ? 4 : 2);

    canvas.drawCircle(center, radius, runeP);

    // Tick marks around circle
    for (int i = 0; i < segments; i++) {
      final a = i * math.pi * 2 / segments;
      final inner = radius - 4;
      final outer = radius + 4;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(a), center.dy + inner * math.sin(a)),
        Offset(center.dx + outer * math.cos(a), center.dy + outer * math.sin(a)),
        runeP,
      );
    }

    if (tier == 4) {
      // Second inner runic ring
      canvas.drawCircle(center, radius * 0.75, Paint()
        ..color = glowCol.withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  /// Draws floating energy particles around a center.
  void _drawFloatingParticles(Canvas canvas, Offset center, double radius,
      Color color, int count) {
    for (int i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count;
      final r = radius * (0.9 + (i % 3) * 0.1);
      final px = center.dx + r * math.cos(a);
      final py = center.dy + r * math.sin(a);
      final sz = 2.0 + (i % 2);
      canvas.drawCircle(Offset(px, py), sz, Paint()
        ..color = color.withAlpha(160)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  /// Draws the ground shadow ellipse.
  void _drawGroundShadow(Canvas canvas, Offset center, double width, int tier) {
    final sy = center.dy + _s * 0.32;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 3, sy + 4),
          width: width, height: _s * 0.14),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 1, sy + 2),
          width: width * 0.8, height: _s * 0.09),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  /// Draws tier indicator stars at the bottom.
  void _drawTierStars(Canvas canvas, int tier) {
    if (tier < 1) return;
    final starR = _s * 0.024;
    final starY = _s * 0.92;
    final totalW = tier * starR * 3.2;
    final startX = _s / 2 - totalW / 2 + starR * 1.6;

    for (int i = 0; i < tier; i++) {
      final sx = startX + i * starR * 3.2;
      final color = tier >= 4 ? const Color(0xFFFFD700) : const Color(0xCCFFD700);

      canvas.drawCircle(Offset(sx, starY), starR * 2.0, Paint()
        ..color = color.withAlpha(tier >= 4 ? 50 : 25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

      _drawStarShape(canvas, sx, starY, starR, color);

      canvas.drawCircle(Offset(sx, starY), starR * 0.3, Paint()
        ..color = const Color(0xAAFFFFFF));
    }
  }

  void _drawStarShape(Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerA = i * math.pi * 2 / 5 - math.pi / 2;
      final innerA = outerA + math.pi / 5;
      if (i == 0) {
        path.moveTo(cx + r * math.cos(outerA), cy + r * math.sin(outerA));
      } else {
        path.lineTo(cx + r * math.cos(outerA), cy + r * math.sin(outerA));
      }
      path.lineTo(cx + r * 0.45 * math.cos(innerA), cy + r * 0.45 * math.sin(innerA));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()
      ..color = _darken(color, 0.3).withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }

  // ---------------------------------------------------------------------------
  // Main paint dispatcher
  // ---------------------------------------------------------------------------

  void _paintTower(Canvas canvas, TowerType type, int tier) {
    switch (type) {
      case TowerType.arrow:
        _paintArrowTower(canvas, tier);
      case TowerType.fire:
        _paintFireTower(canvas, tier);
      case TowerType.ice:
        _paintIceTower(canvas, tier);
      case TowerType.lightning:
        _paintLightningTower(canvas, tier);
      case TowerType.poison:
        _paintPoisonTower(canvas, tier);
      case TowerType.water:
        _paintWaterTower(canvas, tier);
      case TowerType.dark:
        _paintDarkTower(canvas, tier);
      case TowerType.holy:
        _paintHolyTower(canvas, tier);
      case TowerType.cannon:
        _paintCannonTower(canvas, tier);
      case TowerType.wizard:
        _paintWizardTower(canvas, tier);
      case TowerType.support:
        _paintSupportTower(canvas, tier);
      case TowerType.spikeWall:
        _paintSpikeWallTower(canvas, tier);
    }
    _drawTierStars(canvas, tier);
  }

  // ===========================================================================
  //  1. ARROW TOWER - Tall wooden/stone watchtower with crossbow
  // ===========================================================================

  void _paintArrowTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFFd4a843);
    final glowA = (80 + tier * 30).clamp(0, 255);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.55, tier);

    // --- Stone base ---
    final baseW = _s * 0.50;
    final baseH = _s * 0.14;
    final baseTop = cy + _s * 0.18;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    final baseGrad = ui.Gradient.linear(
      Offset(baseRect.left, baseRect.top),
      Offset(baseRect.right, baseRect.bottom),
      [const Color(0xFF6B6B6B), const Color(0xFF4A4A4A), const Color(0xFF3A3A3A)],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
        Paint()..shader = baseGrad);
    _drawBrickTexture(canvas, baseRect, const Color(0xFF555555), brickH: 10, brickW: 18);

    // --- Wooden tower body (tapered) ---
    final bodyBotW = _s * (0.34 + tier * 0.01);
    final bodyTopW = _s * (0.24 + tier * 0.005);
    final bodyBot = baseTop + 2;
    final bodyTop = cy - _s * (0.22 + tier * 0.02);

    final bodyPath = Path()
      ..moveTo(cx - bodyBotW / 2, bodyBot)
      ..lineTo(cx - bodyTopW / 2, bodyTop)
      ..lineTo(cx + bodyTopW / 2, bodyTop)
      ..lineTo(cx + bodyBotW / 2, bodyBot)
      ..close();

    // Wood grain gradient
    final woodGrad = ui.Gradient.linear(
      Offset(cx - bodyBotW / 2, 0), Offset(cx + bodyBotW / 2, 0),
      [const Color(0xFF5C3D1E), const Color(0xFF7D5A3A), const Color(0xFF6B4A2A),
       const Color(0xFF4A3218)],
      [0.0, 0.35, 0.65, 1.0],
    );
    canvas.drawPath(bodyPath, Paint()..shader = woodGrad);

    // Horizontal wood planks
    final plankP = Paint()
      ..color = const Color(0x30000000)
      ..strokeWidth = 1.0;
    for (double y = bodyBot - 8; y > bodyTop + 4; y -= 14) {
      final t = (bodyBot - y) / (bodyBot - bodyTop);
      final w = bodyBotW + (bodyTopW - bodyBotW) * t;
      canvas.drawLine(Offset(cx - w / 2 + 2, y), Offset(cx + w / 2 - 2, y), plankP);
    }

    // Left highlight
    canvas.drawLine(
      Offset(cx - bodyBotW / 2 + 5, bodyBot - 4),
      Offset(cx - bodyTopW / 2 + 5, bodyTop + 4),
      Paint()..color = const Color(0x25FFFFFF)..strokeWidth = 3..strokeCap = StrokeCap.round,
    );

    // Body outline
    canvas.drawPath(bodyPath, Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // --- Window slits ---
    final slitCount = tier;
    for (int i = 0; i < slitCount; i++) {
      final frac = (i + 1) / (slitCount + 1);
      final sy = bodyBot + (bodyTop - bodyBot) * frac;
      final t = (bodyBot - sy) / (bodyBot - bodyTop);
      final w = bodyBotW + (bodyTopW - bodyBotW) * t;
      final slitW = w * 0.18;
      final slitH = 8.0;
      final slitRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, sy), width: slitW, height: slitH),
        const Radius.circular(3));
      canvas.drawRRect(slitRect, Paint()..color = const Color(0xCC1A1A1A));
      canvas.drawRRect(slitRect, Paint()
        ..color = glow.withAlpha(40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // --- Crenellations at top ---
    final crenCount = 3 + tier;
    final crenW = bodyTopW / crenCount;
    final crenH = 10.0 + tier * 2;
    for (int i = 0; i < crenCount; i++) {
      if (i % 2 == 0) continue;
      final mx = cx - bodyTopW / 2 + i * crenW;
      canvas.drawRect(
        Rect.fromLTWH(mx, bodyTop - crenH, crenW * 0.8, crenH + 2),
        Paint()..color = const Color(0xFF5C3D1E));
      canvas.drawRect(
        Rect.fromLTWH(mx, bodyTop - crenH, crenW * 0.8, crenH + 2),
        Paint()..color = const Color(0x44000000)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // --- Crossbow on top ---
    final bowCx = cx;
    final bowCy = bodyTop - crenH - _s * 0.04;

    // Crossbow body (horizontal bow)
    final bowW = _s * (0.16 + tier * 0.015);
    final bowPath = Path()
      ..moveTo(bowCx - bowW, bowCy + 4)
      ..quadraticBezierTo(bowCx - bowW * 0.5, bowCy - 6, bowCx, bowCy - 2)
      ..quadraticBezierTo(bowCx + bowW * 0.5, bowCy - 6, bowCx + bowW, bowCy + 4);
    canvas.drawPath(bowPath, Paint()
      ..color = const Color(0xFF6B4A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);

    // Bowstring
    canvas.drawLine(Offset(bowCx - bowW, bowCy + 4), Offset(bowCx + bowW, bowCy + 4),
      Paint()..color = const Color(0xCCCCBB99)..strokeWidth = 1.5);

    // Arrow shaft
    final arrowLen = _s * (0.10 + tier * 0.01);
    canvas.drawLine(Offset(bowCx, bowCy + 4), Offset(bowCx, bowCy - arrowLen),
      Paint()..color = const Color(0xFFAA9060)..strokeWidth = 2.5..strokeCap = StrokeCap.round);

    // Arrow tip glow
    final tipY = bowCy - arrowLen;
    canvas.drawCircle(Offset(bowCx, tipY), 8 + tier * 2.0, Paint()
      ..color = glow.withAlpha(glowA)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 + tier * 2));

    // Arrow tip (triangle)
    final tipPath = Path()
      ..moveTo(bowCx, tipY - 8)
      ..lineTo(bowCx - 5, tipY + 2)
      ..lineTo(bowCx + 5, tipY + 2)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = glow);
    canvas.drawPath(tipPath, Paint()
      ..color = _lighten(glow, 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Tier 3-4: runic circle around crossbow
    _drawRunicCircle(canvas, Offset(bowCx, bowCy), _s * 0.14, glow, tier);

    // Tier 4: floating arrows
    if (tier == 4) {
      for (int i = 0; i < 3; i++) {
        final a = i * math.pi * 2 / 3 - math.pi / 2;
        final fx = bowCx + _s * 0.12 * math.cos(a);
        final fy = bowCy + _s * 0.12 * math.sin(a);
        canvas.drawLine(Offset(fx, fy - 6), Offset(fx, fy + 6), Paint()
          ..color = glow.withAlpha(180)..strokeWidth = 2..strokeCap = StrokeCap.round);
        final miniTip = Path()..moveTo(fx, fy - 10)..lineTo(fx - 3, fy - 5)..lineTo(fx + 3, fy - 5)..close();
        canvas.drawPath(miniTip, Paint()..color = glow.withAlpha(200));
      }
    }
  }

  // ===========================================================================
  //  2. FIRE TOWER - Dark iron brazier with roaring flame
  // ===========================================================================

  void _paintFireTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFFe94560);
    final glowA = (90 + tier * 30).clamp(0, 255);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.58, tier);

    // --- Dark iron pedestal ---
    final pedW = _s * 0.44;
    final pedH = _s * 0.10;
    final pedTop = cy + _s * 0.20;
    final pedRect = Rect.fromLTWH(cx - pedW / 2, pedTop, pedW, pedH);
    final pedGrad = ui.Gradient.linear(
      Offset(pedRect.left, pedRect.top), Offset(pedRect.right, pedRect.bottom),
      [const Color(0xFF4A4A4A), const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
      [0.0, 0.5, 1.0]);
    canvas.drawRRect(RRect.fromRectAndRadius(pedRect, const Radius.circular(3)),
        Paint()..shader = pedGrad);

    // --- Iron column (tapered) ---
    final colBotW = _s * 0.16;
    final colTopW = _s * 0.10;
    final colBot = pedTop + 2;
    final colTop = cy - _s * 0.04;
    final colPath = Path()
      ..moveTo(cx - colBotW / 2, colBot)
      ..lineTo(cx - colTopW / 2, colTop)
      ..lineTo(cx + colTopW / 2, colTop)
      ..lineTo(cx + colBotW / 2, colBot)
      ..close();
    final ironGrad = ui.Gradient.linear(
      Offset(cx - colBotW / 2, 0), Offset(cx + colBotW / 2, 0),
      [const Color(0xFF555555), const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)],
      [0.0, 0.4, 1.0]);
    canvas.drawPath(colPath, Paint()..shader = ironGrad);

    // Iron bands
    for (double y = colBot - 6; y > colTop + 4; y -= 18) {
      final t = (colBot - y) / (colBot - colTop);
      final w = colBotW + (colTopW - colBotW) * t;
      canvas.drawLine(Offset(cx - w / 2, y), Offset(cx + w / 2, y),
        Paint()..color = const Color(0xFF666666)..strokeWidth = 2.5);
      canvas.drawLine(Offset(cx - w / 2, y - 1), Offset(cx + w / 2, y - 1),
        Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 0.8);
    }

    // --- Brazier bowl ---
    final brazW = _s * (0.38 + tier * 0.015);
    final brazH = _s * 0.12;
    final brazCy = colTop - brazH * 0.3;

    // Bowl shape (trapezoid with curved bottom)
    final bowlPath = Path()
      ..moveTo(cx - brazW / 2, brazCy - brazH / 2)
      ..lineTo(cx - brazW * 0.35, brazCy + brazH / 2)
      ..quadraticBezierTo(cx, brazCy + brazH * 0.7, cx + brazW * 0.35, brazCy + brazH / 2)
      ..lineTo(cx + brazW / 2, brazCy - brazH / 2)
      ..close();

    final bowlGrad = ui.Gradient.linear(
      Offset(cx, brazCy - brazH / 2), Offset(cx, brazCy + brazH / 2),
      [const Color(0xFF555555), const Color(0xFF333333), const Color(0xFF1A1A1A)],
      [0.0, 0.5, 1.0]);
    canvas.drawPath(bowlPath, Paint()..shader = bowlGrad);

    // Hot rim glow
    canvas.drawLine(
      Offset(cx - brazW / 2, brazCy - brazH / 2),
      Offset(cx + brazW / 2, brazCy - brazH / 2),
      Paint()..color = const Color(0xCCFF4400)..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..strokeCap = StrokeCap.round);

    // --- Roaring flames ---
    final flameBase = brazCy - brazH / 2;
    final flameH = _s * (0.22 + tier * 0.04);
    final flameW = brazW * 0.6;

    // Outer glow aura
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, flameBase - flameH * 0.4),
          width: flameW * 2, height: flameH * 1.8),
      Paint()..color = glow.withAlpha(glowA ~/ 2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15.0 + tier * 3));

    // Outer flame (dark red)
    final outerFlame = Path()
      ..moveTo(cx, flameBase - flameH)
      ..quadraticBezierTo(cx + flameW * 1.3, flameBase - flameH * 0.15,
          cx + flameW * 0.5, flameBase + 4)
      ..quadraticBezierTo(cx, flameBase - 2, cx - flameW * 0.5, flameBase + 4)
      ..quadraticBezierTo(cx - flameW * 1.3, flameBase - flameH * 0.15,
          cx, flameBase - flameH);
    canvas.drawPath(outerFlame, Paint()..color = const Color(0xEECC2200));

    // Middle flame (orange)
    final midH = flameH * 0.75;
    final midW = flameW * 0.7;
    final midFlame = Path()
      ..moveTo(cx, flameBase - midH)
      ..quadraticBezierTo(cx + midW * 1.1, flameBase - midH * 0.1,
          cx + midW * 0.3, flameBase + 2)
      ..quadraticBezierTo(cx, flameBase - 4, cx - midW * 0.3, flameBase + 2)
      ..quadraticBezierTo(cx - midW * 1.1, flameBase - midH * 0.1,
          cx, flameBase - midH);
    canvas.drawPath(midFlame, Paint()..color = const Color(0xEEFF6600));

    // Inner flame (bright orange-yellow)
    final innerH = flameH * 0.50;
    final innerW = flameW * 0.4;
    final innerFlame = Path()
      ..moveTo(cx, flameBase - innerH)
      ..quadraticBezierTo(cx + innerW, flameBase - innerH * 0.05,
          cx + innerW * 0.2, flameBase + 1)
      ..quadraticBezierTo(cx, flameBase - 2, cx - innerW * 0.2, flameBase + 1)
      ..quadraticBezierTo(cx - innerW, flameBase - innerH * 0.05,
          cx, flameBase - innerH);
    canvas.drawPath(innerFlame, Paint()..color = const Color(0xEEFFCC22));

    // White-hot core
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, flameBase - flameH * 0.15),
          width: innerW * 0.6, height: innerH * 0.3),
      Paint()..color = const Color(0xBBFFFFDD)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Side flame tongues (tier 2+)
    if (tier >= 2) {
      for (final side in [-1.0, 1.0]) {
        final tongueH = flameH * (0.3 + tier * 0.05);
        final tongueX = cx + side * flameW * 0.4;
        final tongue = Path()
          ..moveTo(tongueX, flameBase - flameH * 0.3)
          ..quadraticBezierTo(
              tongueX + side * flameW * 0.4, flameBase - tongueH * 0.8,
              tongueX + side * flameW * 0.15, flameBase - tongueH * 0.1);
        canvas.drawPath(tongue, Paint()
          ..color = const Color(0xBBFF4400)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4..strokeCap = StrokeCap.round);
      }
    }

    // Embers / sparks
    if (tier >= 3) {
      _drawFloatingParticles(canvas, Offset(cx, flameBase - flameH * 0.5),
          flameH * 0.7, const Color(0xFFFF6600), tier * 3);
    }

    _drawRunicCircle(canvas, Offset(cx, brazCy), _s * 0.18, glow, tier);
  }

  // ===========================================================================
  //  3. ICE TOWER - Crystal ice spire, angular/faceted
  // ===========================================================================

  void _paintIceTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFF4ecdc4);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.50, tier);

    // --- Snow/ice base platform ---
    final baseW = _s * 0.48;
    final baseH = _s * 0.10;
    final baseTop = cy + _s * 0.22;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    final baseGrad = ui.Gradient.linear(
      Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
      [const Color(0xFFAADDEE), const Color(0xFF88BBCC), const Color(0xFF668899)],
      [0.0, 0.5, 1.0]);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(3)),
        Paint()..shader = baseGrad);

    // Frost texture on base
    _drawBrickTexture(canvas, baseRect, const Color(0xFF88BBCC), brickH: 8, brickW: 16);

    // --- Main ice crystal spire (angular, faceted) ---
    final spireH = _s * (0.46 + tier * 0.03);
    final spireBot = baseTop + 2;
    final spireTop = spireBot - spireH;
    final spireBotW = _s * (0.24 + tier * 0.01);

    // Center facet (brightest)
    final centerFacet = Path()
      ..moveTo(cx, spireTop)
      ..lineTo(cx - spireBotW * 0.2, spireBot)
      ..lineTo(cx + spireBotW * 0.2, spireBot)
      ..close();
    canvas.drawPath(centerFacet, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, spireTop), Offset(cx, spireBot),
        [const Color(0xFFDDFFFF), const Color(0xFFAAEEFF), const Color(0xFF77CCDD)],
        [0.0, 0.4, 1.0]));

    // Left facet (darker)
    final leftFacet = Path()
      ..moveTo(cx, spireTop)
      ..lineTo(cx - spireBotW * 0.2, spireBot)
      ..lineTo(cx - spireBotW * 0.5, spireBot)
      ..close();
    canvas.drawPath(leftFacet, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - spireBotW * 0.5, spireTop), Offset(cx, spireBot),
        [const Color(0xFF99DDEE), const Color(0xFF66AABB), const Color(0xFF448899)],
        [0.0, 0.4, 1.0]));

    // Right facet (darkest)
    final rightFacet = Path()
      ..moveTo(cx, spireTop)
      ..lineTo(cx + spireBotW * 0.2, spireBot)
      ..lineTo(cx + spireBotW * 0.5, spireBot)
      ..close();
    canvas.drawPath(rightFacet, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, spireTop), Offset(cx + spireBotW * 0.5, spireBot),
        [const Color(0xFF77BBCC), const Color(0xFF559999), const Color(0xFF337777)],
        [0.0, 0.4, 1.0]));

    // Edge highlight lines
    canvas.drawLine(Offset(cx, spireTop), Offset(cx - spireBotW * 0.2, spireBot),
      Paint()..color = const Color(0x50FFFFFF)..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx, spireTop), Offset(cx + spireBotW * 0.2, spireBot),
      Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 1.0);

    // Spire outline
    final spireOutline = Path()
      ..moveTo(cx - spireBotW * 0.5, spireBot)
      ..lineTo(cx, spireTop)
      ..lineTo(cx + spireBotW * 0.5, spireBot)
      ..close();
    canvas.drawPath(spireOutline, Paint()
      ..color = const Color(0x44FFFFFF)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // --- Side crystal shards ---
    for (final side in [-1.0, 1.0]) {
      final shardH = spireH * (0.35 + tier * 0.03);
      final shardW = spireBotW * 0.22;
      final shardBaseX = cx + side * spireBotW * 0.4;
      final shardTopX = cx + side * spireBotW * 0.25;
      final shardBot = spireBot - spireH * 0.15;
      final shardTop = shardBot - shardH;

      final shard = Path()
        ..moveTo(shardTopX, shardTop)
        ..lineTo(shardBaseX - shardW * 0.5 * side, shardBot)
        ..lineTo(shardBaseX + shardW * 0.5 * side, shardBot)
        ..close();
      canvas.drawPath(shard, Paint()
        ..color = Color.fromARGB(180, 100, 200, 220));
      canvas.drawPath(shard, Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // --- Frost glow at tip ---
    canvas.drawCircle(Offset(cx, spireTop), 12.0 + tier * 4, Paint()
      ..color = glow.withAlpha(80 + tier * 25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 + tier * 3));

    // Bright dot at tip
    canvas.drawCircle(Offset(cx, spireTop), 4.0 + tier * 1.0, Paint()
      ..color = _lighten(glow, 0.6));

    // --- Snowflake / frost emanation lines ---
    if (tier >= 2) {
      final frostR = _s * (0.06 + tier * 0.02);
      for (int i = 0; i < 6; i++) {
        final a = i * math.pi / 3 - math.pi / 2;
        canvas.drawLine(
          Offset(cx + frostR * 0.3 * math.cos(a), spireTop + frostR * 0.3 * math.sin(a)),
          Offset(cx + frostR * math.cos(a), spireTop + frostR * math.sin(a)),
          Paint()..color = glow.withAlpha(120)..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round);
      }
    }

    // Frost particles around spire (tier 3+)
    if (tier >= 3) {
      _drawFloatingParticles(canvas, Offset(cx, spireTop + spireH * 0.3),
          spireH * 0.4, glow, tier * 2 + 2);
    }

    _drawRunicCircle(canvas, Offset(cx, spireBot - spireH * 0.4), _s * 0.16, glow, tier);

    // Tier 4: icicle floating ring
    if (tier == 4) {
      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final ir = _s * 0.18;
        final ix = cx + ir * math.cos(a);
        final iy = (spireTop + spireBot) / 2 + ir * math.sin(a) * 0.5;
        final icicle = Path()
          ..moveTo(ix, iy - 6)..lineTo(ix - 2, iy + 3)..lineTo(ix + 2, iy + 3)..close();
        canvas.drawPath(icicle, Paint()..color = glow.withAlpha(160));
      }
    }
  }

  // ===========================================================================
  //  4. LIGHTNING TOWER - Metal tesla coil / conductor
  // ===========================================================================

  void _paintLightningTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFFa78bfa);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.52, tier);

    // --- Metal base plate ---
    final baseW = _s * 0.46;
    final baseH = _s * 0.10;
    final baseTop = cy + _s * 0.22;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(3)),
        Paint()..shader = ui.Gradient.linear(
          Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
          [const Color(0xFF5A5A5A), const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)],
          [0.0, 0.5, 1.0]));

    // Riveted metal plates
    for (double rx = baseRect.left + 15; rx < baseRect.right - 10; rx += 20) {
      canvas.drawCircle(Offset(rx, baseTop + baseH / 2), 2.5, Paint()..color = const Color(0xAA888888));
      canvas.drawCircle(Offset(rx - 0.5, baseTop + baseH / 2 - 0.5), 1, Paint()..color = const Color(0x40FFFFFF));
    }

    // --- Central metal column ---
    final colW = _s * 0.10;
    final colBot = baseTop + 2;
    final colTop = cy - _s * 0.12;
    final colRect = Rect.fromLTWH(cx - colW / 2, colTop, colW, colBot - colTop);
    canvas.drawRect(colRect, Paint()
      ..shader = ui.Gradient.linear(
        Offset(colRect.left, 0), Offset(colRect.right, 0),
        [const Color(0xFF666666), const Color(0xFF888888), const Color(0xFF555555)],
        [0.0, 0.4, 1.0]));

    // Insulator rings
    for (double y = colBot - 10; y > colTop + 5; y -= 16) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y), width: colW + 8, height: 6),
          const Radius.circular(3)),
        Paint()..color = const Color(0xFF444466));
      canvas.drawLine(Offset(cx - colW / 2 - 4, y - 2), Offset(cx + colW / 2 + 4, y - 2),
        Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 0.8);
    }

    // --- Tesla coil toroid (donut shape at top) ---
    final toroidCy = colTop - _s * 0.02;
    final toroidRx = _s * (0.12 + tier * 0.01);
    final toroidRy = _s * 0.04;

    // Toroid body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, toroidCy), width: toroidRx * 2, height: toroidRy * 2),
      Paint()..shader = ui.Gradient.linear(
        Offset(cx, toroidCy - toroidRy), Offset(cx, toroidCy + toroidRy),
        [const Color(0xFFAAAABB), const Color(0xFF666677), const Color(0xFF444455)],
        [0.0, 0.5, 1.0]));

    // Toroid highlight
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, toroidCy), width: toroidRx * 1.8, height: toroidRy * 1.2),
      math.pi, math.pi, false,
      Paint()..color = const Color(0x30FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 2);

    // --- Conductor sphere on top ---
    final sphereR = _s * (0.06 + tier * 0.008);
    final sphereCy = toroidCy - toroidRy - sphereR * 0.6;

    // Electric glow behind sphere
    canvas.drawCircle(Offset(cx, sphereCy), sphereR * 3, Paint()
      ..color = glow.withAlpha(60 + tier * 20)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 + tier * 3));

    // Sphere gradient
    canvas.drawCircle(Offset(cx, sphereCy), sphereR, Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - sphereR * 0.3, sphereCy - sphereR * 0.3), sphereR * 1.4,
        [const Color(0xFFCCCCDD), const Color(0xFF8888AA), const Color(0xFF555577)],
        [0.0, 0.5, 1.0]));

    // Specular highlight
    canvas.drawCircle(Offset(cx - sphereR * 0.3, sphereCy - sphereR * 0.3),
        sphereR * 0.25, Paint()..color = const Color(0x88FFFFFF));

    // --- Electric arcs from sphere ---
    final arcCount = 2 + tier;
    for (int i = 0; i < arcCount; i++) {
      final a = i * math.pi * 2 / arcCount - math.pi / 4;
      final endR = sphereR * (2.5 + tier * 0.5);
      final endX = cx + endR * math.cos(a);
      final endY = sphereCy + endR * math.sin(a);
      final midX = (cx + endX) / 2 + (i.isEven ? 8 : -8);
      final midY = (sphereCy + endY) / 2 + (i.isEven ? -6 : 6);

      final arc = Path()
        ..moveTo(cx, sphereCy)
        ..quadraticBezierTo(midX, midY, endX, endY);

      // Glow layer
      canvas.drawPath(arc, Paint()
        ..color = glow.withAlpha(80)
        ..style = PaintingStyle.stroke..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      // Bright core
      canvas.drawPath(arc, Paint()
        ..color = _lighten(glow, 0.5).withAlpha(200)
        ..style = PaintingStyle.stroke..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
    }

    // --- Electric crackle around toroid ---
    if (tier >= 2) {
      for (int i = 0; i < 6 + tier * 2; i++) {
        final a = i * math.pi * 2 / (6 + tier * 2);
        final sr = toroidRx * 1.1;
        final er = toroidRx * (1.3 + tier * 0.1);
        canvas.drawLine(
          Offset(cx + sr * math.cos(a), toroidCy + toroidRy * 0.8 * math.sin(a)),
          Offset(cx + er * math.cos(a), toroidCy + toroidRy * 1.2 * math.sin(a)),
          Paint()..color = glow.withAlpha(100 + tier * 20)
            ..strokeWidth = 1.5..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }

    _drawRunicCircle(canvas, Offset(cx, toroidCy), _s * 0.16, glow, tier);

    // Tier 4: orbiting energy balls
    if (tier == 4) {
      _drawFloatingParticles(canvas, Offset(cx, sphereCy), sphereR * 4, glow, 6);
    }
  }

  // ===========================================================================
  //  5. POISON TOWER - Organic twisted wood with bubbling cauldron
  // ===========================================================================

  void _paintPoisonTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFF2ecc71);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.55, tier);

    // --- Mossy stone base ---
    final baseW = _s * 0.48;
    final baseH = _s * 0.10;
    final baseTop = cy + _s * 0.22;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
        Paint()..shader = ui.Gradient.linear(
          Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
          [const Color(0xFF4A5A3A), const Color(0xFF3A4A2A), const Color(0xFF2A3A1A)],
          [0.0, 0.5, 1.0]));
    _drawBrickTexture(canvas, baseRect, const Color(0xFF3A4A2A), brickH: 8, brickW: 16);

    // --- Twisted trunk (organic curves) ---
    final trunkBot = baseTop + 2;
    final trunkTop = cy - _s * 0.06;
    final trunkW = _s * 0.12;

    // Left trunk curve
    final leftTrunk = Path()
      ..moveTo(cx - trunkW * 0.8, trunkBot)
      ..quadraticBezierTo(cx - trunkW * 1.5, (trunkBot + trunkTop) / 2,
          cx - trunkW * 0.3, trunkTop)
      ..lineTo(cx - trunkW * 0.1, trunkTop)
      ..quadraticBezierTo(cx - trunkW * 1.0, (trunkBot + trunkTop) / 2 + 8,
          cx - trunkW * 0.4, trunkBot)
      ..close();
    canvas.drawPath(leftTrunk, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - trunkW * 1.5, 0), Offset(cx, 0),
        [const Color(0xFF3A2A14), const Color(0xFF5A4020), const Color(0xFF4A3218)],
        [0.0, 0.5, 1.0]));

    // Right trunk curve
    final rightTrunk = Path()
      ..moveTo(cx + trunkW * 0.8, trunkBot)
      ..quadraticBezierTo(cx + trunkW * 1.5, (trunkBot + trunkTop) / 2,
          cx + trunkW * 0.3, trunkTop)
      ..lineTo(cx + trunkW * 0.1, trunkTop)
      ..quadraticBezierTo(cx + trunkW * 1.0, (trunkBot + trunkTop) / 2 + 8,
          cx + trunkW * 0.4, trunkBot)
      ..close();
    canvas.drawPath(rightTrunk, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, 0), Offset(cx + trunkW * 1.5, 0),
        [const Color(0xFF5A4020), const Color(0xFF3A2A14), const Color(0xFF2A1A0A)],
        [0.0, 0.5, 1.0]));

    // Bark texture lines on trunks
    for (double y = trunkBot - 6; y > trunkTop + 4; y -= 10) {
      final t = (trunkBot - y) / (trunkBot - trunkTop);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - trunkW * (0.6 - t * 0.3), y),
            width: trunkW * 0.6, height: 6),
        0, math.pi, false,
        Paint()..color = const Color(0x25000000)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + trunkW * (0.6 - t * 0.3), y),
            width: trunkW * 0.6, height: 6),
        0, math.pi, false,
        Paint()..color = const Color(0x25000000)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // Moss/vine drips
    for (final side in [-1.0, 1.0]) {
      for (int i = 0; i < tier; i++) {
        final vy = trunkTop + (trunkBot - trunkTop) * (0.2 + i * 0.25);
        final vx = cx + side * trunkW * (0.8 + i * 0.1);
        canvas.drawLine(Offset(vx, vy), Offset(vx + side * 3, vy + 12),
          Paint()..color = glow.withAlpha(80)..strokeWidth = 2..strokeCap = StrokeCap.round);
      }
    }

    // --- Cauldron ---
    final caulW = _s * (0.30 + tier * 0.01);
    final caulH = _s * 0.10;
    final caulCy = trunkTop - caulH * 0.2;

    // Cauldron body
    final cauldron = Path()
      ..moveTo(cx - caulW / 2, caulCy - caulH * 0.3)
      ..quadraticBezierTo(cx - caulW / 2, caulCy + caulH * 0.8,
          cx, caulCy + caulH * 0.8)
      ..quadraticBezierTo(cx + caulW / 2, caulCy + caulH * 0.8,
          cx + caulW / 2, caulCy - caulH * 0.3)
      ..close();
    canvas.drawPath(cauldron, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - caulW / 2, 0), Offset(cx + caulW / 2, 0),
        [const Color(0xFF3A3A3A), const Color(0xFF555555), const Color(0xFF2A2A2A)],
        [0.0, 0.4, 1.0]));

    // Cauldron rim
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, caulCy - caulH * 0.3),
          width: caulW, height: caulH * 0.3),
      Paint()..color = const Color(0xFF4A4A4A));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, caulCy - caulH * 0.3),
          width: caulW, height: caulH * 0.3),
      Paint()..color = const Color(0x30FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // --- Bubbling liquid surface ---
    final liquidCy = caulCy - caulH * 0.2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, liquidCy),
          width: caulW * 0.85, height: caulH * 0.25),
      Paint()..color = glow.withAlpha(180));

    // Bubbles
    final bubbleCount = 3 + tier;
    for (int i = 0; i < bubbleCount; i++) {
      final bx = cx - caulW * 0.3 + (i * caulW * 0.6 / bubbleCount);
      final by = liquidCy - 4 - (i % 3) * 5;
      final br = 3.0 + (i % 2) * 2;
      canvas.drawCircle(Offset(bx, by), br, Paint()
        ..color = _lighten(glow, 0.3).withAlpha(160)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(Offset(bx - 1, by - 1), br * 0.3, Paint()
        ..color = const Color(0x55FFFFFF));
    }

    // --- Toxic glow above cauldron ---
    final fumeH = _s * (0.08 + tier * 0.025);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, liquidCy - fumeH),
          width: caulW * 1.2, height: fumeH * 2),
      Paint()..color = glow.withAlpha(40 + tier * 15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 + tier * 3));

    // Skull vapor (tier 3+)
    if (tier >= 3) {
      final skullCy = liquidCy - fumeH * 1.5;
      final skullR = _s * 0.04;
      // Head
      canvas.drawCircle(Offset(cx, skullCy), skullR, Paint()
        ..color = glow.withAlpha(90)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      // Eye sockets
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(cx + side * skullR * 0.4, skullCy - skullR * 0.15),
            skullR * 0.2, Paint()..color = const Color(0xAA000000));
      }
    }

    _drawRunicCircle(canvas, Offset(cx, caulCy), _s * 0.16, glow, tier);

    if (tier == 4) {
      _drawFloatingParticles(canvas, Offset(cx, caulCy - _s * 0.05),
          _s * 0.14, glow, 8);
    }
  }

  // ===========================================================================
  //  6. WATER TOWER - Smooth stone fountain tower with water spout
  // ===========================================================================

  void _paintWaterTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFF3498db);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.54, tier);

    // --- Circular stone basin ---
    final basinW = _s * 0.50;
    final basinH = _s * 0.12;
    final basinCy = cy + _s * 0.20;

    // Basin outer wall
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, basinCy), width: basinW, height: basinH),
      Paint()..shader = ui.Gradient.linear(
        Offset(cx, basinCy - basinH / 2), Offset(cx, basinCy + basinH / 2),
        [const Color(0xFF7A7A8A), const Color(0xFF5A5A6A), const Color(0xFF3A3A4A)],
        [0.0, 0.5, 1.0]));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, basinCy), width: basinW, height: basinH),
      Paint()..color = const Color(0x44000000)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Water surface in basin
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, basinCy - basinH * 0.15),
          width: basinW * 0.85, height: basinH * 0.5),
      Paint()..shader = ui.Gradient.radial(
        Offset(cx, basinCy - basinH * 0.15), basinW * 0.4,
        [glow.withAlpha(180), const Color(0xFF1A3A5A), const Color(0xFF0A2A4A)],
        [0.0, 0.5, 1.0]));

    // Water ripples
    for (int i = 0; i < 2 + tier; i++) {
      final rr = basinW * (0.15 + i * 0.12);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, basinCy - basinH * 0.15),
            width: rr, height: rr * 0.3),
        Paint()..color = glow.withAlpha(40 - i * 8)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }

    // --- Central pillar ---
    final pillarW = _s * 0.08;
    final pillarBot = basinCy - basinH * 0.2;
    final pillarTop = cy - _s * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - pillarW / 2, pillarTop, pillarW, pillarBot - pillarTop),
        const Radius.circular(3)),
      Paint()..shader = ui.Gradient.linear(
        Offset(cx - pillarW / 2, 0), Offset(cx + pillarW / 2, 0),
        [const Color(0xFF8888AA), const Color(0xFFAAAACC), const Color(0xFF6666AA)],
        [0.0, 0.4, 1.0]));

    // Pillar stone rings
    for (double y = pillarBot - 8; y > pillarTop + 4; y -= 14) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y), width: pillarW + 4, height: 4),
          const Radius.circular(2)),
        Paint()..color = const Color(0xFF7777AA));
    }

    // --- Spout top (dish shape) ---
    final dishW = _s * (0.20 + tier * 0.01);
    final dishH = _s * 0.04;
    final dishCy = pillarTop - 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, dishCy), width: dishW, height: dishH),
      Paint()..shader = ui.Gradient.linear(
        Offset(cx, dishCy - dishH / 2), Offset(cx, dishCy + dishH / 2),
        [const Color(0xFFAAAACC), const Color(0xFF7777AA)],
        [0.0, 1.0]));

    // --- Water jet going upward ---
    final jetH = _s * (0.10 + tier * 0.025);
    final jetTop = dishCy - jetH;

    // Jet glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, dishCy - jetH / 2),
            width: 14 + tier * 2.0, height: jetH),
        const Radius.circular(6)),
      Paint()..color = glow.withAlpha(60 + tier * 15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 + tier * 2));

    // Jet body
    final jetPath = Path()
      ..moveTo(cx - 3, dishCy)
      ..quadraticBezierTo(cx - 5, dishCy - jetH * 0.5, cx - 2, jetTop)
      ..lineTo(cx + 2, jetTop)
      ..quadraticBezierTo(cx + 5, dishCy - jetH * 0.5, cx + 3, dishCy)
      ..close();
    canvas.drawPath(jetPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx, dishCy), Offset(cx, jetTop),
        [glow, _lighten(glow, 0.4), _lighten(glow, 0.7)],
        [0.0, 0.5, 1.0]));

    // Top splash
    canvas.drawCircle(Offset(cx, jetTop), 5 + tier * 1.5, Paint()
      ..color = _lighten(glow, 0.5).withAlpha(180)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Falling water streams
    for (final side in [-1.0, 1.0]) {
      final stream = Path()
        ..moveTo(cx + side * 2, jetTop + 2)
        ..quadraticBezierTo(cx + side * (10 + tier * 3), jetTop + jetH * 0.5,
            cx + side * (6 + tier * 2), dishCy + 4);
      canvas.drawPath(stream, Paint()
        ..color = glow.withAlpha(100)
        ..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);
    }

    // Ambient glow
    canvas.drawCircle(Offset(cx, dishCy - jetH / 2), _s * 0.08 + tier * 4, Paint()
      ..color = glow.withAlpha(30 + tier * 10)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 + tier * 2));

    _drawRunicCircle(canvas, Offset(cx, basinCy), _s * 0.18, glow, tier);

    if (tier == 4) {
      // Orbiting water drops
      for (int i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        final dr = _s * 0.15;
        final dx = cx + dr * math.cos(a);
        final dy = dishCy - jetH / 2 + dr * math.sin(a) * 0.6;
        // Drop shape
        final drop = Path()
          ..moveTo(dx, dy - 4)
          ..quadraticBezierTo(dx + 3, dy + 2, dx, dy + 4)
          ..quadraticBezierTo(dx - 3, dy + 2, dx, dy - 4);
        canvas.drawPath(drop, Paint()..color = glow.withAlpha(160));
      }
    }
  }

  // ===========================================================================
  //  7. DARK TOWER - Obsidian obelisk with dark energy
  // ===========================================================================

  void _paintDarkTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFF8b5cf6);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.48, tier);

    // --- Cracked stone base ---
    final baseW = _s * 0.42;
    final baseH = _s * 0.10;
    final baseTop = cy + _s * 0.22;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(3)),
        Paint()..shader = ui.Gradient.linear(
          Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
          [const Color(0xFF2A2A3A), const Color(0xFF1A1A2A), const Color(0xFF0A0A1A)],
          [0.0, 0.5, 1.0]));
    _drawBrickTexture(canvas, baseRect, const Color(0xFF1A1A2A), brickH: 8, brickW: 16);

    // --- Obsidian obelisk (tall, narrow, tapered) ---
    final obH = _s * (0.50 + tier * 0.03);
    final obBotW = _s * (0.18 + tier * 0.005);
    final obBot = baseTop + 2;
    final obTop = obBot - obH;

    // Main obelisk shape (4-sided with slight taper)
    final obPath = Path()
      ..moveTo(cx, obTop) // pointed top
      ..lineTo(cx - obBotW / 2, obBot)
      ..lineTo(cx + obBotW / 2, obBot)
      ..close();

    // Dark gradient with purple tint
    canvas.drawPath(obPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - obBotW / 2, 0), Offset(cx + obBotW / 2, 0),
        [const Color(0xFF1A1030), const Color(0xFF2A1840), const Color(0xFF1A1030)],
        [0.0, 0.5, 1.0]));

    // Facet edge highlights
    canvas.drawLine(Offset(cx, obTop), Offset(cx - obBotW * 0.15, obBot),
      Paint()..color = const Color(0x20FFFFFF)..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx, obTop), Offset(cx + obBotW * 0.15, obBot),
      Paint()..color = const Color(0x15FFFFFF)..strokeWidth = 1.0);

    // Glowing runes on obelisk
    final runeCount = 1 + tier;
    for (int i = 0; i < runeCount; i++) {
      final frac = (i + 1) / (runeCount + 1);
      final ry = obBot + (obTop - obBot) * frac;
      final t = frac;
      final rw = obBotW * (1 - t) * 0.5;

      // Rune glow slot
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, ry), width: rw, height: 4),
          const Radius.circular(2)),
        Paint()..color = glow.withAlpha(120 + tier * 20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 + tier));
    }

    // Obelisk outline
    canvas.drawPath(obPath, Paint()
      ..color = glow.withAlpha(40)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // --- Dark energy orb at peak ---
    final orbR = _s * (0.04 + tier * 0.008);
    final orbCy = obTop;

    // Shadow void aura
    canvas.drawCircle(Offset(cx, orbCy), orbR * 4, Paint()
      ..color = glow.withAlpha(40 + tier * 15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 + tier * 4));

    // Dark energy orb
    canvas.drawCircle(Offset(cx, orbCy), orbR, Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx + orbR * 0.2, orbCy - orbR * 0.2), orbR * 1.3,
        [glow, _darken(glow, 0.4), const Color(0xFF0A0A1A)],
        [0.0, 0.5, 1.0]));

    // Inner void (darker center)
    canvas.drawCircle(Offset(cx + orbR * 0.2, orbCy), orbR * 0.5, Paint()
      ..color = const Color(0xCC0A0A1A));

    // Orbiting shadow particles
    final partCount = 4 + tier * 2;
    for (int i = 0; i < partCount; i++) {
      final a = i * math.pi * 2 / partCount;
      final pr = orbR * (1.8 + tier * 0.3);
      final px = cx + pr * math.cos(a);
      final py = orbCy + pr * math.sin(a) * 0.7;
      canvas.drawCircle(Offset(px, py), 2.0 + (i % 2), Paint()
        ..color = glow.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    // Dark tendrils downward from orb (tier 2+)
    if (tier >= 2) {
      for (int i = 0; i < tier; i++) {
        final a = -math.pi / 2 + (i - (tier - 1) / 2) * 0.4;
        final tendril = Path()
          ..moveTo(cx, orbCy + orbR)
          ..quadraticBezierTo(
              cx + math.cos(a) * _s * 0.06, orbCy + _s * 0.08,
              cx + math.cos(a) * _s * 0.04, orbCy + _s * 0.14);
        canvas.drawPath(tendril, Paint()
          ..color = glow.withAlpha(60 + tier * 10)
          ..style = PaintingStyle.stroke..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }

    _drawRunicCircle(canvas, Offset(cx, obBot - obH * 0.4), _s * 0.14, glow, tier);

    // Tier 4: shadow ring expanding from base
    if (tier == 4) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, baseTop + baseH / 2),
            width: _s * 0.5, height: _s * 0.08),
        Paint()..color = glow.withAlpha(60)
          ..style = PaintingStyle.stroke..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
  }

  // ===========================================================================
  //  8. HOLY TOWER - White marble tower with divine light
  // ===========================================================================

  void _paintHolyTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFFffd700);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.52, tier);

    // --- Divine radiance behind tower ---
    canvas.drawCircle(Offset(cx, cy - _s * 0.08), _s * (0.18 + tier * 0.03), Paint()
      ..color = glow.withAlpha(20 + tier * 8)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18.0 + tier * 4));

    // --- White marble base ---
    final baseW = _s * 0.48;
    final baseH = _s * 0.12;
    final baseTop = cy + _s * 0.20;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
        Paint()..shader = ui.Gradient.linear(
          Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
          [const Color(0xFFE8E0D0), const Color(0xFFD0C8B8), const Color(0xFFB8B0A0)],
          [0.0, 0.5, 1.0]));
    _drawBrickTexture(canvas, baseRect, const Color(0xFFD0C8B8), brickH: 10, brickW: 20);

    // --- Marble column body (classical pillar shape) ---
    final bodyW = _s * (0.22 + tier * 0.008);
    final bodyBot = baseTop + 2;
    final bodyTop = cy - _s * (0.16 + tier * 0.015);

    // Main column
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - bodyW / 2, bodyTop, bodyW, bodyBot - bodyTop),
        Radius.circular(bodyW * 0.15)),
      Paint()..shader = ui.Gradient.linear(
        Offset(cx - bodyW / 2, 0), Offset(cx + bodyW / 2, 0),
        [const Color(0xFFE0D8C8), const Color(0xFFF0E8D8), const Color(0xFFD8D0C0),
         const Color(0xFFC0B8A8)],
        [0.0, 0.35, 0.65, 1.0]));

    // Fluted column grooves
    final grooveCount = 5 + tier;
    for (int i = 0; i < grooveCount; i++) {
      final gx = cx - bodyW / 2 + bodyW * (i + 0.5) / grooveCount;
      canvas.drawLine(Offset(gx, bodyTop + 6), Offset(gx, bodyBot - 4),
        Paint()..color = const Color(0x18000000)..strokeWidth = 1.0);
    }

    // Column highlight
    canvas.drawLine(
      Offset(cx - bodyW * 0.25, bodyTop + 4),
      Offset(cx - bodyW * 0.25, bodyBot - 4),
      Paint()..color = const Color(0x20FFFFFF)..strokeWidth = 3..strokeCap = StrokeCap.round);

    // Capital (top ornament)
    final capH = 10.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - bodyW * 0.65, bodyTop - capH, bodyW * 1.3, capH),
        const Radius.circular(3)),
      Paint()..shader = ui.Gradient.linear(
        Offset(cx, bodyTop - capH), Offset(cx, bodyTop),
        [const Color(0xFFE8E0D0), const Color(0xFFD0C8B8)],
        [0.0, 1.0]));

    // Pediment base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - bodyW * 0.6, bodyBot, bodyW * 1.2, 8),
        const Radius.circular(3)),
      Paint()..color = const Color(0xFFD0C8B8));

    // --- Golden cross / divine symbol on top ---
    final crossCy = bodyTop - capH - _s * 0.06;
    final crossH = _s * (0.06 + tier * 0.01);
    final crossW = crossH * 0.6;

    // Cross glow
    canvas.drawCircle(Offset(cx, crossCy), crossH * 1.5, Paint()
      ..color = glow.withAlpha(60 + tier * 20)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 + tier * 3));

    // Cross vertical
    canvas.drawLine(Offset(cx, crossCy - crossH), Offset(cx, crossCy + crossH * 0.6),
      Paint()..color = glow..strokeWidth = 4..strokeCap = StrokeCap.round);
    // Cross horizontal
    canvas.drawLine(Offset(cx - crossW, crossCy - crossH * 0.3),
        Offset(cx + crossW, crossCy - crossH * 0.3),
      Paint()..color = glow..strokeWidth = 4..strokeCap = StrokeCap.round);

    // Cross glow overlay
    canvas.drawLine(Offset(cx, crossCy - crossH), Offset(cx, crossCy + crossH * 0.6),
      Paint()..color = _lighten(glow, 0.5).withAlpha(150)..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(cx - crossW, crossCy - crossH * 0.3),
        Offset(cx + crossW, crossCy - crossH * 0.3),
      Paint()..color = _lighten(glow, 0.5).withAlpha(150)..strokeWidth = 2..strokeCap = StrokeCap.round);

    // --- Light rays from cross ---
    final rayCount = 4 + tier * 2;
    for (int i = 0; i < rayCount; i++) {
      final a = i * math.pi * 2 / rayCount;
      final innerR = crossH * 0.8;
      final outerR = crossH * (1.5 + tier * 0.3);
      canvas.drawLine(
        Offset(cx + innerR * math.cos(a), crossCy + innerR * math.sin(a)),
        Offset(cx + outerR * math.cos(a), crossCy + outerR * math.sin(a)),
        Paint()..color = glow.withAlpha(50 + tier * 15)
          ..strokeWidth = 2..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    // Window arches on column
    for (int i = 0; i < tier; i++) {
      final frac = (i + 1) / (tier + 1);
      final wy = bodyTop + (bodyBot - bodyTop) * frac;
      final ww = bodyW * 0.35;
      final wh = bodyW * 0.25;
      // Arch shape
      final arch = Path()
        ..moveTo(cx - ww / 2, wy + wh / 2)
        ..lineTo(cx - ww / 2, wy - wh * 0.1)
        ..quadraticBezierTo(cx, wy - wh, cx + ww / 2, wy - wh * 0.1)
        ..lineTo(cx + ww / 2, wy + wh / 2)
        ..close();
      canvas.drawPath(arch, Paint()..color = const Color(0xFF3A3020));
      // Warm light from inside
      canvas.drawPath(arch, Paint()
        ..color = glow.withAlpha(30 + tier * 10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    _drawRunicCircle(canvas, Offset(cx, crossCy), _s * 0.14, glow, tier);

    // Tier 4: floating halo ring
    if (tier == 4) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, crossCy - crossH * 1.2),
            width: _s * 0.12, height: _s * 0.03),
        Paint()..color = glow.withAlpha(200)
          ..style = PaintingStyle.stroke..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  // ===========================================================================
  //  9. CANNON TOWER - Heavy iron/bronze cannon on stone base
  // ===========================================================================

  void _paintCannonTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFFe67e22);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.60, tier);

    // --- Heavy stone fortification base ---
    final baseW = _s * 0.56;
    final baseH = _s * 0.16;
    final baseTop = cy + _s * 0.16;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
        Paint()..shader = ui.Gradient.linear(
          Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
          [const Color(0xFF6A6A6A), const Color(0xFF4A4A4A), const Color(0xFF3A3A3A)],
          [0.0, 0.5, 1.0]));
    _drawBrickTexture(canvas, baseRect, const Color(0xFF555555), brickH: 12, brickW: 22);

    // Top ledge highlight
    canvas.drawLine(Offset(baseRect.left + 4, baseTop + 2), Offset(baseRect.right - 4, baseTop + 2),
      Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 2);

    // --- Short squat tower body ---
    final bodyW = _s * (0.36 + tier * 0.01);
    final bodyH = _s * (0.16 + tier * 0.01);
    final bodyBot = baseTop + 2;
    final bodyTop2 = bodyBot - bodyH;
    final bodyRect = Rect.fromLTWH(cx - bodyW / 2, bodyTop2, bodyW, bodyH);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(4)),
        Paint()..shader = ui.Gradient.linear(
          Offset(bodyRect.left, bodyRect.top), Offset(bodyRect.right, bodyRect.bottom),
          [const Color(0xFF5A5A5A), const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)],
          [0.0, 0.5, 1.0]));
    _drawBrickTexture(canvas, bodyRect, const Color(0xFF444444), brickH: 10, brickW: 18);

    // Crenellations
    final crenCount = 4 + tier;
    final crenW = bodyW / crenCount;
    final crenH = 8.0 + tier * 2;
    for (int i = 0; i < crenCount; i++) {
      if (i % 2 == 0) continue;
      final mx = cx - bodyW / 2 + i * crenW;
      canvas.drawRect(
        Rect.fromLTWH(mx, bodyTop2 - crenH, crenW * 0.8, crenH + 2),
        Paint()..color = const Color(0xFF4A4A4A));
    }

    // --- Cannon barrel ---
    final barrelLen = _s * (0.22 + tier * 0.02);
    final barrelH = _s * (0.06 + tier * 0.005);
    final barrelCy = bodyTop2 - crenH * 0.3;
    final barrelStartX = cx - barrelLen * 0.15;
    final barrelEndX = barrelStartX + barrelLen;

    // Barrel body gradient (bronze/iron)
    final barrelRect = Rect.fromLTWH(barrelStartX, barrelCy - barrelH / 2, barrelLen, barrelH);
    canvas.drawRRect(RRect.fromRectAndRadius(barrelRect, Radius.circular(barrelH * 0.3)),
        Paint()..shader = ui.Gradient.linear(
          Offset(0, barrelRect.top), Offset(0, barrelRect.bottom),
          [const Color(0xFF8A7A5A), const Color(0xFF6A5A3A), const Color(0xFF4A3A2A),
           const Color(0xFF6A5A3A)],
          [0.0, 0.35, 0.65, 1.0]));

    // Barrel highlight
    canvas.drawLine(
      Offset(barrelStartX + 4, barrelCy - barrelH * 0.3),
      Offset(barrelEndX - 2, barrelCy - barrelH * 0.3),
      Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 2..strokeCap = StrokeCap.round);

    // Reinforcement rings
    for (double rx = barrelStartX + 12; rx < barrelEndX - 8; rx += barrelLen * 0.3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(rx, barrelCy),
              width: 6, height: barrelH + 4),
          const Radius.circular(2)),
        Paint()..color = const Color(0xFF888866));
      canvas.drawLine(Offset(rx, barrelCy - barrelH / 2 - 2),
          Offset(rx, barrelCy - barrelH / 2),
        Paint()..color = const Color(0x40FFFFFF)..strokeWidth = 1);
    }

    // Barrel mouth (darker circle)
    canvas.drawCircle(Offset(barrelEndX, barrelCy), barrelH * 0.4, Paint()
      ..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(Offset(barrelEndX, barrelCy), barrelH * 0.4, Paint()
      ..color = const Color(0xFF3A3A3A)..style = PaintingStyle.stroke..strokeWidth = 2);

    // --- Muzzle flash glow ---
    final flashR = _s * (0.06 + tier * 0.015);
    canvas.drawCircle(Offset(barrelEndX + flashR * 0.3, barrelCy), flashR * 2, Paint()
      ..color = glow.withAlpha(50 + tier * 20)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 + tier * 3));

    // Flash burst
    canvas.drawCircle(Offset(barrelEndX + 2, barrelCy), flashR * 0.8, Paint()
      ..shader = ui.Gradient.radial(
        Offset(barrelEndX + 2, barrelCy), flashR,
        [const Color(0xCCFFFFDD), glow.withAlpha(200), glow.withAlpha(0)],
        [0.0, 0.3, 1.0]));

    // --- Cannonball (tier 2+) ---
    if (tier >= 2) {
      final ballR = _s * 0.025;
      final ballX = barrelEndX + flashR * 0.8;
      canvas.drawCircle(Offset(ballX, barrelCy), ballR, Paint()
        ..shader = ui.Gradient.radial(
          Offset(ballX - ballR * 0.3, barrelCy - ballR * 0.3), ballR * 1.2,
          [const Color(0xFF555555), const Color(0xFF222222)],
          [0.0, 1.0]));
    }

    // --- Wheel/mount at base of cannon ---
    final wheelR = _s * 0.035;
    final wheelCy = barrelCy + barrelH * 0.5 + wheelR * 0.8;
    for (final side in [-0.8, 0.8]) {
      final wx = cx + side * bodyW * 0.15;
      canvas.drawCircle(Offset(wx, wheelCy), wheelR, Paint()
        ..color = const Color(0xFF5A4A3A));
      canvas.drawCircle(Offset(wx, wheelCy), wheelR, Paint()
        ..color = const Color(0xFF3A2A1A)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(Offset(wx, wheelCy), wheelR * 0.3, Paint()
        ..color = const Color(0xFF888866));
    }

    _drawRunicCircle(canvas, Offset(cx, barrelCy), _s * 0.18, glow, tier);

    if (tier == 4) {
      // Smoke puffs
      for (int i = 0; i < 4; i++) {
        final sx = barrelEndX + flashR + i * 8.0;
        final sy = barrelCy - 6 - i * 4.0;
        canvas.drawCircle(Offset(sx, sy), 5.0 + i * 2, Paint()
          ..color = Color.fromARGB(40 - i * 8, 150, 150, 150)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }
  }

  // ===========================================================================
  //  10. WIZARD TOWER - Mystical tower with floating crystal orb
  // ===========================================================================

  void _paintWizardTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFF9b59b6);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.50, tier);

    // --- Mystical stone base ---
    final baseW = _s * 0.46;
    final baseH = _s * 0.10;
    final baseTop = cy + _s * 0.22;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
        Paint()..shader = ui.Gradient.linear(
          Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
          [const Color(0xFF5A4A6A), const Color(0xFF3A2A4A), const Color(0xFF2A1A3A)],
          [0.0, 0.5, 1.0]));
    _drawBrickTexture(canvas, baseRect, const Color(0xFF3A2A4A), brickH: 8, brickW: 16);

    // --- Tower body (slightly curved, mystical shape) ---
    final bodyBotW = _s * (0.26 + tier * 0.008);
    final bodyTopW = _s * (0.18 + tier * 0.005);
    final bodyBot = baseTop + 2;
    final bodyTop2 = cy - _s * (0.16 + tier * 0.015);

    final bodyPath = Path()
      ..moveTo(cx - bodyBotW / 2, bodyBot)
      ..quadraticBezierTo(cx - bodyBotW * 0.55, (bodyBot + bodyTop2) / 2,
          cx - bodyTopW / 2, bodyTop2)
      ..lineTo(cx + bodyTopW / 2, bodyTop2)
      ..quadraticBezierTo(cx + bodyBotW * 0.55, (bodyBot + bodyTop2) / 2,
          cx + bodyBotW / 2, bodyBot)
      ..close();

    canvas.drawPath(bodyPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - bodyBotW / 2, 0), Offset(cx + bodyBotW / 2, 0),
        [const Color(0xFF4A3A5A), const Color(0xFF6A5A7A), const Color(0xFF5A4A6A),
         const Color(0xFF3A2A4A)],
        [0.0, 0.35, 0.65, 1.0]));

    // Stone texture
    for (double y = bodyBot - 10; y > bodyTop2 + 6; y -= 12) {
      final t = (bodyBot - y) / (bodyBot - bodyTop2);
      final w = bodyBotW + (bodyTopW - bodyBotW) * t;
      canvas.drawLine(Offset(cx - w / 2 + 4, y), Offset(cx + w / 2 - 4, y),
        Paint()..color = const Color(0x20000000)..strokeWidth = 0.8);
    }

    // Mystical window (arched, with glow)
    final winCy = (bodyBot + bodyTop2) / 2;
    final winW = bodyBotW * 0.35;
    final winH = (bodyBot - bodyTop2) * 0.2;
    final winArch = Path()
      ..moveTo(cx - winW / 2, winCy + winH / 2)
      ..lineTo(cx - winW / 2, winCy - winH * 0.1)
      ..quadraticBezierTo(cx, winCy - winH * 0.8, cx + winW / 2, winCy - winH * 0.1)
      ..lineTo(cx + winW / 2, winCy + winH / 2)
      ..close();
    canvas.drawPath(winArch, Paint()..color = const Color(0xFF1A0A2A));
    canvas.drawPath(winArch, Paint()
      ..color = glow.withAlpha(40 + tier * 12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Body outline
    canvas.drawPath(bodyPath, Paint()
      ..color = const Color(0x44000000)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // --- Conical wizard hat roof ---
    final roofH = _s * (0.10 + tier * 0.01);
    final roofBotW = bodyTopW * 1.3;
    final roofBot = bodyTop2 + 2;
    final roofTop = roofBot - roofH;

    final roofPath = Path()
      ..moveTo(cx, roofTop)
      ..quadraticBezierTo(cx - roofBotW * 0.6, roofTop + roofH * 0.8,
          cx - roofBotW / 2, roofBot)
      ..lineTo(cx + roofBotW / 2, roofBot)
      ..quadraticBezierTo(cx + roofBotW * 0.6, roofTop + roofH * 0.8,
          cx, roofTop)
      ..close();
    canvas.drawPath(roofPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(cx - roofBotW / 2, 0), Offset(cx + roofBotW / 2, 0),
        [const Color(0xFF3A1A5A), const Color(0xFF5A3A7A), const Color(0xFF2A0A4A)],
        [0.0, 0.4, 1.0]));

    // Roof trim
    canvas.drawLine(Offset(cx - roofBotW / 2, roofBot), Offset(cx + roofBotW / 2, roofBot),
      Paint()..color = glow.withAlpha(80)..strokeWidth = 2);

    // --- Floating crystal orb above roof ---
    final orbR = _s * (0.05 + tier * 0.008);
    final orbCy = roofTop - orbR * 2;

    // Arcane aura
    canvas.drawCircle(Offset(cx, orbCy), orbR * 3.5, Paint()
      ..color = glow.withAlpha(40 + tier * 15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 + tier * 3));

    // Pentagram circle around orb
    canvas.drawCircle(Offset(cx, orbCy), orbR * 2.2, Paint()
      ..color = glow.withAlpha(60 + tier * 15)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    // Pentagram lines
    for (int i = 0; i < 5; i++) {
      final a1 = i * math.pi * 2 / 5 - math.pi / 2;
      final a2 = ((i + 2) % 5) * math.pi * 2 / 5 - math.pi / 2;
      final pr = orbR * 2.2;
      canvas.drawLine(
        Offset(cx + pr * math.cos(a1), orbCy + pr * math.sin(a1)),
        Offset(cx + pr * math.cos(a2), orbCy + pr * math.sin(a2)),
        Paint()..color = glow.withAlpha(80 + tier * 10)..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
    }

    // Crystal orb
    canvas.drawCircle(Offset(cx, orbCy), orbR, Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - orbR * 0.3, orbCy - orbR * 0.3), orbR * 1.4,
        [_lighten(glow, 0.6), glow, _darken(glow, 0.3)],
        [0.0, 0.4, 1.0]));

    // Specular highlight
    canvas.drawCircle(Offset(cx - orbR * 0.3, orbCy - orbR * 0.3),
        orbR * 0.25, Paint()..color = const Color(0x88FFFFFF));

    // Energy beam connecting orb to roof tip
    canvas.drawLine(Offset(cx, orbCy + orbR), Offset(cx, roofTop),
      Paint()..color = glow.withAlpha(100)..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    _drawRunicCircle(canvas, Offset(cx, orbCy), _s * 0.14, glow, tier);

    if (tier == 4) {
      // Orbiting rune symbols (small bright dots in pattern)
      _drawFloatingParticles(canvas, Offset(cx, orbCy), orbR * 3, glow, 8);
    }
  }

  // ===========================================================================
  //  11. SUPPORT TOWER - Golden beacon/totem with aura ring
  // ===========================================================================

  void _paintSupportTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFFffd700);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.50, tier);

    // --- Warm ambient radiance ---
    canvas.drawCircle(Offset(cx, cy), _s * (0.20 + tier * 0.03), Paint()
      ..color = glow.withAlpha(15 + tier * 5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20.0 + tier * 5));

    // --- Ornate stone base ---
    final baseW = _s * 0.44;
    final baseH = _s * 0.10;
    final baseTop = cy + _s * 0.22;
    final baseRect = Rect.fromLTWH(cx - baseW / 2, baseTop, baseW, baseH);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
        Paint()..shader = ui.Gradient.linear(
          Offset(baseRect.left, baseRect.top), Offset(baseRect.right, baseRect.bottom),
          [const Color(0xFF8A7A5A), const Color(0xFF6A5A3A), const Color(0xFF4A3A2A)],
          [0.0, 0.5, 1.0]));
    _drawBrickTexture(canvas, baseRect, const Color(0xFF6A5A3A), brickH: 8, brickW: 16);

    // --- Golden pillar/totem ---
    final pillarW = _s * 0.10;
    final pillarBot = baseTop + 2;
    final pillarTop = cy - _s * 0.08;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - pillarW / 2, pillarTop, pillarW, pillarBot - pillarTop),
        const Radius.circular(3)),
      Paint()..shader = ui.Gradient.linear(
        Offset(cx - pillarW / 2, 0), Offset(cx + pillarW / 2, 0),
        [const Color(0xFFB89A40), const Color(0xFFE0C860), const Color(0xFFD0B850),
         const Color(0xFF9A8030)],
        [0.0, 0.35, 0.65, 1.0]));

    // Decorative bands on pillar
    for (double y = pillarBot - 10; y > pillarTop + 5; y -= 14) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y), width: pillarW + 6, height: 4),
          const Radius.circular(2)),
        Paint()..color = const Color(0xFFCCAA44));
      canvas.drawLine(Offset(cx - pillarW / 2 - 3, y - 1),
          Offset(cx + pillarW / 2 + 3, y - 1),
        Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 0.8);
    }

    // --- Golden orb at top ---
    final orbR = _s * (0.07 + tier * 0.01);
    final orbCy = pillarTop - orbR * 0.8;

    // Outer aura rings (pulsing)
    for (int ring = 2 + tier; ring >= 1; ring--) {
      final ringR = orbR + ring * _s * 0.03;
      canvas.drawCircle(Offset(cx, orbCy), ringR, Paint()
        ..color = glow.withAlpha((30 - ring * 4).clamp(5, 40))
        ..style = PaintingStyle.stroke..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // Glow behind orb
    canvas.drawCircle(Offset(cx, orbCy), orbR * 2, Paint()
      ..shader = ui.Gradient.radial(Offset(cx, orbCy), orbR * 2,
        [glow.withAlpha(60 + tier * 15), glow.withAlpha(0)],
        [0.0, 1.0]));

    // Main golden orb
    canvas.drawCircle(Offset(cx, orbCy), orbR, Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx - orbR * 0.25, orbCy - orbR * 0.25), orbR * 1.4,
        [const Color(0xFFFFFF99), const Color(0xFFFFEE44),
         const Color(0xFFEECC00), const Color(0xFFCC9900)],
        [0.0, 0.3, 0.6, 1.0]));

    // Inner bright core
    canvas.drawCircle(
      Offset(cx - orbR * 0.15, orbCy - orbR * 0.15), orbR * 0.35,
      Paint()..color = const Color(0x77FFFFFF));

    // Specular
    canvas.drawCircle(
      Offset(cx - orbR * 0.3, orbCy - orbR * 0.3), orbR * 0.15,
      Paint()..color = const Color(0x99FFFFFF));

    // Plus sign emblem
    final plusW = orbR * 0.5;
    final plusP = Paint()
      ..color = const Color(0xBB2A200E)..strokeWidth = 4.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, orbCy - plusW), Offset(cx, orbCy + plusW), plusP);
    canvas.drawLine(Offset(cx - plusW, orbCy), Offset(cx + plusW, orbCy), plusP);

    // --- Light rays (more at higher tiers) ---
    if (tier >= 2) {
      final rayCount = tier * 3 + 2;
      for (int i = 0; i < rayCount; i++) {
        final a = i * math.pi * 2 / rayCount;
        final innerR = orbR * 1.2;
        final outerR = orbR * (1.6 + tier * 0.2);
        canvas.drawLine(
          Offset(cx + innerR * math.cos(a), orbCy + innerR * math.sin(a)),
          Offset(cx + outerR * math.cos(a), orbCy + outerR * math.sin(a)),
          Paint()..color = glow.withAlpha(40 + tier * 12)
            ..strokeWidth = 1.5..strokeCap = StrokeCap.round);
      }
    }

    // Orb border
    canvas.drawCircle(Offset(cx, orbCy), orbR, Paint()
      ..color = const Color(0x55AA8800)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    _drawRunicCircle(canvas, Offset(cx, orbCy), _s * 0.14, glow, tier);

    if (tier == 4) {
      _drawFloatingParticles(canvas, Offset(cx, orbCy), orbR * 3, glow, 6);
    }
  }

  // ===========================================================================
  //  12. SPIKE WALL - Low stone wall with metal spikes
  // ===========================================================================

  void _paintSpikeWallTower(Canvas canvas, int tier) {
    const cx = _s / 2;
    const cy = _s / 2;
    final glow = const Color(0xFF7f8c8d);

    _drawGroundShadow(canvas, const Offset(cx, cy), _s * 0.70, tier);

    // --- Low stone wall ---
    final wallW = _s * (0.70 + tier * 0.02);
    final wallH = _s * (0.18 + tier * 0.01);
    final wallCy = cy + _s * 0.10;
    final wallRect = Rect.fromLTWH(cx - wallW / 2, wallCy - wallH / 2, wallW, wallH);

    // Wall body with stone gradient
    canvas.drawRRect(RRect.fromRectAndRadius(wallRect, const Radius.circular(3)),
        Paint()..shader = ui.Gradient.linear(
          Offset(wallRect.left, wallRect.top), Offset(wallRect.right, wallRect.bottom),
          [const Color(0xFF6A6A6A), const Color(0xFF5A5A5A), const Color(0xFF4A4A4A),
           const Color(0xFF3A3A3A)],
          [0.0, 0.3, 0.6, 1.0]));

    // Stone brick texture
    _drawBrickTexture(canvas, wallRect, const Color(0xFF555555), brickH: 14, brickW: 26);

    // Top edge highlight
    canvas.drawLine(
      Offset(wallRect.left + 3, wallRect.top + 2),
      Offset(wallRect.right - 3, wallRect.top + 2),
      Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 2);

    // Bottom shadow
    canvas.drawLine(
      Offset(wallRect.left + 3, wallRect.bottom - 2),
      Offset(wallRect.right - 3, wallRect.bottom - 2),
      Paint()..color = const Color(0x30000000)..strokeWidth = 2);

    // Wall outline
    canvas.drawRRect(RRect.fromRectAndRadius(wallRect, const Radius.circular(3)),
        Paint()..color = const Color(0x55000000)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // --- Metal band across wall ---
    final bandY = wallCy;
    canvas.drawLine(
      Offset(wallRect.left + 4, bandY), Offset(wallRect.right - 4, bandY),
      Paint()..color = const Color(0xAA777777)..strokeWidth = 3.5);
    canvas.drawLine(
      Offset(wallRect.left + 4, bandY - 1.5), Offset(wallRect.right - 4, bandY - 1.5),
      Paint()..color = const Color(0x30FFFFFF)..strokeWidth = 1.0);

    // Rivets on band
    for (double rx = wallRect.left + 18; rx < wallRect.right - 10; rx += 22) {
      canvas.drawCircle(Offset(rx, bandY), 3, Paint()..color = const Color(0xCCBBBBBB));
      canvas.drawCircle(Offset(rx - 0.5, bandY - 0.5), 1.2, Paint()..color = const Color(0x40FFFFFF));
    }

    // --- Metal spikes ---
    final spikeCount = 3 + tier * 2; // 5 to 11 spikes
    final spikeSpacing = wallW / (spikeCount + 1);

    for (int i = 1; i <= spikeCount; i++) {
      final sx = wallRect.left + i * spikeSpacing;
      final spikeH = _s * (0.18 + tier * 0.025);
      final spikeW = _s * 0.025;
      final spikeBot = wallCy - wallH / 2 + 2;
      final spikeTop = spikeBot - spikeH;

      // Spike gradient (metallic sheen)
      final spikeGrad = ui.Gradient.linear(
        Offset(sx - spikeW, spikeTop), Offset(sx + spikeW, spikeBot),
        [const Color(0xFFE8E8E8), const Color(0xFFCCCCCC),
         const Color(0xFF999999), const Color(0xFF666666)],
        [0.0, 0.3, 0.6, 1.0]);

      final spike = Path()
        ..moveTo(sx - spikeW, spikeBot)
        ..lineTo(sx, spikeTop)
        ..lineTo(sx + spikeW, spikeBot)
        ..close();
      canvas.drawPath(spike, Paint()..shader = spikeGrad);

      // Spike edge highlight (left edge)
      canvas.drawLine(Offset(sx - spikeW * 0.4, spikeBot - 4), Offset(sx, spikeTop + 3),
        Paint()..color = const Color(0x50FFFFFF)..strokeWidth = 1.2);

      // Spike outline
      canvas.drawPath(spike, Paint()
        ..color = const Color(0x55444444)..style = PaintingStyle.stroke..strokeWidth = 0.8);

      // Spike tip glow (subtle metallic sheen)
      if (tier >= 2) {
        canvas.drawCircle(Offset(sx, spikeTop), 3 + tier * 0.5, Paint()
          ..color = glow.withAlpha(40 + tier * 15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }

    // --- Blood drips on spikes (tier 3+) ---
    if (tier >= 3) {
      for (int i = 1; i <= spikeCount; i += 3) {
        final sx = wallRect.left + i * spikeSpacing;
        final spikeBot = wallCy - wallH / 2 + 2;
        final spikeH = _s * (0.18 + tier * 0.025);
        final dripY = spikeBot - spikeH * 0.6;
        canvas.drawLine(Offset(sx + 1, dripY), Offset(sx + 2, dripY + 10),
          Paint()..color = const Color(0xBB992222)..strokeWidth = 2..strokeCap = StrokeCap.round);
      }
    }

    _drawRunicCircle(canvas, Offset(cx, wallCy), _s * 0.22, glow, tier);

    // Tier 4: dark energy between spikes
    if (tier == 4) {
      for (int i = 1; i < spikeCount; i += 2) {
        final sx1 = wallRect.left + i * spikeSpacing;
        final sx2 = wallRect.left + (i + 1) * spikeSpacing;
        final spikeBot = wallCy - wallH / 2 + 2;
        final spikeH = _s * (0.18 + tier * 0.025);
        final arcCy = spikeBot - spikeH * 0.4;
        canvas.drawArc(
          Rect.fromCenter(center: Offset((sx1 + sx2) / 2, arcCy),
              width: spikeSpacing, height: spikeH * 0.3),
          math.pi, math.pi, false,
          Paint()..color = glow.withAlpha(60)
            ..style = PaintingStyle.stroke..strokeWidth = 1.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }
  }
}
