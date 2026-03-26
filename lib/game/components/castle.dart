import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../data/game_config.dart';
import 'rendering/castle_sprites.dart';

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

  // ---------------------------------------------------------------------------
  //  Determine current damage phase from HP ratio
  // ---------------------------------------------------------------------------

  int get _damagePhase {
    if (_hp < maxHp * 0.4) return 2;
    if (_hp < maxHp * 0.7) return 1;
    return 0;
  }

  // ---------------------------------------------------------------------------
  //  Render — sprite-based with dynamic Canvas overlays
  // ---------------------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final phase = _damagePhase;

    // Draw the pre-rendered castle sprite for the current damage phase
    final sprite = CastleSpriteGenerator.instance.getSprite(phase);
    if (sprite != null) {
      final src = Rect.fromLTWH(
        0, 0, sprite.width.toDouble(), sprite.height.toDouble(),
      );
      final dst = Rect.fromLTWH(0, 0, w, h);
      canvas.drawImageRect(
        sprite,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // Dynamic overlays that animate every frame
    _renderDynamicEffects(canvas, w, h, phase);
    _renderHpBar(canvas, w, h);
  }

  // ---------------------------------------------------------------------------
  //  Dynamic effects — torch flames, animated smoke, fire glow pulse
  // ---------------------------------------------------------------------------

  void _renderDynamicEffects(Canvas canvas, double w, double h, int phase) {
    final turretW = w * 0.22;
    final ch = h * 0.05;

    // Torch flames on turret tops (always animated)
    _drawTorch(canvas, turretW * 0.5, h * 0.12 - ch - (w * 0.01));
    // Phase 2: right turret collapsed — no torch
    if (phase < 2) {
      _drawTorch(canvas, w - turretW * 0.5, h * 0.12 - ch - (w * 0.01));
    }

    // Animated flag wave overlay
    final flagWave = math.sin(_animTimer * 3.0) * 2.0 * (w / 80.0);
    _drawAnimatedFlag(canvas, turretW * 0.5, h * 0.04, flagWave, const Color(0xFFDD1111), phase, isLeft: true);
    if (phase < 2) {
      _drawAnimatedFlag(canvas, w - turretW * 0.5, h * 0.04, flagWave, const Color(0xFFDD1111), phase, isLeft: false);
    }

    // Phase 2: animated fire glow pulse emanating from cracks
    if (phase >= 2) {
      final glowPulse = (math.sin(_animTimer * 2.5) * 0.5 + 0.5);
      final glowAlpha = (20 + glowPulse * 35).round();
      final crackGlow = Paint()
        ..color = Color.fromARGB(glowAlpha, 255, 100, 20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(w * 0.37, h * 0.50), w * 0.06, crackGlow);
      canvas.drawCircle(Offset(w * 0.64, h * 0.42), w * 0.06, crackGlow);
      canvas.drawCircle(Offset(w * 0.56, h * 0.55), w * 0.05, crackGlow);

      // Animated smoke wisps rising
      final smokeT = _animTimer * 2;
      for (int i = 0; i < 4; i++) {
        final sx = w * 0.20 + i * w * 0.18;
        final sy = h * 0.08 - math.sin(smokeT + i * 1.2) * (w * 0.05) - i * (w * 0.02);
        final alpha = (45 - i * 8).clamp(0, 255);
        final smokeSize = w * 0.04 + i * w * 0.015;
        // Outer smoke
        canvas.drawCircle(
          Offset(sx, sy),
          smokeSize + w * 0.015,
          Paint()..color = Color.fromARGB((alpha * 0.4).round(), 50, 50, 50),
        );
        // Core smoke
        canvas.drawCircle(
          Offset(sx, sy),
          smokeSize,
          Paint()..color = Color.fromARGB(alpha, 60, 60, 60),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Animated flag (dynamic overlay replacing static sprite flag)
  // ---------------------------------------------------------------------------

  void _drawAnimatedFlag(Canvas canvas, double x, double y, double wave, Color color, int phase, {required bool isLeft}) {
    final isTorn = phase >= 1 && !isLeft;
    final scale = size.x / 80.0; // scale relative to original ~80px castle

    // Pole
    canvas.drawLine(
      Offset(x, y + 22 * scale),
      Offset(x, y - 4 * scale),
      Paint()
        ..color = const Color(0xFFBBBBBB)
        ..strokeWidth = 1.2 * scale
        ..strokeCap = StrokeCap.round,
    );

    if (isTorn) {
      final flagPath = Path()
        ..moveTo(x, y - 4 * scale)
        ..lineTo(x + 9 * scale + wave * 0.3, y + 1 * scale)
        ..lineTo(x + 7 * scale + wave * 0.2, y + 3 * scale)
        ..lineTo(x + 8 * scale + wave * 0.15, y + 5 * scale)
        ..lineTo(x + 6 * scale, y + 6 * scale)
        ..lineTo(x, y + 6 * scale)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = color.withAlpha(180));
    } else {
      final flagPath = Path()
        ..moveTo(x, y - 4 * scale)
        ..quadraticBezierTo(x + 5 * scale + wave * 0.5, y - 1 * scale + wave * 0.3, x + 9 * scale, y + 1 * scale + wave * 0.2)
        ..lineTo(x, y + 4 * scale)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = color);
      // Highlight
      canvas.drawPath(
        Path()
          ..moveTo(x + 1 * scale, y - 1 * scale)
          ..quadraticBezierTo(x + 4 * scale, y + wave * 0.2, x + 7 * scale, y + 1 * scale)
          ..lineTo(x + 1 * scale, y + 2 * scale)
          ..close(),
        Paint()..color = const Color(0x44FFFFFF),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Torch flame (dynamic — flickers every frame)
  // ---------------------------------------------------------------------------

  void _drawTorch(Canvas canvas, double x, double y) {
    final scale = size.x / 80.0;
    final flicker1 = math.sin(_animTimer * 6.0) * 1.0 * scale;
    final flicker2 = math.cos(_animTimer * 8.0) * 0.5 * scale;

    // Outer glow
    canvas.drawCircle(
      Offset(x, y - 2 * scale + flicker2),
      5.0 * scale,
      Paint()..color = const Color(0x22FF6600),
    );
    // Mid glow
    canvas.drawCircle(
      Offset(x, y - 2 * scale + flicker2),
      3.5 * scale,
      Paint()..color = const Color(0x44FF8800),
    );
    // Fire core (orange)
    canvas.drawCircle(
      Offset(x + flicker1 * 0.3, y - 2.5 * scale + flicker2),
      2.0 * scale,
      Paint()..color = const Color(0xCCFF8800),
    );
    // Bright center (yellow)
    canvas.drawCircle(
      Offset(x, y - 2.5 * scale + flicker2),
      1.0 * scale,
      Paint()..color = const Color(0xDDFFCC22),
    );
  }

  // ---------------------------------------------------------------------------
  //  HP bar (dynamic — changes every frame with HP)
  // ---------------------------------------------------------------------------

  void _renderHpBar(Canvas canvas, double w, double h) {
    final hpRatio = maxHp > 0 ? _hp / maxHp : 0.0;

    final barY = h + w * 0.04;
    final barH = w * 0.055;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barY, w, barH),
      Radius.circular(barH * 0.5),
    );
    canvas.drawRRect(barRect, Paint()..color = const Color(0x88000000));

    // HP gradient bar
    if (hpRatio > 0) {
      final hpColor1 = hpRatio > 0.5
          ? Color.lerp(const Color(0xFFFFFF00), const Color(0xFF00FF00), (hpRatio - 0.5) * 2)!
          : Color.lerp(const Color(0xFFFF0000), const Color(0xFFFFFF00), hpRatio * 2)!;
      final hpColor2 = _darken(hpColor1, 0.3);
      final hpGrad = ui.Gradient.linear(
        Offset(0, barY),
        Offset(0, barY + barH),
        [hpColor1, hpColor2],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barY, w * hpRatio, barH),
          Radius.circular(barH * 0.5),
        ),
        Paint()..shader = hpGrad,
      );
    }

    // HP text
    if (w > 40) {
      final fontSize = (w * 0.06).clamp(5.0, 14.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$_hp / $maxHp',
          style: TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((w - textPainter.width) / 2, barY + (barH - textPainter.height) / 2),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Helpers
  // ---------------------------------------------------------------------------

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(
      (c.a * 255.0).round().clamp(0, 255),
      (c.r * 255.0 * (1 - amount)).round().clamp(0, 255),
      (c.g * 255.0 * (1 - amount)).round().clamp(0, 255),
      (c.b * 255.0 * (1 - amount)).round().clamp(0, 255),
    );
  }
}
