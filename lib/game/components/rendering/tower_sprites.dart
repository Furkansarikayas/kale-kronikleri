import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/tower_data.dart';

/// Procedural sprite generator for all tower types and tiers.
///
/// Generates 12 tower types x 4 tiers = 48 sprites at 256x256 resolution,
/// cached as [ui.Image] for fast rendering via `drawImageRect`.
///
/// Quality improvements over inline Canvas rendering:
/// - 256x256 resolution (vs ~40x40 display = 6.4x more detail)
/// - Proper lighting/shadow with gradients
/// - Glowing top elements with MaskFilter.blur
/// - Detailed brick textures
/// - Higher-tier towers look visibly more impressive
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

  /// Pre-renders all 48 tower sprites (12 types x 4 tiers).
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    for (final type in TowerType.values) {
      for (int tier = 1; tier <= 4; tier++) {
        final key = _cacheKey(type, tier);
        _cache[key] = await _renderSprite((canvas) {
          _paintTower(canvas, type, tier);
        });
      }
    }

    _initialized = true;
  }

  /// Returns the cached sprite for the given tower type and tier.
  /// Returns null if not yet initialized.
  ui.Image? getSprite(TowerType type, int tier) {
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
  // Colors
  // ---------------------------------------------------------------------------

  static Color _primaryColor(TowerType type) {
    switch (type) {
      case TowerType.arrow:
        return const Color(0xFF9E5B3C);
      case TowerType.ice:
        return const Color(0xFF22CCEE);
      case TowerType.fire:
        return const Color(0xFFFF5511);
      case TowerType.lightning:
        return const Color(0xFFFFDD00);
      case TowerType.poison:
        return const Color(0xFF33FF33);
      case TowerType.cannon:
        return const Color(0xFF4A5568);
      case TowerType.spikeWall:
        return const Color(0xFF555555);
      case TowerType.support:
        return const Color(0xFFDDCC00);
      case TowerType.water:
        return const Color(0xFF00BBCC);
      case TowerType.wizard:
        return const Color(0xFFAA33DD);
      case TowerType.dark:
        return const Color(0xFF3311AA);
      case TowerType.holy:
        return const Color(0xFFFFDD66);
    }
  }

  static Color _glowColor(TowerType type) {
    switch (type) {
      case TowerType.arrow:
        return const Color(0xFFd4a843);
      case TowerType.ice:
        return const Color(0xFF4ecdc4);
      case TowerType.fire:
        return const Color(0xFFe94560);
      case TowerType.lightning:
        return const Color(0xFFa78bfa);
      case TowerType.poison:
        return const Color(0xFF2ecc71);
      case TowerType.cannon:
        return const Color(0xFFe67e22);
      case TowerType.spikeWall:
        return const Color(0xFF95a5a6);
      case TowerType.support:
        return const Color(0xFFffd700);
      case TowerType.water:
        return const Color(0xFF3498db);
      case TowerType.wizard:
        return const Color(0xFF9b59b6);
      case TowerType.dark:
        return const Color(0xFF8b5cf6);
      case TowerType.holy:
        return const Color(0xFFffd700);
    }
  }

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
  // Main paint dispatcher
  // ---------------------------------------------------------------------------

  void _paintTower(Canvas canvas, TowerType type, int tier) {
    final center = const Offset(_s / 2, _s / 2);

    // 1. Shadow under platform
    _drawShadow(canvas, center, tier);

    // 2. Stone platform
    _drawPlatform(canvas, center, tier);

    // 3. Tower body (type-specific)
    if (type == TowerType.spikeWall) {
      _drawSpikeWallBody(canvas, center, tier);
    } else if (type == TowerType.support) {
      _drawSupportBody(canvas, center, tier);
    } else {
      _drawStandardBody(canvas, center, type, tier);
    }

    // 4. Type-specific top element / icon
    _drawTopElement(canvas, center, type, tier);

    // 5. Tier stars at bottom
    _drawTierStars(canvas, tier);
  }

  // ---------------------------------------------------------------------------
  // 1. Shadow
  // ---------------------------------------------------------------------------

  void _drawShadow(Canvas canvas, Offset center, int tier) {
    final shadowWidth = _s * (0.72 + tier * 0.02);
    final shadowHeight = _s * 0.18;
    final shadowY = center.dy + _s * 0.30;

    // Soft blurred shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 3, shadowY + 4),
        width: shadowWidth,
        height: shadowHeight,
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Sharper inner shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 1, shadowY + 2),
        width: shadowWidth * 0.85,
        height: shadowHeight * 0.7,
      ),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Stone platform with brick texture and 3D edges
  // ---------------------------------------------------------------------------

  void _drawPlatform(Canvas canvas, Offset center, int tier) {
    final platW = _s * (0.78 + tier * 0.02);
    final platH = _s * 0.16;
    final platY = center.dy + _s * 0.24;

    final platformRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, platY), width: platW, height: platH),
      const Radius.circular(8),
    );

    // Platform body gradient (3D stone)
    final platGrad = ui.Gradient.linear(
      Offset(center.dx - platW / 2, platY - platH / 2),
      Offset(center.dx + platW / 2, platY + platH / 2),
      [
        const Color(0xFF8A8A8A),
        const Color(0xFF777777),
        const Color(0xFF666666),
        const Color(0xFF555555),
        const Color(0xFF444444),
      ],
      [0.0, 0.2, 0.5, 0.75, 1.0],
    );
    canvas.drawRRect(platformRect, Paint()..shader = platGrad);

    // Top face highlight (3D ledge)
    final topEdge = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - platW / 2 + 3,
        platY - platH / 2,
        platW - 6,
        platH * 0.25,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      topEdge,
      Paint()..color = const Color(0x30FFFFFF),
    );

    // Bottom edge shadow (3D ledge)
    final bottomEdge = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - platW / 2 + 3,
        platY + platH / 2 - platH * 0.2,
        platW - 6,
        platH * 0.2,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bottomEdge,
      Paint()..color = const Color(0x25000000),
    );

    // Brick lines
    final brickPaint = Paint()
      ..color = const Color(0x30000000)
      ..strokeWidth = 1.0;
    final platTop = platY - platH / 2;
    final platBot = platY + platH / 2;
    final platLeft = center.dx - platW / 2;
    final platRight = center.dx + platW / 2;
    final midY = (platTop + platBot) / 2;

    // Horizontal mortar line
    canvas.drawLine(
      Offset(platLeft + 10, midY),
      Offset(platRight - 10, midY),
      brickPaint,
    );

    // Vertical mortar lines (staggered rows)
    for (double bx = platLeft + 22; bx < platRight - 10; bx += 28) {
      canvas.drawLine(Offset(bx, platTop + 4), Offset(bx, midY - 1), brickPaint);
    }
    for (double bx = platLeft + 36; bx < platRight - 10; bx += 28) {
      canvas.drawLine(Offset(bx, midY + 1), Offset(bx, platBot - 4), brickPaint);
    }

    // Platform outline
    canvas.drawRRect(
      platformRect,
      Paint()
        ..color = const Color(0x44000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ---------------------------------------------------------------------------
  // 3a. Standard tower body
  // ---------------------------------------------------------------------------

  void _drawStandardBody(
      Canvas canvas, Offset center, TowerType type, int tier) {
    final primary = _primaryColor(type);
    final bodyW = _s * (0.38 + tier * 0.015);
    final bodyH = _s * (0.52 + tier * 0.02);
    final bodyCenter = Offset(center.dx, center.dy - _s * 0.02);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: bodyCenter, width: bodyW, height: bodyH),
      Radius.circular(bodyW * 0.14),
    );

    // Main body gradient (top-left light, bottom-right shadow)
    final bodyGrad = ui.Gradient.linear(
      Offset(bodyCenter.dx - bodyW * 0.5, bodyCenter.dy - bodyH * 0.4),
      Offset(bodyCenter.dx + bodyW * 0.5, bodyCenter.dy + bodyH * 0.4),
      [
        _lighten(primary, 0.50),
        _lighten(primary, 0.25),
        primary,
        _darken(primary, 0.20),
        _darken(primary, 0.40),
      ],
      [0.0, 0.2, 0.45, 0.75, 1.0],
    );
    canvas.drawRRect(bodyRect, Paint()..shader = bodyGrad);

    // Left highlight edge (3D rim light)
    final hlLeft = bodyCenter.dx - bodyW / 2 + bodyW * 0.08;
    canvas.drawLine(
      Offset(hlLeft, bodyCenter.dy - bodyH * 0.38),
      Offset(hlLeft, bodyCenter.dy + bodyH * 0.38),
      Paint()
        ..color = _lighten(primary, 0.55).withAlpha(100)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Right shadow edge
    final hlRight = bodyCenter.dx + bodyW / 2 - bodyW * 0.08;
    canvas.drawLine(
      Offset(hlRight, bodyCenter.dy - bodyH * 0.35),
      Offset(hlRight, bodyCenter.dy + bodyH * 0.35),
      Paint()
        ..color = _darken(primary, 0.50).withAlpha(80)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Brick texture lines on body
    _drawBodyBricks(canvas, bodyCenter, bodyW, bodyH, primary);

    // Window slits (more at higher tiers)
    _drawWindowSlits(canvas, bodyCenter, bodyW, bodyH, primary, tier);

    // Body border
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = _darken(primary, 0.30).withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Crenellations at top
    _drawCrenellations(canvas, bodyCenter, bodyW, bodyH, primary, tier);
  }

  void _drawBodyBricks(Canvas canvas, Offset bodyCenter, double bodyW,
      double bodyH, Color primary) {
    final brickPaint = Paint()
      ..color = _darken(primary, 0.15).withAlpha(40)
      ..strokeWidth = 0.8;

    final top = bodyCenter.dy - bodyH / 2 + 12;
    final bot = bodyCenter.dy + bodyH / 2 - 8;
    final left = bodyCenter.dx - bodyW / 2 + 6;
    final right = bodyCenter.dx + bodyW / 2 - 6;

    // Horizontal lines
    for (double y = top; y < bot; y += 16) {
      canvas.drawLine(Offset(left, y), Offset(right, y), brickPaint);
    }

    // Vertical lines (staggered)
    int rowIdx = 0;
    for (double y = top; y < bot; y += 16) {
      final offset = (rowIdx % 2 == 0) ? 0.0 : 12.0;
      for (double x = left + offset; x < right; x += 24) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 16), brickPaint);
      }
      rowIdx++;
    }
  }

  void _drawWindowSlits(Canvas canvas, Offset bodyCenter, double bodyW,
      double bodyH, Color primary, int tier) {
    final slitCount = tier; // 1 slit for tier 1, up to 4 for tier 4
    final slitW = bodyW * 0.22;
    final slitH = bodyH * 0.06;

    for (int i = 0; i < slitCount; i++) {
      final fraction = (i + 1) / (slitCount + 1);
      final slitY = bodyCenter.dy - bodyH * 0.3 + bodyH * 0.6 * fraction;

      final slitRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bodyCenter.dx, slitY),
          width: slitW,
          height: slitH,
        ),
        Radius.circular(slitH * 0.4),
      );

      // Dark window
      canvas.drawRRect(
        slitRect,
        Paint()..color = _darken(primary, 0.60).withAlpha(180),
      );
      // Inner glow (dim light from inside)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(bodyCenter.dx, slitY),
            width: slitW * 0.6,
            height: slitH * 0.5,
          ),
          Radius.circular(slitH * 0.2),
        ),
        Paint()..color = _lighten(primary, 0.3).withAlpha(50),
      );
      // Slit border
      canvas.drawRRect(
        slitRect,
        Paint()
          ..color = _darken(primary, 0.30).withAlpha(60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  void _drawCrenellations(Canvas canvas, Offset bodyCenter, double bodyW,
      double bodyH, Color primary, int tier) {
    final topY = bodyCenter.dy - bodyH / 2;
    final crenCount = 3 + tier; // 4 at tier 1, 7 at tier 4
    final crenW = bodyW / crenCount;
    final crenH = _s * (0.06 + tier * 0.008);
    final startX = bodyCenter.dx - bodyW / 2;

    for (int i = 0; i < crenCount; i++) {
      // Only draw every other merlon (gap between)
      if (i % 2 == 0) continue;

      final cx = startX + i * crenW;
      final crenRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + crenW * 0.1, topY - crenH, crenW * 0.8, crenH + 3),
        Radius.circular(3),
      );

      // Crenellation gradient
      final crenGrad = ui.Gradient.linear(
        Offset(cx, topY - crenH),
        Offset(cx + crenW, topY),
        [
          _lighten(primary, 0.20),
          primary,
          _darken(primary, 0.25),
        ],
        [0.0, 0.4, 1.0],
      );
      canvas.drawRRect(crenRect, Paint()..shader = crenGrad);
      canvas.drawRRect(
        crenRect,
        Paint()
          ..color = _darken(primary, 0.35).withAlpha(90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 3b. SpikeWall body
  // ---------------------------------------------------------------------------

  void _drawSpikeWallBody(Canvas canvas, Offset center, int tier) {
    final baseW = _s * 0.62;
    final baseH = _s * 0.22;
    final baseCenter = Offset(center.dx, center.dy + _s * 0.05);

    // Wooden base with grain texture
    final baseRect =
        Rect.fromCenter(center: baseCenter, width: baseW, height: baseH);
    final woodGrad = ui.Gradient.linear(
      Offset(baseRect.left, 0),
      Offset(baseRect.right, 0),
      [
        const Color(0xFF7D5C3A),
        const Color(0xFF6D4C2A),
        const Color(0xFF5C4020),
        const Color(0xFF4A3518),
      ],
      [0.0, 0.3, 0.6, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
      Paint()..shader = woodGrad,
    );

    // Wood grain lines
    for (double gy = baseRect.top + 6; gy < baseRect.bottom - 4; gy += 6) {
      canvas.drawLine(
        Offset(baseRect.left + 6, gy),
        Offset(baseRect.right - 6, gy),
        Paint()
          ..color = const Color(0x25000000)
          ..strokeWidth = 0.8,
      );
    }

    // Wood border
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFF3C2810)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Metal band across middle
    final bandY = baseCenter.dy;
    canvas.drawLine(
      Offset(baseRect.left + 4, bandY),
      Offset(baseRect.right - 4, bandY),
      Paint()
        ..color = const Color(0xAA888888)
        ..strokeWidth = 3.0,
    );
    canvas.drawLine(
      Offset(baseRect.left + 4, bandY - 1),
      Offset(baseRect.right - 4, bandY - 1),
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..strokeWidth = 1.0,
    );

    // Rivets on band
    for (double rx = baseRect.left + 18;
        rx < baseRect.right - 10;
        rx += 24) {
      canvas.drawCircle(
        Offset(rx, bandY),
        2.5,
        Paint()..color = const Color(0xCCBBBBBB),
      );
      canvas.drawCircle(
        Offset(rx - 0.5, bandY - 0.5),
        1.0,
        Paint()..color = const Color(0x40FFFFFF),
      );
    }

    // Metal spikes (more at higher tiers)
    final spikeCount = 3 + tier; // 4 to 7 spikes
    final spikeSpacing = baseW / (spikeCount + 1);
    for (int i = 1; i <= spikeCount; i++) {
      final sx = baseRect.left + i * spikeSpacing;
      final spikeH = _s * (0.22 + tier * 0.03);
      final spikeW = _s * 0.035;

      // Spike gradient (metallic sheen)
      final spikeGrad = ui.Gradient.linear(
        Offset(sx - spikeW, baseCenter.dy - spikeH),
        Offset(sx + spikeW, baseCenter.dy),
        [
          const Color(0xFFE8E8E8),
          const Color(0xFFCCCCCC),
          const Color(0xFF999999),
          const Color(0xFF666666),
        ],
        [0.0, 0.3, 0.6, 1.0],
      );

      final spike = Path()
        ..moveTo(sx - spikeW, baseCenter.dy - baseH * 0.35)
        ..lineTo(sx, baseCenter.dy - spikeH)
        ..lineTo(sx + spikeW, baseCenter.dy - baseH * 0.35)
        ..close();
      canvas.drawPath(spike, Paint()..shader = spikeGrad);

      // Spike edge highlight
      canvas.drawLine(
        Offset(sx - spikeW * 0.4, baseCenter.dy - baseH * 0.2),
        Offset(sx, baseCenter.dy - spikeH + 4),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 1.0,
      );

      // Spike outline
      canvas.drawPath(
        spike,
        Paint()
          ..color = const Color(0x55444444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 3c. Support tower body
  // ---------------------------------------------------------------------------

  void _drawSupportBody(Canvas canvas, Offset center, int tier) {
    final orbR = _s * (0.14 + tier * 0.015);
    final orbCenter = Offset(center.dx, center.dy - _s * 0.02);

    // Pedestal column
    final colW = _s * 0.10;
    final colTop = orbCenter.dy + orbR * 0.5;
    final colBot = center.dy + _s * 0.20;
    final colGrad = ui.Gradient.linear(
      Offset(orbCenter.dx - colW, 0),
      Offset(orbCenter.dx + colW, 0),
      [
        const Color(0xFFC0A040),
        const Color(0xFFE0C860),
        const Color(0xFFD0B850),
        const Color(0xFFA08830),
      ],
      [0.0, 0.35, 0.65, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            orbCenter.dx - colW / 2, colTop, colW, colBot - colTop),
        const Radius.circular(3),
      ),
      Paint()..shader = colGrad,
    );

    // Outer aura rings (pulsing concentric)
    for (int ring = 3; ring >= 1; ring--) {
      final ringR = orbR + ring * _s * 0.04;
      final ringAlpha = (25 - ring * 5).clamp(5, 30);
      canvas.drawCircle(
        orbCenter,
        ringR,
        Paint()
          ..color = Color.fromARGB(ringAlpha, 255, 215, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Glow behind orb
    final glowGrad = ui.Gradient.radial(
      orbCenter,
      orbR * 1.8,
      [
        const Color(0x44FFD700),
        const Color(0x22FFCC00),
        const Color(0x00FFD700),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(orbCenter, orbR * 1.8, Paint()..shader = glowGrad);

    // Main orb
    final orbGrad = ui.Gradient.radial(
      Offset(orbCenter.dx - orbR * 0.25, orbCenter.dy - orbR * 0.25),
      orbR * 1.4,
      [
        const Color(0xFFFFFF99),
        const Color(0xFFFFEE44),
        const Color(0xFFEECC00),
        const Color(0xFFCC9900),
      ],
      [0.0, 0.3, 0.6, 1.0],
    );
    canvas.drawCircle(orbCenter, orbR, Paint()..shader = orbGrad);

    // Inner bright core
    canvas.drawCircle(
      Offset(orbCenter.dx - orbR * 0.15, orbCenter.dy - orbR * 0.15),
      orbR * 0.35,
      Paint()..color = const Color(0x77FFFFFF),
    );

    // Specular highlight
    canvas.drawCircle(
      Offset(orbCenter.dx - orbR * 0.3, orbCenter.dy - orbR * 0.3),
      orbR * 0.15,
      Paint()..color = const Color(0x99FFFFFF),
    );

    // Plus sign
    final plusW = orbR * 0.55;
    final plusPaint = Paint()
      ..color = const Color(0xBB2A200E)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(orbCenter.dx, orbCenter.dy - plusW),
      Offset(orbCenter.dx, orbCenter.dy + plusW),
      plusPaint,
    );
    canvas.drawLine(
      Offset(orbCenter.dx - plusW, orbCenter.dy),
      Offset(orbCenter.dx + plusW, orbCenter.dy),
      plusPaint,
    );

    // Tier-dependent flourishes
    if (tier >= 2) {
      // Radiating light rays
      final rayCount = tier * 2 + 2;
      for (int i = 0; i < rayCount; i++) {
        final angle = i * math.pi * 2 / rayCount;
        final innerR = orbR * 1.1;
        final outerR = orbR * (1.4 + tier * 0.1);
        canvas.drawLine(
          Offset(
            orbCenter.dx + innerR * math.cos(angle),
            orbCenter.dy + innerR * math.sin(angle),
          ),
          Offset(
            orbCenter.dx + outerR * math.cos(angle),
            orbCenter.dy + outerR * math.sin(angle),
          ),
          Paint()
            ..color = Color.fromARGB(40 + tier * 10, 255, 215, 0)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Orb border
    canvas.drawCircle(
      orbCenter,
      orbR,
      Paint()
        ..color = const Color(0x55AA8800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Top elements (glowing orb/crystal/flame)
  // ---------------------------------------------------------------------------

  void _drawTopElement(Canvas canvas, Offset center, TowerType type, int tier) {
    // SpikeWall and support have no additional top element
    if (type == TowerType.spikeWall || type == TowerType.support) return;

    final primary = _primaryColor(type);
    final glow = _glowColor(type);
    final bodyH = _s * (0.52 + tier * 0.02);
    final bodyTop = center.dy - _s * 0.02 - bodyH / 2;
    final topY = bodyTop - _s * 0.04;
    final topCenter = Offset(center.dx, topY);
    final orbR = _s * (0.04 + tier * 0.006);

    // Glow aura behind element
    final auraGrad = ui.Gradient.radial(
      topCenter,
      orbR * 3.5,
      [
        glow.withAlpha(60 + tier * 15),
        glow.withAlpha(20),
        glow.withAlpha(0),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(
      topCenter,
      orbR * 3.5,
      Paint()
        ..shader = auraGrad
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Type-specific element
    switch (type) {
      case TowerType.arrow:
        _drawArrowTopElement(canvas, topCenter, orbR, primary, glow, tier);
        break;
      case TowerType.ice:
        _drawIceCrystal(canvas, topCenter, orbR, tier);
        break;
      case TowerType.fire:
        _drawFireFlame(canvas, topCenter, orbR, tier);
        break;
      case TowerType.lightning:
        _drawLightningOrb(canvas, topCenter, orbR, tier);
        break;
      case TowerType.poison:
        _drawPoisonSkull(canvas, topCenter, orbR, tier);
        break;
      case TowerType.cannon:
        _drawCannonBarrel(canvas, topCenter, orbR, tier);
        break;
      case TowerType.water:
        _drawWaterDrop(canvas, topCenter, orbR, tier);
        break;
      case TowerType.wizard:
        _drawWizardStar(canvas, topCenter, orbR, tier);
        break;
      case TowerType.dark:
        _drawDarkOrb(canvas, topCenter, orbR, tier);
        break;
      case TowerType.holy:
        _drawHolySun(canvas, topCenter, orbR, tier);
        break;
      case TowerType.spikeWall:
      case TowerType.support:
        break; // handled above
    }
  }

  void _drawArrowTopElement(Canvas canvas, Offset center, double r,
      Color primary, Color glow, int tier) {
    // Glowing warm orb
    final orbGrad = ui.Gradient.radial(
      Offset(center.dx - r * 0.3, center.dy - r * 0.3),
      r * 2,
      [
        _lighten(glow, 0.5),
        glow,
        _darken(glow, 0.3),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(center, r * 1.3, Paint()..shader = orbGrad);

    // Arrow icon on orb
    final iconR = r * 1.0;
    canvas.drawLine(
      Offset(center.dx - iconR, center.dy + iconR),
      Offset(center.dx + iconR, center.dy - iconR),
      Paint()
        ..color = const Color(0xDDFFFFFF)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    // Arrow tip
    canvas.drawLine(
      Offset(center.dx + iconR, center.dy - iconR),
      Offset(center.dx + iconR * 0.3, center.dy - iconR * 0.7),
      Paint()
        ..color = const Color(0xDDFFFFFF)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx + iconR, center.dy - iconR),
      Offset(center.dx + iconR * 0.7, center.dy - iconR * 0.3),
      Paint()
        ..color = const Color(0xDDFFFFFF)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawIceCrystal(
      Canvas canvas, Offset center, double r, int tier) {
    // Ice crystal / snowflake
    final crystalR = r * (1.5 + tier * 0.2);

    // Glowing core
    final coreGrad = ui.Gradient.radial(
      center,
      crystalR * 0.5,
      [
        const Color(0xCCFFFFFF),
        const Color(0xAA88EEFF),
        const Color(0x4422CCEE),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(center, crystalR * 0.5, Paint()..shader = coreGrad);

    // Crystal arms (6-fold symmetry)
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      final endX = center.dx + crystalR * math.cos(angle);
      final endY = center.dy + crystalR * math.sin(angle);
      canvas.drawLine(
        center,
        Offset(endX, endY),
        Paint()
          ..color = const Color(0xCCBBEEFF)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // Branch at 2/3 of each arm
      if (tier >= 2) {
        final bx = center.dx + crystalR * 0.6 * math.cos(angle);
        final by = center.dy + crystalR * 0.6 * math.sin(angle);
        for (final side in [-1, 1]) {
          final branchAngle = angle + side * math.pi / 4;
          canvas.drawLine(
            Offset(bx, by),
            Offset(
              bx + crystalR * 0.3 * math.cos(branchAngle),
              by + crystalR * 0.3 * math.sin(branchAngle),
            ),
            Paint()
              ..color = const Color(0xAABBEEFF)
              ..strokeWidth = 1.8
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Center sparkle
    canvas.drawCircle(
      center,
      r * 0.4,
      Paint()..color = const Color(0xBBFFFFFF),
    );
  }

  void _drawFireFlame(
      Canvas canvas, Offset center, double r, int tier) {
    final flameH = r * (2.5 + tier * 0.4);
    final flameW = r * (1.5 + tier * 0.2);

    // Outer flame (orange-red)
    final outerFlame = Path()
      ..moveTo(center.dx, center.dy - flameH)
      ..quadraticBezierTo(
        center.dx + flameW * 1.2,
        center.dy - flameH * 0.2,
        center.dx + flameW * 0.5,
        center.dy + flameH * 0.3,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy + flameH * 0.1,
        center.dx - flameW * 0.5,
        center.dy + flameH * 0.3,
      )
      ..quadraticBezierTo(
        center.dx - flameW * 1.2,
        center.dy - flameH * 0.2,
        center.dx,
        center.dy - flameH,
      );
    canvas.drawPath(outerFlame, Paint()..color = const Color(0xEEFF6600));

    // Middle flame (orange-yellow)
    final midFlame = Path()
      ..moveTo(center.dx, center.dy - flameH * 0.7)
      ..quadraticBezierTo(
        center.dx + flameW * 0.7,
        center.dy - flameH * 0.05,
        center.dx + flameW * 0.25,
        center.dy + flameH * 0.2,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy + flameH * 0.05,
        center.dx - flameW * 0.25,
        center.dy + flameH * 0.2,
      )
      ..quadraticBezierTo(
        center.dx - flameW * 0.7,
        center.dy - flameH * 0.05,
        center.dx,
        center.dy - flameH * 0.7,
      );
    canvas.drawPath(midFlame, Paint()..color = const Color(0xEEFFAA00));

    // Inner flame (yellow-white core)
    final innerFlame = Path()
      ..moveTo(center.dx, center.dy - flameH * 0.4)
      ..quadraticBezierTo(
        center.dx + flameW * 0.3,
        center.dy + flameH * 0.05,
        center.dx + flameW * 0.1,
        center.dy + flameH * 0.15,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy + flameH * 0.08,
        center.dx - flameW * 0.1,
        center.dy + flameH * 0.15,
      )
      ..quadraticBezierTo(
        center.dx - flameW * 0.3,
        center.dy + flameH * 0.05,
        center.dx,
        center.dy - flameH * 0.4,
      );
    canvas.drawPath(innerFlame, Paint()..color = const Color(0xEEFFEE44));

    // White-hot core
    canvas.drawCircle(
      Offset(center.dx, center.dy + flameH * 0.05),
      r * 0.4,
      Paint()..color = const Color(0x88FFFFFF),
    );
  }

  void _drawLightningOrb(
      Canvas canvas, Offset center, double r, int tier) {
    // Crackling electric orb
    final orbR = r * (1.3 + tier * 0.15);

    // Glow sphere
    final orbGrad = ui.Gradient.radial(
      center,
      orbR,
      [
        const Color(0xDDFFFF88),
        const Color(0xBBFFEE00),
        const Color(0x55FFDD00),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(center, orbR, Paint()..shader = orbGrad);

    // Lightning bolt icon
    final boltH = orbR * 1.8;
    final bolt = Path()
      ..moveTo(center.dx + r * 0.5, center.dy - boltH * 0.5)
      ..lineTo(center.dx - r * 0.15, center.dy - boltH * 0.05)
      ..lineTo(center.dx + r * 0.4, center.dy - boltH * 0.05)
      ..lineTo(center.dx - r * 0.3, center.dy + boltH * 0.5);
    canvas.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xEEFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Electric crackle halo
    canvas.drawCircle(
      center,
      orbR * 1.2,
      Paint()
        ..color = const Color(0x33FFFF88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawPoisonSkull(
      Canvas canvas, Offset center, double r, int tier) {
    final skullR = r * (1.2 + tier * 0.15);

    // Green glow
    canvas.drawCircle(
      center,
      skullR * 1.5,
      Paint()
        ..color = const Color(0x2200FF44)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Skull body
    canvas.drawCircle(
      Offset(center.dx, center.dy - skullR * 0.1),
      skullR,
      Paint()..color = const Color(0xDD33FF44),
    );

    // Eye sockets
    final eyeR = skullR * 0.25;
    final eyeY = center.dy - skullR * 0.3;
    canvas.drawCircle(
      Offset(center.dx - skullR * 0.35, eyeY),
      eyeR,
      Paint()..color = const Color(0xFF0A0A0A),
    );
    canvas.drawCircle(
      Offset(center.dx + skullR * 0.35, eyeY),
      eyeR,
      Paint()..color = const Color(0xFF0A0A0A),
    );

    // Glowing eye dots
    canvas.drawCircle(
      Offset(center.dx - skullR * 0.35, eyeY),
      eyeR * 0.35,
      Paint()..color = const Color(0xCC00FF00),
    );
    canvas.drawCircle(
      Offset(center.dx + skullR * 0.35, eyeY),
      eyeR * 0.35,
      Paint()..color = const Color(0xCC00FF00),
    );

    // Jaw with teeth
    final jawW = skullR * 0.9;
    final jawH = skullR * 0.3;
    final jawY = center.dy + skullR * 0.45;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(center.dx, jawY), width: jawW, height: jawH),
      Paint()..color = const Color(0xDD33FF44),
    );

    // Teeth
    final toothW = skullR * 0.12;
    for (double tx = center.dx - jawW * 0.4;
        tx <= center.dx + jawW * 0.4;
        tx += toothW * 1.8) {
      canvas.drawRect(
        Rect.fromLTWH(tx, jawY - jawH * 0.5, toothW, jawH * 0.5),
        Paint()..color = const Color(0xFF0A0A0A),
      );
    }
  }

  void _drawCannonBarrel(
      Canvas canvas, Offset center, double r, int tier) {
    final barrelW = r * (2.5 + tier * 0.3);
    final barrelH = r * (1.2 + tier * 0.1);

    // Barrel gradient (metallic)
    final barrelGrad = ui.Gradient.linear(
      Offset(center.dx, center.dy - barrelH / 2),
      Offset(center.dx, center.dy + barrelH / 2),
      [
        const Color(0xCC888888),
        const Color(0xCC555555),
        const Color(0xCC333333),
        const Color(0xCC555555),
      ],
      [0.0, 0.35, 0.65, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + r * 0.3, center.dy),
          width: barrelW,
          height: barrelH,
        ),
        Radius.circular(barrelH * 0.2),
      ),
      Paint()..shader = barrelGrad,
    );

    // Barrel rings
    for (final rx in [-0.3, 0.0, 0.4]) {
      final ringX = center.dx + r * rx;
      canvas.drawLine(
        Offset(ringX, center.dy - barrelH * 0.5),
        Offset(ringX, center.dy + barrelH * 0.5),
        Paint()
          ..color = const Color(0xAA999999)
          ..strokeWidth = 2.0,
      );
    }

    // Cannonball at mouth
    final ballX = center.dx + barrelW * 0.5 + r * 0.1;
    final ballR = r * 0.5;
    final ballGrad = ui.Gradient.radial(
      Offset(ballX - ballR * 0.3, center.dy - ballR * 0.3),
      ballR,
      [
        const Color(0xCC555555),
        const Color(0xCC222222),
        const Color(0xCC111111),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(
      Offset(ballX, center.dy),
      ballR,
      Paint()..shader = ballGrad,
    );

    // Metallic barrel highlight
    canvas.drawLine(
      Offset(center.dx - barrelW * 0.3, center.dy - barrelH * 0.3),
      Offset(center.dx + barrelW * 0.4, center.dy - barrelH * 0.3),
      Paint()
        ..color = const Color(0x30FFFFFF)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawWaterDrop(
      Canvas canvas, Offset center, double r, int tier) {
    final dropH = r * (2.0 + tier * 0.3);
    final dropW = r * (1.4 + tier * 0.15);

    // Water drop shape
    final dropPath = Path()
      ..moveTo(center.dx, center.dy - dropH * 0.5)
      ..quadraticBezierTo(
        center.dx + dropW,
        center.dy + dropH * 0.15,
        center.dx,
        center.dy + dropH * 0.4,
      )
      ..quadraticBezierTo(
        center.dx - dropW,
        center.dy + dropH * 0.15,
        center.dx,
        center.dy - dropH * 0.5,
      );

    // Drop fill
    canvas.drawPath(dropPath, Paint()..color = const Color(0xDD44CCEE));

    // Inner ripple
    final innerDrop = Path()
      ..moveTo(center.dx, center.dy - dropH * 0.2)
      ..quadraticBezierTo(
        center.dx + dropW * 0.5,
        center.dy + dropH * 0.08,
        center.dx,
        center.dy + dropH * 0.25,
      )
      ..quadraticBezierTo(
        center.dx - dropW * 0.5,
        center.dy + dropH * 0.08,
        center.dx,
        center.dy - dropH * 0.2,
      );
    canvas.drawPath(innerDrop, Paint()..color = const Color(0x66FFFFFF));

    // Specular highlight
    canvas.drawCircle(
      Offset(center.dx - dropW * 0.2, center.dy - dropH * 0.15),
      r * 0.3,
      Paint()..color = const Color(0x77FFFFFF),
    );

    // Ripple waves at bottom (higher tiers)
    if (tier >= 2) {
      for (int i = 0; i < tier - 1; i++) {
        final waveY = center.dy + dropH * (0.45 + i * 0.08);
        final waveW = dropW * (0.8 - i * 0.15);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, waveY),
            width: waveW * 2,
            height: r * 0.6,
          ),
          0,
          math.pi,
          false,
          Paint()
            ..color = Color.fromARGB(40 - i * 10, 68, 204, 238)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawWizardStar(
      Canvas canvas, Offset center, double r, int tier) {
    final starR = r * (1.5 + tier * 0.2);

    // Arcane glow
    canvas.drawCircle(
      center,
      starR * 1.3,
      Paint()
        ..color = const Color(0x33DD88FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Pentagram
    for (int i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 - math.pi / 2;
      final nextAngle = ((i + 2) % 5) * math.pi * 2 / 5 - math.pi / 2;
      canvas.drawLine(
        Offset(
          center.dx + starR * math.cos(angle),
          center.dy + starR * math.sin(angle),
        ),
        Offset(
          center.dx + starR * math.cos(nextAngle),
          center.dy + starR * math.sin(nextAngle),
        ),
        Paint()
          ..color = const Color(0xDDDD88FF)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Outer circle
    canvas.drawCircle(
      center,
      starR * 1.05,
      Paint()
        ..color = const Color(0x88CC77EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Center arcane core
    final coreGrad = ui.Gradient.radial(
      center,
      starR * 0.4,
      [
        const Color(0xBBFFFFFF),
        const Color(0xAADD88FF),
        const Color(0x44AA55CC),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(center, starR * 0.35, Paint()..shader = coreGrad);
  }

  void _drawDarkOrb(
      Canvas canvas, Offset center, double r, int tier) {
    final orbR = r * (1.3 + tier * 0.15);

    // Dark void aura
    canvas.drawCircle(
      center,
      orbR * 1.6,
      Paint()
        ..color = const Color(0x227700EE)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Main dark orb
    final orbGrad = ui.Gradient.radial(
      Offset(center.dx + orbR * 0.2, center.dy - orbR * 0.1),
      orbR * 1.2,
      [
        const Color(0xDD9944FF),
        const Color(0xDD6622CC),
        const Color(0xDD3311AA),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(center, orbR, Paint()..shader = orbGrad);

    // Crescent shadow (moon-like)
    canvas.drawCircle(
      Offset(center.dx + orbR * 0.3, center.dy - orbR * 0.1),
      orbR * 0.75,
      Paint()..color = _darken(const Color(0xFF3311AA), 0.6),
    );

    // Orbiting dark particles
    for (int i = 0; i < 4 + tier; i++) {
      final angle = i * math.pi * 2 / (4 + tier);
      final px = center.dx + orbR * 1.2 * math.cos(angle);
      final py = center.dy + orbR * 1.2 * math.sin(angle);
      canvas.drawCircle(
        Offset(px, py),
        2.5,
        Paint()..color = const Color(0xBB9900FF),
      );
    }

    // Inner ethereal glow
    canvas.drawCircle(
      Offset(center.dx - orbR * 0.2, center.dy + orbR * 0.1),
      orbR * 0.25,
      Paint()..color = const Color(0x44CC66FF),
    );
  }

  void _drawHolySun(
      Canvas canvas, Offset center, double r, int tier) {
    final sunR = r * (1.0 + tier * 0.15);
    final rayCount = 6 + tier * 2;

    // Warm golden aura
    canvas.drawCircle(
      center,
      sunR * 2.5,
      Paint()
        ..color = const Color(0x22FFD700)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Rays of light
    for (int i = 0; i < rayCount; i++) {
      final angle = i * math.pi * 2 / rayCount;
      final innerR = sunR * 0.7;
      final outerR = sunR * (1.5 + tier * 0.15);

      // Main ray
      canvas.drawLine(
        Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        ),
        Offset(
          center.dx + outerR * math.cos(angle),
          center.dy + outerR * math.sin(angle),
        ),
        Paint()
          ..color = const Color(0xCCFFEE66)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );

      // Short secondary ray between main rays
      final halfAngle = angle + math.pi / rayCount;
      canvas.drawLine(
        Offset(
          center.dx + innerR * 0.9 * math.cos(halfAngle),
          center.dy + innerR * 0.9 * math.sin(halfAngle),
        ),
        Offset(
          center.dx + outerR * 0.65 * math.cos(halfAngle),
          center.dy + outerR * 0.65 * math.sin(halfAngle),
        ),
        Paint()
          ..color = const Color(0x88FFE844)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Sun body
    final sunGrad = ui.Gradient.radial(
      Offset(center.dx - sunR * 0.2, center.dy - sunR * 0.2),
      sunR,
      [
        const Color(0xFFFFFFEE),
        const Color(0xEEFFF5CC),
        const Color(0xDDFFDD66),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(center, sunR * 0.6, Paint()..shader = sunGrad);

    // White-hot center
    canvas.drawCircle(
      Offset(center.dx - sunR * 0.1, center.dy - sunR * 0.1),
      sunR * 0.25,
      Paint()..color = const Color(0xBBFFFFFF),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Tier stars
  // ---------------------------------------------------------------------------

  void _drawTierStars(Canvas canvas, int tier) {
    if (tier < 1) return;

    final starR = _s * 0.022;
    final starY = _s * 0.90;
    final totalW = tier * starR * 3.0;
    final startX = _s / 2 - totalW / 2 + starR * 1.5;

    for (int i = 0; i < tier; i++) {
      final sx = startX + i * starR * 3.0;
      final color =
          tier >= 4 ? const Color(0xFFFFD700) : const Color(0xCCFFD700);

      // Star glow (subtle)
      canvas.drawCircle(
        Offset(sx, starY),
        starR * 1.8,
        Paint()
          ..color = color.withAlpha(30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      _drawStar(canvas, sx, starY, starR, color);

      // Bright center dot
      canvas.drawCircle(
        Offset(sx, starY),
        starR * 0.25,
        Paint()..color = const Color(0x88FFFFFF),
      );
    }
  }

  void _drawStar(
      Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = i * math.pi * 2 / 5 - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 5;
      if (i == 0) {
        path.moveTo(
            cx + r * math.cos(outerAngle), cy + r * math.sin(outerAngle));
      } else {
        path.lineTo(
            cx + r * math.cos(outerAngle), cy + r * math.sin(outerAngle));
      }
      path.lineTo(cx + r * 0.45 * math.cos(innerAngle),
          cy + r * 0.45 * math.sin(innerAngle));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = _darken(color, 0.3).withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }
}
