import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../data/game_config.dart';

class Castle extends RectangleComponent {
  int _hp;
  final int maxHp;
  double _animTimer = 0;

  Castle({required double cellSize, int? maxHp})
      : _hp = maxHp ?? GameConfig.baseCastleHp,
        maxHp = maxHp ?? GameConfig.baseCastleHp,
        super(
          position: Vector2((GameConfig.gridColumns - 2) * cellSize, (GameConfig.gridRows ~/ 2 - 1) * cellSize),
          size: Vector2(cellSize * 2, cellSize * 2),
          paint: Paint()..color = Colors.transparent,
        );

  int get hp => _hp;
  bool get isDestroyed => _hp <= 0;

  void takeDamage(int damage, {double damageReduction = 0.0}) {
    final actual = (damage * (1 - damageReduction)).round();
    _hp = (_hp - actual).clamp(0, maxHp);
  }

  void heal(int amount) {
    _hp = (_hp + amount).clamp(0, maxHp);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTimer += dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final hpRatio = maxHp > 0 ? _hp / maxHp : 0.0;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h + 2), width: w * 1.1, height: 8),
      Paint()..color = const Color(0x55000000),
    );

    // Base platform with rich gradient
    final baseGrad = ui.Gradient.radial(
      Offset(w * 0.4, h * 0.8),
      w * 0.8,
      [const Color(0xFF8B6B20), const Color(0xFF4A2E08)],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, h * 0.82, w - 4, h * 0.18), const Radius.circular(2)),
      Paint()..shader = baseGrad,
    );
    // Base platform highlight
    canvas.drawLine(
      Offset(4, h * 0.82), Offset(w - 4, h * 0.82),
      Paint()..color = const Color(0x33FFCC66)..strokeWidth = 0.8,
    );

    // Main castle body with rich warm gradient
    final bodyGrad = ui.Gradient.linear(
      Offset(0, h * 0.15), Offset(0, h * 0.8),
      [const Color(0xFFD4A030), const Color(0xFFB8842A), const Color(0xFF8B6518), const Color(0xFF6B4E10)],
      [0.0, 0.3, 0.65, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.15, h * 0.18, w * 0.7, h * 0.65), const Radius.circular(2)),
      Paint()..shader = bodyGrad,
    );

    // Body highlight edge (left side illumination)
    final highlightGrad = ui.Gradient.linear(
      Offset(w * 0.15, 0), Offset(w * 0.35, 0),
      [const Color(0x22FFE088), Colors.transparent],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.15, h * 0.18, w * 0.7, h * 0.65), const Radius.circular(2)),
      Paint()..shader = highlightGrad,
    );

    // Stone brick lines on body - more contrast
    final brickPaint = Paint()..color = const Color(0x25000000)..strokeWidth = 0.6;
    final brickHighlight = Paint()..color = const Color(0x0DFFFFFF)..strokeWidth = 0.4;
    for (double by = h * 0.25; by < h * 0.78; by += 6) {
      canvas.drawLine(Offset(w * 0.17, by), Offset(w * 0.83, by), brickPaint);
      canvas.drawLine(Offset(w * 0.17, by + 0.6), Offset(w * 0.83, by + 0.6), brickHighlight);
    }
    for (double bx = w * 0.25; bx < w * 0.82; bx += 8) {
      final row = ((bx - w * 0.25) / 8).floor();
      final yOff = (row % 2 == 0) ? 0.0 : 3.0;
      for (double by = h * 0.25 + yOff; by < h * 0.78; by += 12) {
        canvas.drawLine(Offset(bx, by), Offset(bx, by + 6), brickPaint);
      }
    }

    // Banner / coat of arms on main body
    _drawBanner(canvas, w * 0.42, h * 0.30, w * 0.16, h * 0.18);

    // Corner turrets with richer gradient
    final turretW = w * 0.22;
    final turretH = h * 0.7;
    _drawTurret(canvas, 0, h * 0.12, turretW, turretH);
    _drawTurret(canvas, w - turretW, h * 0.12, turretW, turretH);

    // Crenellations on turrets
    final crenPaint = Paint()..color = const Color(0xFFCC9930);
    final crenDark = Paint()..color = const Color(0xFF7B5A12);
    final cw = turretW * 0.4;
    final ch = h * 0.06;
    // Left turret
    canvas.drawRect(Rect.fromLTWH(0, h * 0.12 - ch, cw, ch), crenPaint);
    canvas.drawRect(Rect.fromLTWH(turretW - cw, h * 0.12 - ch, cw, ch), crenPaint);
    canvas.drawRect(Rect.fromLTWH(cw * 0.5, h * 0.12 - ch * 0.5, turretW - cw, ch * 0.5), crenDark);
    // Right turret
    canvas.drawRect(Rect.fromLTWH(w - turretW, h * 0.12 - ch, cw, ch), crenPaint);
    canvas.drawRect(Rect.fromLTWH(w - cw, h * 0.12 - ch, cw, ch), crenPaint);
    canvas.drawRect(Rect.fromLTWH(w - turretW + cw * 0.5, h * 0.12 - ch * 0.5, turretW - cw, ch * 0.5), crenDark);

    // Torch flames on turret tops
    _drawTorch(canvas, turretW * 0.5, h * 0.12 - ch - 1);
    _drawTorch(canvas, w - turretW * 0.5, h * 0.12 - ch - 1);

    // Top wall crenellations
    final wallCW = w * 0.06;
    final wallCH = h * 0.05;
    for (double cx = turretW + wallCW * 0.5; cx < w - turretW - wallCW; cx += wallCW * 2) {
      canvas.drawRect(Rect.fromLTWH(cx, h * 0.18 - wallCH, wallCW, wallCH), crenPaint);
    }

    // Gate with dramatic arch and depth
    final gateW = w * 0.24;
    final gateH = h * 0.35;
    final gateLeft = (w - gateW) / 2;
    final gateTop = h * 0.82 - gateH;

    // Gate outer frame (stone surround)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(gateLeft - 3, gateTop - 3, gateW + 6, gateH + 5),
        topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFF5A4010),
    );
    // Gate shadow/depth
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(gateLeft - 1, gateTop - 1, gateW + 2, gateH + 3),
        topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFF1A0A00),
    );
    // Gate interior - deep dark gradient
    final gateGrad = ui.Gradient.linear(
      Offset(gateLeft, gateTop), Offset(gateLeft, gateTop + gateH),
      [const Color(0xFF0D0602), const Color(0xFF1A0E05), const Color(0xFF0A0500)],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(gateLeft, gateTop, gateW, gateH),
        topLeft: const Radius.circular(10), topRight: const Radius.circular(10),
      ),
      Paint()..shader = gateGrad,
    );
    // Gate portcullis lines
    final portPaint = Paint()..color = const Color(0x55777777)..strokeWidth = 0.8;
    for (double gx = gateLeft + 3; gx < gateLeft + gateW - 2; gx += 4) {
      canvas.drawLine(Offset(gx, gateTop + 3), Offset(gx, gateTop + gateH), portPaint);
    }
    for (double gy = gateTop + 5; gy < gateTop + gateH; gy += 4) {
      canvas.drawLine(Offset(gateLeft + 2, gy), Offset(gateLeft + gateW - 2, gy), portPaint);
    }
    // Gate arch keystone
    canvas.drawCircle(
      Offset(w * 0.5, gateTop - 1), 2.0,
      Paint()..color = const Color(0xFFCC9930),
    );

    // Windows with brighter warm glow
    _drawWindow(canvas, w * 0.28, h * 0.35, w * 0.09, h * 0.12);
    _drawWindow(canvas, w * 0.63, h * 0.35, w * 0.09, h * 0.12);

    // Flags on turrets with animation
    final flagWave = math.sin(_animTimer * 3.0) * 2.0;
    _drawFlag(canvas, turretW * 0.5, h * 0.12 - ch - 2, flagWave, const Color(0xFFDD1111));
    _drawFlag(canvas, w - turretW * 0.5, h * 0.12 - ch - 2, flagWave, const Color(0xFFDD1111));

    // Damage effects
    if (hpRatio < 0.7) {
      // Cracks
      final crackPaint = Paint()..color = const Color(0x77000000)..strokeWidth = 1.0..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.35, h * 0.4), Offset(w * 0.4, h * 0.55), crackPaint);
      canvas.drawLine(Offset(w * 0.4, h * 0.55), Offset(w * 0.38, h * 0.65), crackPaint);
      canvas.drawLine(Offset(w * 0.38, h * 0.65), Offset(w * 0.42, h * 0.72), crackPaint);
      // Branching crack
      canvas.drawLine(Offset(w * 0.4, h * 0.55), Offset(w * 0.45, h * 0.58), crackPaint);
    }
    if (hpRatio < 0.4) {
      // More dramatic cracks
      final crackPaint = Paint()..color = const Color(0x99000000)..strokeWidth = 1.2..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.6, h * 0.3), Offset(w * 0.65, h * 0.5), crackPaint);
      canvas.drawLine(Offset(w * 0.65, h * 0.5), Offset(w * 0.58, h * 0.6), crackPaint);
      canvas.drawLine(Offset(w * 0.55, h * 0.5), Offset(w * 0.7, h * 0.55), crackPaint);
      canvas.drawLine(Offset(w * 0.58, h * 0.6), Offset(w * 0.62, h * 0.72), crackPaint);
      // Branching cracks
      canvas.drawLine(Offset(w * 0.65, h * 0.5), Offset(w * 0.72, h * 0.48), crackPaint);
      canvas.drawLine(Offset(w * 0.55, h * 0.5), Offset(w * 0.50, h * 0.45), crackPaint);

      // Red/orange glow emanating from cracks
      final glowPulse = (math.sin(_animTimer * 2.5) * 0.5 + 0.5);
      final glowAlpha = (25 + glowPulse * 30).round();
      final crackGlow = Paint()
        ..color = Color.fromARGB(glowAlpha, 255, 100, 20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(w * 0.4, h * 0.55), 6, crackGlow);
      canvas.drawCircle(Offset(w * 0.63, h * 0.5), 6, crackGlow);
      canvas.drawCircle(Offset(w * 0.58, h * 0.6), 5, crackGlow);

      // Larger, darker smoke wisps
      final smokeT = _animTimer * 2;
      for (int i = 0; i < 4; i++) {
        final sx = w * 0.25 + i * w * 0.18;
        final sy = h * 0.15 - math.sin(smokeT + i * 1.2) * 6 - i * 3;
        final alpha = (50 - i * 10).clamp(0, 255);
        final smokeSize = 4.0 + i * 1.5;
        // Outer smoke
        canvas.drawCircle(
          Offset(sx, sy), smokeSize + 2,
          Paint()..color = Color.fromARGB((alpha * 0.4).round(), 50, 50, 50),
        );
        // Core smoke
        canvas.drawCircle(
          Offset(sx, sy), smokeSize,
          Paint()..color = Color.fromARGB(alpha, 60, 60, 60),
        );
      }
    }

    // HP bar with rounded ends and gradient
    final barY = h + 5;
    final barH = 5.0;
    final barRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, barY, w, barH), const Radius.circular(2.5));
    canvas.drawRRect(barRect, Paint()..color = const Color(0x88000000));

    // HP gradient bar
    if (hpRatio > 0) {
      final hpColor1 = hpRatio > 0.5
          ? Color.lerp(const Color(0xFFFFFF00), const Color(0xFF00FF00), (hpRatio - 0.5) * 2)!
          : Color.lerp(const Color(0xFFFF0000), const Color(0xFFFFFF00), hpRatio * 2)!;
      final hpColor2 = _darken(hpColor1, 0.3);
      final hpGrad = ui.Gradient.linear(
        Offset(0, barY), Offset(0, barY + barH),
        [hpColor1, hpColor2],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, barY, w * hpRatio, barH), const Radius.circular(2.5)),
        Paint()..shader = hpGrad,
      );
    }

    // HP text - slightly larger
    if (w > 40) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$_hp / $maxHp',
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 5,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((w - textPainter.width) / 2, barY + 0.2));
    }
  }

  void _drawTurret(Canvas canvas, double x, double y, double w, double h) {
    final grad = ui.Gradient.linear(
      Offset(x, y), Offset(x + w, y + h),
      [const Color(0xFFCC9930), const Color(0xFF9B7018), const Color(0xFF6B4E10)],
      [0.0, 0.4, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(1)),
      Paint()..shader = grad,
    );
    // Turret highlight edge - brighter
    canvas.drawLine(
      Offset(x + 1, y), Offset(x + 1, y + h),
      Paint()..color = const Color(0x33FFE088)..strokeWidth = 1,
    );
    // Turret shadow edge
    canvas.drawLine(
      Offset(x + w - 1, y), Offset(x + w - 1, y + h),
      Paint()..color = const Color(0x33000000)..strokeWidth = 1,
    );
    // Turret brick detail
    final tBrick = Paint()..color = const Color(0x18000000)..strokeWidth = 0.4;
    for (double ty = y + 4; ty < y + h - 2; ty += 5) {
      canvas.drawLine(Offset(x + 2, ty), Offset(x + w - 2, ty), tBrick);
    }
  }

  void _drawWindow(Canvas canvas, double x, double y, double w, double h) {
    // Window recess
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x - 1, y - 1, w + 2, h + 2),
        topLeft: const Radius.circular(4), topRight: const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF120800),
    );
    // Warm glow - brighter and more visible
    final glowGrad = ui.Gradient.radial(
      Offset(x + w * 0.5, y + h * 0.4), w * 0.8,
      [const Color(0x77FFBB33), const Color(0x44FF9900), const Color(0x11FF6600)],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, w, h),
        topLeft: const Radius.circular(3), topRight: const Radius.circular(3),
      ),
      Paint()..shader = glowGrad,
    );
    // Outer glow spill
    canvas.drawCircle(
      Offset(x + w * 0.5, y + h * 0.5), w * 0.8,
      Paint()..color = const Color(0x0DFFAA22),
    );
    // Window cross
    canvas.drawLine(
      Offset(x + w * 0.5, y + 1), Offset(x + w * 0.5, y + h - 1),
      Paint()..color = const Color(0x77553311)..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(x + 1, y + h * 0.45), Offset(x + w - 1, y + h * 0.45),
      Paint()..color = const Color(0x77553311)..strokeWidth = 0.8,
    );
  }

  void _drawFlag(Canvas canvas, double x, double y, double wave, Color color) {
    // Pole
    canvas.drawLine(
      Offset(x, y + 10), Offset(x, y - 2),
      Paint()..color = const Color(0xFFBBBBBB)..strokeWidth = 1.2..strokeCap = StrokeCap.round,
    );
    // Flag with wave
    final flagPath = Path()
      ..moveTo(x, y - 2)
      ..quadraticBezierTo(x + 5 + wave * 0.5, y - 1 + wave * 0.3, x + 9, y + 1 + wave * 0.2)
      ..lineTo(x, y + 4)
      ..close();
    canvas.drawPath(flagPath, Paint()..color = color);
    // Highlight
    canvas.drawPath(
      Path()
        ..moveTo(x + 1, y - 1)
        ..quadraticBezierTo(x + 4, y + wave * 0.2, x + 7, y + 1)
        ..lineTo(x + 1, y + 2)
        ..close(),
      Paint()..color = const Color(0x44FFFFFF),
    );
  }

  void _drawTorch(Canvas canvas, double x, double y) {
    final flicker1 = math.sin(_animTimer * 6.0) * 1.0;
    final flicker2 = math.cos(_animTimer * 8.0) * 0.5;

    // Outer glow
    canvas.drawCircle(
      Offset(x, y - 2 + flicker2), 5.0,
      Paint()..color = const Color(0x22FF6600),
    );
    // Mid glow
    canvas.drawCircle(
      Offset(x, y - 2 + flicker2), 3.5,
      Paint()..color = const Color(0x44FF8800),
    );
    // Fire core (orange)
    canvas.drawCircle(
      Offset(x + flicker1 * 0.3, y - 2.5 + flicker2), 2.0,
      Paint()..color = const Color(0xCCFF8800),
    );
    // Bright center (yellow)
    canvas.drawCircle(
      Offset(x, y - 2.5 + flicker2), 1.0,
      Paint()..color = const Color(0xDDFFCC22),
    );
  }

  void _drawBanner(Canvas canvas, double x, double y, double w, double h) {
    // Banner background
    final bannerPath = Path()
      ..moveTo(x, y)
      ..lineTo(x + w, y)
      ..lineTo(x + w, y + h * 0.85)
      ..lineTo(x + w * 0.5, y + h)
      ..lineTo(x, y + h * 0.85)
      ..close();

    // Dark red banner
    canvas.drawPath(bannerPath, Paint()..color = const Color(0xBB8B1111));
    // Banner border
    canvas.drawPath(
      bannerPath,
      Paint()
        ..color = const Color(0x66FFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Simple coat of arms: small shield shape
    final cx = x + w * 0.5;
    final cy = y + h * 0.42;
    final sw = w * 0.4;
    final sh = h * 0.35;
    final shieldPath = Path()
      ..moveTo(cx - sw * 0.5, cy - sh * 0.5)
      ..lineTo(cx + sw * 0.5, cy - sh * 0.5)
      ..lineTo(cx + sw * 0.5, cy + sh * 0.1)
      ..quadraticBezierTo(cx, cy + sh * 0.5, cx - sw * 0.5, cy + sh * 0.1)
      ..close();
    canvas.drawPath(shieldPath, Paint()..color = const Color(0x88FFD700));
  }

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255),
    );
  }
}
