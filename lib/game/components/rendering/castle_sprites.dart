import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Procedural sprite generator for the castle at 3 damage phases.
///
/// Generates 512x512 sprites for:
/// - **Phase 0 (Intact)**: Full castle with turrets, gate, windows, flags,
///   crenellations, banner, and warm glow.
/// - **Phase 1 (Damaged, HP < 70%)**: Cracks, missing bricks, one torn flag.
/// - **Phase 2 (Ruined, HP < 40%)**: Heavy damage, collapsed turret section,
///   fire glow from cracks, dark smoke wisps.
class CastleSpriteGenerator {
  static final CastleSpriteGenerator instance = CastleSpriteGenerator._();
  CastleSpriteGenerator._();

  final Map<int, ui.Image> _cache = {}; // key: damage phase 0, 1, 2
  static const int spriteSize = 512;
  static const double _s = 512.0;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Generates all 3 castle phase sprites. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;

    _cache[0] = await _renderPhase(0);
    _cache[1] = await _renderPhase(1);
    _cache[2] = await _renderPhase(2);

    _initialized = true;
  }

  /// Returns the cached sprite for [damagePhase] (0, 1, or 2).
  ui.Image? getSprite(int damagePhase) => _cache[damagePhase.clamp(0, 2)];

  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  //  Rendering pipeline
  // ---------------------------------------------------------------------------

  Future<ui.Image> _renderPhase(int phase) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintCastle(canvas, phase);
    final picture = recorder.endRecording();
    final image = await picture.toImage(spriteSize, spriteSize);
    picture.dispose();
    return image;
  }

  void _paintCastle(Canvas canvas, int phase) {
    final w = _s;
    final h = _s;

    // 1. Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.96),
        width: w * 0.92,
        height: h * 0.06,
      ),
      Paint()..color = const Color(0x55000000),
    );

    // 2. Base platform with gradient
    final baseGrad = ui.Gradient.radial(
      Offset(w * 0.4, h * 0.88),
      w * 0.8,
      [const Color(0xFF8B6B20), const Color(0xFF4A2E08)],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.82, w * 0.92, h * 0.14),
        const Radius.circular(6),
      ),
      Paint()..shader = baseGrad,
    );
    // Base platform highlight
    canvas.drawLine(
      Offset(w * 0.06, h * 0.82),
      Offset(w * 0.94, h * 0.82),
      Paint()
        ..color = const Color(0x44FFCC66)
        ..strokeWidth = 2.0,
    );

    // 3. Main castle body with rich warm gradient
    final bodyGrad = ui.Gradient.linear(
      Offset(0, h * 0.15),
      Offset(0, h * 0.8),
      [
        const Color(0xFFD4A030),
        const Color(0xFFB8842A),
        const Color(0xFF8B6518),
        const Color(0xFF6B4E10),
      ],
      [0.0, 0.3, 0.65, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.15, h * 0.18, w * 0.7, h * 0.65),
        const Radius.circular(4),
      ),
      Paint()..shader = bodyGrad,
    );

    // Body highlight edge (left side illumination)
    final highlightGrad = ui.Gradient.linear(
      Offset(w * 0.15, 0),
      Offset(w * 0.35, 0),
      [const Color(0x33FFE088), Colors.transparent],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.15, h * 0.18, w * 0.7, h * 0.65),
        const Radius.circular(4),
      ),
      Paint()..shader = highlightGrad,
    );

    // 4. Brick pattern on body
    _drawBrickPattern(canvas, w, h, phase);

    // 5. Banner / coat of arms
    _drawBanner(canvas, w * 0.40, h * 0.28, w * 0.20, h * 0.16);

    // 6. Corner turrets with gradients
    final turretW = w * 0.22;
    final turretH = h * 0.70;
    _drawTurret(canvas, 0, h * 0.12, turretW, turretH, phase, isLeft: true);
    _drawTurret(
        canvas, w - turretW, h * 0.12, turretW, turretH, phase,
        isLeft: false);

    // 7. Crenellations on turrets
    _drawCrenellations(canvas, w, h, turretW, phase);

    // 8. Top wall crenellations
    final wallCW = w * 0.055;
    final wallCH = h * 0.045;
    final crenPaint = Paint()..color = const Color(0xFFCC9930);
    for (double cx = turretW + wallCW * 0.5;
        cx < w - turretW - wallCW;
        cx += wallCW * 2) {
      canvas.drawRect(
        Rect.fromLTWH(cx, h * 0.18 - wallCH, wallCW, wallCH),
        crenPaint,
      );
    }

    // 9. Gate with arch and portcullis
    _drawGate(canvas, w, h, phase);

    // 10. Windows with warm inner glow
    _drawWindow(canvas, w * 0.25, h * 0.33, w * 0.10, h * 0.10, phase, 0);
    _drawWindow(canvas, w * 0.65, h * 0.33, w * 0.10, h * 0.10, phase, 1);

    // 11. Extra window row for detail at 512
    _drawWindow(canvas, w * 0.25, h * 0.52, w * 0.08, h * 0.08, phase, 2);
    _drawWindow(canvas, w * 0.67, h * 0.52, w * 0.08, h * 0.08, phase, 3);

    // 12. Flags on turrets (static in sprite — no wave animation)
    final flagWave = 0.0; // static snapshot
    _drawFlag(canvas, turretW * 0.5, h * 0.04, flagWave,
        const Color(0xFFDD1111), phase, isLeft: true);
    _drawFlag(canvas, w - turretW * 0.5, h * 0.04, flagWave,
        const Color(0xFFDD1111), phase, isLeft: false);

    // 13. Damage overlays
    if (phase >= 1) {
      _drawDamagePhase1(canvas, w, h);
    }
    if (phase >= 2) {
      _drawDamagePhase2(canvas, w, h);
    }
  }

  // ---------------------------------------------------------------------------
  //  Brick pattern
  // ---------------------------------------------------------------------------

  void _drawBrickPattern(Canvas canvas, double w, double h, int phase) {
    final brickPaint = Paint()
      ..color = const Color(0x25000000)
      ..strokeWidth = 1.2;
    final brickHighlight = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 0.8;

    // Horizontal brick lines
    for (double by = h * 0.22; by < h * 0.80; by += 14) {
      canvas.drawLine(
          Offset(w * 0.17, by), Offset(w * 0.83, by), brickPaint);
      canvas.drawLine(Offset(w * 0.17, by + 1.0), Offset(w * 0.83, by + 1.0),
          brickHighlight);
    }
    // Vertical brick lines (staggered)
    for (double bx = w * 0.22; bx < w * 0.82; bx += 18) {
      final row = ((bx - w * 0.22) / 18).floor();
      final yOff = (row % 2 == 0) ? 0.0 : 7.0;
      for (double by = h * 0.22 + yOff; by < h * 0.80; by += 28) {
        canvas.drawLine(
            Offset(bx, by), Offset(bx, by + 14), brickPaint);
      }
    }

    // Phase 2: some missing bricks (dark holes)
    if (phase >= 2) {
      final rng = math.Random(42);
      for (int i = 0; i < 8; i++) {
        final mx = w * 0.22 + rng.nextDouble() * w * 0.56;
        final my = h * 0.25 + rng.nextDouble() * h * 0.45;
        final mw = 10.0 + rng.nextDouble() * 12.0;
        final mh = 6.0 + rng.nextDouble() * 8.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(mx, my, mw, mh),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xBB1A0E05),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Turret
  // ---------------------------------------------------------------------------

  void _drawTurret(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    int phase, {
    required bool isLeft,
  }) {
    // Phase 2: right turret partially collapsed
    final isCollapsed = phase >= 2 && !isLeft;
    final drawH = isCollapsed ? h * 0.65 : h;
    final drawY = isCollapsed ? y + h * 0.35 : y;

    final grad = ui.Gradient.linear(
      Offset(x, drawY),
      Offset(x + w, drawY + drawH),
      [
        const Color(0xFFCC9930),
        const Color(0xFF9B7018),
        const Color(0xFF6B4E10),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, drawY, w, drawH),
        const Radius.circular(3),
      ),
      Paint()..shader = grad,
    );

    // Turret highlight edge
    canvas.drawLine(
      Offset(x + 2, drawY),
      Offset(x + 2, drawY + drawH),
      Paint()
        ..color = const Color(0x33FFE088)
        ..strokeWidth = 2.0,
    );
    // Turret shadow edge
    canvas.drawLine(
      Offset(x + w - 2, drawY),
      Offset(x + w - 2, drawY + drawH),
      Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = 2.0,
    );

    // Turret brick detail
    final tBrick = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 1.0;
    for (double ty = drawY + 8; ty < drawY + drawH - 4; ty += 12) {
      canvas.drawLine(Offset(x + 4, ty), Offset(x + w - 4, ty), tBrick);
    }

    // Small turret window
    final winX = x + w * 0.3;
    final winY = drawY + drawH * 0.25;
    final winW = w * 0.4;
    final winH = drawH * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(winX, winY, winW, winH),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF0D0602),
    );
    // Warm glow in turret window
    final twGlow = ui.Gradient.radial(
      Offset(winX + winW * 0.5, winY + winH * 0.4),
      winW * 0.6,
      [const Color(0x66FFBB33), const Color(0x22FF9900), Colors.transparent],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(winX, winY, winW, winH),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      Paint()..shader = twGlow,
    );

    // Phase 2 collapsed rubble for right turret
    if (isCollapsed) {
      final rubbleRng = math.Random(77);
      for (int i = 0; i < 12; i++) {
        final rx = x + rubbleRng.nextDouble() * w;
        final ry = drawY - 4 + rubbleRng.nextDouble() * 20;
        final rs = 3.0 + rubbleRng.nextDouble() * 8.0;
        final rubbleColor = Color.lerp(
          const Color(0xFFCC9930),
          const Color(0xFF6B4E10),
          rubbleRng.nextDouble(),
        )!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rx, ry, rs, rs * 0.7),
            const Radius.circular(1.5),
          ),
          Paint()..color = rubbleColor,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Crenellations
  // ---------------------------------------------------------------------------

  void _drawCrenellations(
      Canvas canvas, double w, double h, double turretW, int phase) {
    final crenPaint = Paint()..color = const Color(0xFFCC9930);
    final crenDark = Paint()..color = const Color(0xFF7B5A12);
    final cw = turretW * 0.38;
    final ch = h * 0.05;

    // Left turret crenellations
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.12 - ch, cw, ch), crenPaint);
    canvas.drawRect(
        Rect.fromLTWH(turretW - cw, h * 0.12 - ch, cw, ch), crenPaint);
    canvas.drawRect(
      Rect.fromLTWH(cw * 0.5, h * 0.12 - ch * 0.5, turretW - cw, ch * 0.5),
      crenDark,
    );

    // Right turret crenellations — skip if phase 2 (collapsed)
    if (phase < 2) {
      canvas.drawRect(
          Rect.fromLTWH(w - turretW, h * 0.12 - ch, cw, ch), crenPaint);
      canvas.drawRect(
          Rect.fromLTWH(w - cw, h * 0.12 - ch, cw, ch), crenPaint);
      canvas.drawRect(
        Rect.fromLTWH(
            w - turretW + cw * 0.5, h * 0.12 - ch * 0.5, turretW - cw,
            ch * 0.5),
        crenDark,
      );
    } else {
      // Broken crenellation remnants
      canvas.drawRect(
        Rect.fromLTWH(w - turretW, h * 0.12 + h * 0.35 - ch * 0.6, cw * 0.6,
            ch * 0.6),
        Paint()..color = const Color(0xFF9B7018),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Gate
  // ---------------------------------------------------------------------------

  void _drawGate(Canvas canvas, double w, double h, int phase) {
    final gateW = w * 0.22;
    final gateH = h * 0.30;
    final gateLeft = (w - gateW) / 2;
    final gateTop = h * 0.82 - gateH;

    // Gate outer frame (stone surround)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(gateLeft - 6, gateTop - 6, gateW + 12, gateH + 10),
        topLeft: const Radius.circular(28),
        topRight: const Radius.circular(28),
      ),
      Paint()..color = const Color(0xFF5A4010),
    );

    // Stone detail on gate frame
    final framePaint = Paint()
      ..color = const Color(0xFF6B5020)
      ..strokeWidth = 1.5;
    for (double fy = gateTop; fy < gateTop + gateH; fy += 16) {
      canvas.drawLine(
          Offset(gateLeft - 5, fy), Offset(gateLeft - 2, fy), framePaint);
      canvas.drawLine(Offset(gateLeft + gateW + 2, fy),
          Offset(gateLeft + gateW + 5, fy), framePaint);
    }

    // Gate shadow/depth
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(gateLeft - 2, gateTop - 2, gateW + 4, gateH + 6),
        topLeft: const Radius.circular(24),
        topRight: const Radius.circular(24),
      ),
      Paint()..color = const Color(0xFF1A0A00),
    );

    // Gate interior - deep dark gradient
    final gateGrad = ui.Gradient.linear(
      Offset(gateLeft, gateTop),
      Offset(gateLeft, gateTop + gateH),
      [
        const Color(0xFF0D0602),
        const Color(0xFF1A0E05),
        const Color(0xFF0A0500),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(gateLeft, gateTop, gateW, gateH),
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
      ),
      Paint()..shader = gateGrad,
    );

    // Gate portcullis lines
    final portPaint = Paint()
      ..color = const Color(0x55777777)
      ..strokeWidth = 1.5;
    for (double gx = gateLeft + 6; gx < gateLeft + gateW - 4; gx += 8) {
      canvas.drawLine(
        Offset(gx, gateTop + 6),
        Offset(gx, gateTop + gateH),
        portPaint,
      );
    }
    for (double gy = gateTop + 10; gy < gateTop + gateH; gy += 8) {
      canvas.drawLine(
        Offset(gateLeft + 4, gy),
        Offset(gateLeft + gateW - 4, gy),
        portPaint,
      );
    }

    // Gate arch keystone
    canvas.drawCircle(
      Offset(w * 0.5, gateTop - 3),
      4.0,
      Paint()..color = const Color(0xFFCC9930),
    );

    // Phase 2: partially broken portcullis
    if (phase >= 2) {
      // Dark smudge across gate
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
              gateLeft + 2, gateTop + gateH * 0.4, gateW - 4, gateH * 0.15),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = const Color(0x44000000),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Window
  // ---------------------------------------------------------------------------

  void _drawWindow(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    int phase,
    int windowIndex,
  ) {
    // Phase 2: some windows blown out
    final isBlownOut = phase >= 2 && windowIndex == 1;

    // Window recess
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x - 2, y - 2, w + 4, h + 4),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF120800),
    );

    if (isBlownOut) {
      // Blown out window — dark with fire glow
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, w, h),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF0A0400),
      );
      // Fire glow from inside
      final fireGlow = ui.Gradient.radial(
        Offset(x + w * 0.5, y + h * 0.6),
        w * 0.7,
        [
          const Color(0x88FF5500),
          const Color(0x44FF3300),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
      canvas.drawCircle(
        Offset(x + w * 0.5, y + h * 0.5),
        w * 0.8,
        Paint()..shader = fireGlow,
      );
    } else {
      // Warm glow
      final glowGrad = ui.Gradient.radial(
        Offset(x + w * 0.5, y + h * 0.4),
        w * 0.8,
        [
          const Color(0x88FFBB33),
          const Color(0x55FF9900),
          const Color(0x22FF6600),
        ],
        [0.0, 0.5, 1.0],
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, w, h),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        Paint()..shader = glowGrad,
      );
      // Outer glow spill
      canvas.drawCircle(
        Offset(x + w * 0.5, y + h * 0.5),
        w * 0.9,
        Paint()..color = const Color(0x0DFFAA22),
      );
      // Window cross
      canvas.drawLine(
        Offset(x + w * 0.5, y + 2),
        Offset(x + w * 0.5, y + h - 2),
        Paint()
          ..color = const Color(0x77553311)
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        Offset(x + 2, y + h * 0.45),
        Offset(x + w - 2, y + h * 0.45),
        Paint()
          ..color = const Color(0x77553311)
          ..strokeWidth = 1.5,
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Flag
  // ---------------------------------------------------------------------------

  void _drawFlag(
    Canvas canvas,
    double x,
    double y,
    double wave,
    Color color,
    int phase, {
    required bool isLeft,
  }) {
    // Phase 2: skip right flag entirely (collapsed turret)
    if (phase >= 2 && !isLeft) return;

    final isTorn = phase >= 1 && !isLeft;

    // Pole
    canvas.drawLine(
      Offset(x, y + 22),
      Offset(x, y - 4),
      Paint()
        ..color = const Color(0xFFBBBBBB)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Pole cap
    canvas.drawCircle(
      Offset(x, y - 5),
      3.0,
      Paint()..color = const Color(0xFFDDCCAA),
    );

    if (isTorn) {
      // Torn flag — jagged edge
      final flagPath = Path()
        ..moveTo(x, y - 4)
        ..lineTo(x + 18, y)
        ..lineTo(x + 14, y + 4)
        ..lineTo(x + 16, y + 6)
        ..lineTo(x + 12, y + 8)
        ..lineTo(x, y + 8)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = color.withAlpha(180));
    } else {
      // Full flag with wave
      final flagPath = Path()
        ..moveTo(x, y - 4)
        ..quadraticBezierTo(
            x + 10 + wave, y - 2 + wave * 0.3, x + 18, y + 2 + wave * 0.2)
        ..lineTo(x, y + 8)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = color);
      // Highlight
      canvas.drawPath(
        Path()
          ..moveTo(x + 2, y - 2)
          ..quadraticBezierTo(x + 8, y + wave * 0.2, x + 14, y + 2)
          ..lineTo(x + 2, y + 4)
          ..close(),
        Paint()..color = const Color(0x44FFFFFF),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Banner / coat of arms
  // ---------------------------------------------------------------------------

  void _drawBanner(Canvas canvas, double x, double y, double w, double h) {
    // Banner background — pennant shape
    final bannerPath = Path()
      ..moveTo(x, y)
      ..lineTo(x + w, y)
      ..lineTo(x + w, y + h * 0.85)
      ..lineTo(x + w * 0.5, y + h)
      ..lineTo(x, y + h * 0.85)
      ..close();

    // Dark red banner
    canvas.drawPath(bannerPath, Paint()..color = const Color(0xCC8B1111));
    // Banner border (gold)
    canvas.drawPath(
      bannerPath,
      Paint()
        ..color = const Color(0x88FFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Small shield shape as coat of arms
    final cx = x + w * 0.5;
    final cy = y + h * 0.42;
    final sw = w * 0.45;
    final sh = h * 0.38;
    final shieldPath = Path()
      ..moveTo(cx - sw * 0.5, cy - sh * 0.5)
      ..lineTo(cx + sw * 0.5, cy - sh * 0.5)
      ..lineTo(cx + sw * 0.5, cy + sh * 0.1)
      ..quadraticBezierTo(cx, cy + sh * 0.5, cx - sw * 0.5, cy + sh * 0.1)
      ..close();
    canvas.drawPath(shieldPath, Paint()..color = const Color(0x99FFD700));
    // Shield cross
    canvas.drawLine(
      Offset(cx, cy - sh * 0.35),
      Offset(cx, cy + sh * 0.25),
      Paint()
        ..color = const Color(0x558B1111)
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      Offset(cx - sw * 0.35, cy),
      Offset(cx + sw * 0.35, cy),
      Paint()
        ..color = const Color(0x558B1111)
        ..strokeWidth = 2.5,
    );
  }

  // ---------------------------------------------------------------------------
  //  Damage Phase 1 — cracks, minor damage
  // ---------------------------------------------------------------------------

  void _drawDamagePhase1(Canvas canvas, double w, double h) {
    final crackPaint = Paint()
      ..color = const Color(0x88000000)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final crackThin = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Primary crack (left body area)
    canvas.drawLine(
        Offset(w * 0.32, h * 0.35), Offset(w * 0.37, h * 0.50), crackPaint);
    canvas.drawLine(
        Offset(w * 0.37, h * 0.50), Offset(w * 0.35, h * 0.62), crackPaint);
    canvas.drawLine(
        Offset(w * 0.35, h * 0.62), Offset(w * 0.39, h * 0.72), crackPaint);
    // Branch crack
    canvas.drawLine(
        Offset(w * 0.37, h * 0.50), Offset(w * 0.44, h * 0.54), crackThin);
    canvas.drawLine(
        Offset(w * 0.44, h * 0.54), Offset(w * 0.47, h * 0.60), crackThin);

    // Secondary crack (upper right)
    canvas.drawLine(
        Offset(w * 0.62, h * 0.28), Offset(w * 0.58, h * 0.38), crackThin);
    canvas.drawLine(
        Offset(w * 0.58, h * 0.38), Offset(w * 0.63, h * 0.44), crackThin);

    // Dust/debris marks near cracks
    final dustPaint = Paint()..color = const Color(0x22553311);
    canvas.drawCircle(Offset(w * 0.37, h * 0.50), 8, dustPaint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.62), 6, dustPaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.38), 5, dustPaint);

    // Chipped bricks (small dark rectangles near cracks)
    final chipPaint = Paint()..color = const Color(0x33000000);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.34, h * 0.48, 6, 4), chipPaint);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.40, h * 0.60, 5, 3), chipPaint);
  }

  // ---------------------------------------------------------------------------
  //  Damage Phase 2 — heavy damage, fire, smoke
  // ---------------------------------------------------------------------------

  void _drawDamagePhase2(Canvas canvas, double w, double h) {
    final crackPaint = Paint()
      ..color = const Color(0xAA000000)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final crackMed = Paint()
      ..color = const Color(0x88000000)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Large crack network (right body)
    canvas.drawLine(
        Offset(w * 0.58, h * 0.26), Offset(w * 0.64, h * 0.42), crackPaint);
    canvas.drawLine(
        Offset(w * 0.64, h * 0.42), Offset(w * 0.56, h * 0.55), crackPaint);
    canvas.drawLine(
        Offset(w * 0.56, h * 0.55), Offset(w * 0.62, h * 0.70), crackPaint);
    // Branches
    canvas.drawLine(
        Offset(w * 0.64, h * 0.42), Offset(w * 0.73, h * 0.40), crackMed);
    canvas.drawLine(
        Offset(w * 0.56, h * 0.55), Offset(w * 0.48, h * 0.50), crackMed);
    canvas.drawLine(
        Offset(w * 0.48, h * 0.50), Offset(w * 0.44, h * 0.42), crackMed);

    // Additional cracks on base platform
    canvas.drawLine(
        Offset(w * 0.25, h * 0.85), Offset(w * 0.35, h * 0.88), crackMed);
    canvas.drawLine(
        Offset(w * 0.60, h * 0.84), Offset(w * 0.75, h * 0.87), crackMed);

    // Fire glow from cracks (static baked-in version)
    final crackGlow = Paint()
      ..color = const Color(0x44FF6414)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(w * 0.37, h * 0.50), 12, crackGlow);
    canvas.drawCircle(Offset(w * 0.64, h * 0.42), 12, crackGlow);
    canvas.drawCircle(Offset(w * 0.56, h * 0.55), 10, crackGlow);
    canvas.drawCircle(Offset(w * 0.62, h * 0.70), 8, crackGlow);

    // Inner fire lines along cracks
    final fireLine = Paint()
      ..color = const Color(0x55FF8822)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.58, h * 0.28), Offset(w * 0.64, h * 0.42), fireLine);
    canvas.drawLine(
        Offset(w * 0.64, h * 0.42), Offset(w * 0.56, h * 0.55), fireLine);

    // Scorch marks
    final scorchPaint = Paint()
      ..color = const Color(0x33221100)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(w * 0.40, h * 0.48), 16, scorchPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.50), 14, scorchPaint);

    // Dark smoke wisps baked into sprite
    final rng = math.Random(99);
    for (int i = 0; i < 6; i++) {
      final sx = w * 0.20 + i * w * 0.12;
      final sy = h * 0.08 + rng.nextDouble() * h * 0.08;
      final smokeSize = 8.0 + rng.nextDouble() * 10.0;
      final alpha = (35 + rng.nextInt(25)).clamp(0, 255);

      // Outer smoke
      canvas.drawCircle(
        Offset(sx, sy),
        smokeSize + 4,
        Paint()..color = Color.fromARGB((alpha * 0.4).round(), 40, 40, 40),
      );
      // Core smoke
      canvas.drawCircle(
        Offset(sx, sy),
        smokeSize,
        Paint()..color = Color.fromARGB(alpha, 55, 55, 55),
      );
    }

    // Fallen rubble at base
    final rubbleRng = math.Random(555);
    for (int i = 0; i < 10; i++) {
      final rx = w * 0.08 + rubbleRng.nextDouble() * w * 0.84;
      final ry = h * 0.90 + rubbleRng.nextDouble() * h * 0.06;
      final rs = 3.0 + rubbleRng.nextDouble() * 7.0;
      final rubbleColor = Color.lerp(
        const Color(0xFFCC9930),
        const Color(0xFF6B4E10),
        rubbleRng.nextDouble(),
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rx, ry, rs, rs * 0.6),
          const Radius.circular(1.5),
        ),
        Paint()..color = rubbleColor,
      );
    }
  }
}
