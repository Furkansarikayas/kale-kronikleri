import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/enemy_data.dart';

/// Procedural sprite-sheet generator for all 12 enemy types.
///
/// Each sprite sheet is 512x128 — four 128x128 walk-animation frames laid out
/// horizontally. The frames differ by a subtle vertical bob offset derived from
/// `sin(frame * pi / 2)`.
///
/// Usage:
/// ```dart
/// await EnemySpriteGenerator.instance.initialize();
/// final sheet = EnemySpriteGenerator.instance.getWalkSheet(EnemyType.soldier);
/// ```
class EnemySpriteGenerator {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static final EnemySpriteGenerator instance = EnemySpriteGenerator._();
  EnemySpriteGenerator._();

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const int spriteSize = 128;
  static const int walkFrames = 4;
  static const int _sheetWidth = spriteSize * walkFrames; // 512
  static const int _sheetHeight = spriteSize; // 128

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final Map<String, ui.Image> _cache = {};
  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generates walk-animation sprite sheets for every [EnemyType].
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    for (final type in EnemyType.values) {
      final key = _cacheKey(type);
      if (!_cache.containsKey(key)) {
        _cache[key] = await _generateSheet(type);
      }
    }

    _initialized = true;
  }

  /// Returns the 512x128 walk sprite-sheet for the given [type], or null if
  /// [initialize] has not been called yet.
  ui.Image? getWalkSheet(EnemyType type) => _cache[_cacheKey(type)];

  /// Disposes all cached images. Must call [initialize] again after this.
  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Sheet generation
  // ---------------------------------------------------------------------------

  String _cacheKey(EnemyType type) => 'enemy_walk_${type.name}';

  Future<ui.Image> _generateSheet(EnemyType type) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (int frame = 0; frame < walkFrames; frame++) {
      canvas.save();
      canvas.translate(frame * spriteSize.toDouble(), 0);
      _drawFrame(canvas, type, frame);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_sheetWidth, _sheetHeight);
    picture.dispose();
    return image;
  }

  // ---------------------------------------------------------------------------
  // Per-frame drawing
  // ---------------------------------------------------------------------------

  void _drawFrame(Canvas canvas, EnemyType type, int frame) {
    final size = spriteSize.toDouble();
    final center = Offset(size / 2, size / 2);
    final r = size * 0.32; // body radius — leaves room for glow / aura
    final primary = _enemyColor(type);
    final isBoss = _isBossType(type);

    // Walk bob — slight vertical offset per frame
    final bobY = math.sin(frame * math.pi / 2) * size * 0.02;
    final bodyCenter = Offset(center.dx, center.dy + bobY);

    // 1. Shadow
    _drawShadow(canvas, center, size);

    // 2. Outer glow / aura
    _drawOuterGlow(canvas, bodyCenter, r, primary, isBoss, frame);

    // 3. Body
    if (isBoss) {
      _drawBossBody(canvas, bodyCenter, r, primary, type, frame);
    } else {
      _drawEnemyBody(canvas, bodyCenter, r, primary, type, frame);
    }

    // 4. Eyes
    _drawEyes(canvas, bodyCenter, r, primary, type, frame);
  }

  // ---------------------------------------------------------------------------
  // Shadow
  // ---------------------------------------------------------------------------

  void _drawShadow(Canvas canvas, Offset center, double size) {
    // Larger soft shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size * 0.88),
        width: size * 0.50,
        height: size * 0.10,
      ),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Inner denser shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size * 0.88),
        width: size * 0.35,
        height: size * 0.06,
      ),
      Paint()..color = const Color(0x33000000),
    );
  }

  // ---------------------------------------------------------------------------
  // Outer glow
  // ---------------------------------------------------------------------------

  void _drawOuterGlow(
    Canvas canvas,
    Offset center,
    double r,
    Color primary,
    bool isBoss,
    int frame,
  ) {
    final glowRadius = isBoss ? r * 1.55 : r * 1.20;
    final glowAlpha = isBoss ? 45 : 25;

    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..color = primary.withAlpha(glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    if (isBoss) {
      // Extra pulsing aura ring
      final pulse = (math.sin(frame * math.pi / 2) * 0.5 + 0.5);
      canvas.drawCircle(
        center,
        r * (1.65 + pulse * 0.10),
        Paint()
          ..color = primary.withAlpha((15 + (pulse * 15).round()).clamp(0, 255))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Enemy body (non-boss)
  // ---------------------------------------------------------------------------

  void _drawEnemyBody(
    Canvas canvas,
    Offset center,
    double r,
    Color primary,
    EnemyType type,
    int frame,
  ) {
    // Radial gradient — light from top-left
    final bodyGrad = ui.Gradient.radial(
      Offset(center.dx - r * 0.35, center.dy - r * 0.35),
      r * 1.8,
      [
        _lighten(primary, 0.50),
        _lighten(primary, 0.20),
        primary,
        _darken(primary, 0.30),
        _darken(primary, 0.50),
      ],
      [0.0, 0.20, 0.45, 0.75, 1.0],
    );

    switch (type) {
      case EnemyType.armoredGiant:
        _drawHexagonBody(canvas, center, r, bodyGrad, primary);
        break;
      case EnemyType.cavalry:
        _drawTeardropBody(canvas, center, r, bodyGrad, primary);
        break;
      case EnemyType.goblin:
        _drawGoblinBody(canvas, center, r, bodyGrad, primary);
        break;
      case EnemyType.shieldBearer:
        _drawShieldBearerBody(canvas, center, r, bodyGrad, primary);
        break;
      case EnemyType.darkKnight:
        _drawDiamondBody(canvas, center, r, bodyGrad, primary);
        break;
      case EnemyType.troll:
        _drawTrollBody(canvas, center, r, bodyGrad, primary);
        break;
      case EnemyType.undead:
        _drawUndeadBody(canvas, center, r, bodyGrad, primary, frame);
        break;
      default:
        // soldier, healer, burrower — circle
        _drawCircleBody(canvas, center, r, bodyGrad, primary);
        break;
    }
  }

  // --- Circle (soldier / healer / burrower) ---

  void _drawCircleBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
  ) {
    canvas.drawCircle(center, r, Paint()..shader = grad);
    // Rim light
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = _lighten(primary, 0.35).withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    // Top-left specular highlight
    _drawSpecular(canvas, center, r);
  }

  // --- Hexagon (armored giant) ---

  void _drawHexagonBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
  ) {
    final hexR = r * 1.05;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 6;
      final hx = center.dx + hexR * math.cos(angle);
      final hy = center.dy + hexR * math.sin(angle);
      if (i == 0) {
        path.moveTo(hx, hy);
      } else {
        path.lineTo(hx, hy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..shader = grad);

    // Metallic edge highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = _lighten(primary, 0.45).withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Armor plate shine
    canvas.drawCircle(
      Offset(center.dx - r * 0.30, center.dy - r * 0.30),
      r * 0.28,
      Paint()..color = const Color(0x40FFFFFF),
    );
    _drawSpecular(canvas, center, r);
  }

  // --- Teardrop (cavalry) ---

  void _drawTeardropBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
  ) {
    final path = Path()
      ..moveTo(center.dx + r * 0.95, center.dy)
      ..quadraticBezierTo(
        center.dx + r * 0.3,
        center.dy - r * 1.05,
        center.dx - r * 0.55,
        center.dy - r * 0.60,
      )
      ..quadraticBezierTo(
        center.dx - r * 1.15,
        center.dy,
        center.dx - r * 0.55,
        center.dy + r * 0.60,
      )
      ..quadraticBezierTo(
        center.dx + r * 0.3,
        center.dy + r * 1.05,
        center.dx + r * 0.95,
        center.dy,
      )
      ..close();
    canvas.drawPath(path, Paint()..shader = grad);
    canvas.drawPath(
      path,
      Paint()
        ..color = _lighten(primary, 0.25).withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    _drawSpecular(canvas, center, r);
  }

  // --- Goblin (triangle / imp) ---

  void _drawGoblinBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r * 1.05)
      ..quadraticBezierTo(
        center.dx + r * 1.05,
        center.dy - r * 0.20,
        center.dx + r * 0.75,
        center.dy + r * 0.85,
      )
      ..lineTo(center.dx - r * 0.75, center.dy + r * 0.85)
      ..quadraticBezierTo(
        center.dx - r * 1.05,
        center.dy - r * 0.20,
        center.dx,
        center.dy - r * 1.05,
      )
      ..close();
    canvas.drawPath(path, Paint()..shader = grad);
    canvas.drawPath(
      path,
      Paint()
        ..color = _lighten(primary, 0.25).withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawSpecular(canvas, Offset(center.dx, center.dy - r * 0.15), r * 0.8);
  }

  // --- ShieldBearer (rounded square) ---

  void _drawShieldBearerBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: r * 2.10, height: r * 2.10),
      Radius.circular(r * 0.22),
    );
    canvas.drawRRect(rect, Paint()..shader = grad);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _lighten(primary, 0.40).withAlpha(100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Inner shield emboss
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: r * 1.45, height: r * 1.45),
        Radius.circular(r * 0.15),
      ),
      Paint()
        ..color = _lighten(primary, 0.20).withAlpha(55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawSpecular(canvas, center, r);
  }

  // --- DarkKnight (diamond / rhombus) ---

  void _drawDiamondBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r * 1.15)
      ..lineTo(center.dx + r * 0.95, center.dy)
      ..lineTo(center.dx, center.dy + r * 1.15)
      ..lineTo(center.dx - r * 0.95, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..shader = grad);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x55FF44FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    _drawSpecular(canvas, center, r * 0.85);
  }

  // --- Troll (large oval) ---

  void _drawTrollBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 2.25, height: r * 2.45),
      Paint()..shader = grad,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 2.25, height: r * 2.45),
      Paint()
        ..color = _darken(primary, 0.25).withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    _drawSpecular(canvas, Offset(center.dx, center.dy - r * 0.10), r);
  }

  // --- Undead (ragged circle) ---

  void _drawUndeadBody(
    Canvas canvas,
    Offset center,
    double r,
    ui.Gradient grad,
    Color primary,
    int frame,
  ) {
    final bodyR = r * 0.95;
    canvas.drawCircle(center, bodyR, Paint()..shader = grad);
    // Ghostly overlay
    canvas.drawCircle(center, bodyR, Paint()..color = const Color(0x18FFFFFF));
    // Tattered edges — shift per frame for animation
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 + frame * 0.15;
      final ex = center.dx + bodyR * math.cos(angle);
      final ey = center.dy + bodyR * math.sin(angle);
      canvas.drawCircle(
        Offset(ex, ey),
        r * 0.17,
        Paint()..color = primary.withAlpha(65),
      );
    }
    _drawSpecular(canvas, center, bodyR);
  }

  // ---------------------------------------------------------------------------
  // Boss body
  // ---------------------------------------------------------------------------

  void _drawBossBody(
    Canvas canvas,
    Offset center,
    double r,
    Color primary,
    EnemyType type,
    int frame,
  ) {
    final bigR = r * 1.35;
    final pulse = (math.sin(frame * math.pi / 2) * 0.5 + 0.5);

    // Pulsing aura rings
    final auraR1 = bigR * (1.50 + pulse * 0.15);
    final auraR2 = bigR * (1.30 + pulse * 0.10);
    canvas.drawCircle(
      center,
      auraR1,
      Paint()
        ..color = Color.fromARGB(
          (18 + pulse * 12).round(),
          _to255(primary.r),
          _to255(primary.g),
          _to255(primary.b),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      auraR2,
      Paint()
        ..color = Color.fromARGB(
          (28 + pulse * 18).round(),
          _to255(primary.r),
          _to255(primary.g),
          _to255(primary.b),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Type-specific effects
    if (type == EnemyType.dragonEmperor) {
      _drawDragonEffects(canvas, center, bigR, frame, pulse);
    } else if (type == EnemyType.shadowLord) {
      _drawShadowLordEffects(canvas, center, bigR, frame, pulse);
    }

    // Main body gradient — radial, light from top-left
    final bodyGrad = ui.Gradient.radial(
      Offset(center.dx - bigR * 0.30, center.dy - bigR * 0.30),
      bigR * 1.6,
      [
        _lighten(primary, 0.40),
        _lighten(primary, 0.15),
        primary,
        _darken(primary, 0.35),
        _darken(primary, 0.55),
      ],
      [0.0, 0.20, 0.45, 0.75, 1.0],
    );
    canvas.drawCircle(center, bigR, Paint()..shader = bodyGrad);

    // Boss border — golden, pulsing
    canvas.drawCircle(
      center,
      bigR,
      Paint()
        ..color = Color.fromARGB(
          (130 + pulse * 60).round().clamp(0, 255),
          255,
          215,
          0,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
    // Second glow ring
    canvas.drawCircle(
      center,
      bigR + 4,
      Paint()
        ..color = Color.fromARGB(
          (35 + pulse * 25).round().clamp(0, 255),
          255,
          215,
          0,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Crown
    _drawCrown(canvas, center, bigR, pulse);

    // Boss specular
    _drawSpecular(canvas, center, bigR);
  }

  void _drawDragonEffects(
    Canvas canvas,
    Offset center,
    double bigR,
    int frame,
    double pulse,
  ) {
    final rng = math.Random(42);
    // Fire particles orbiting
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + frame * math.pi / 6;
      final dist = bigR * (1.25 + math.sin(frame * math.pi / 2 + i) * 0.15);
      final px = center.dx + dist * math.cos(angle);
      final py = center.dy + dist * math.sin(angle);
      final pSize = 3.5 + math.sin(frame * math.pi / 2 + i) * 1.5;
      canvas.drawCircle(
        Offset(px, py),
        pSize,
        Paint()
          ..color = Color.fromARGB(
            (190 + (pulse * 60).round()).clamp(0, 255),
            255,
            rng.nextInt(100) + 80,
            0,
          ),
      );
    }
    // Inner fire glow
    canvas.drawCircle(
      center,
      bigR * 0.45,
      Paint()
        ..color = Color.fromARGB(
          (25 + pulse * 18).round(),
          255,
          100,
          0,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawShadowLordEffects(
    Canvas canvas,
    Offset center,
    double bigR,
    int frame,
    double pulse,
  ) {
    // Shadow tendrils
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 + frame * 0.25;
      final tendrilLen =
          bigR * (1.05 + math.sin(frame * math.pi / 2 + i) * 0.30);
      final tendrilPath = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          center.dx + tendrilLen * 0.6 * math.cos(angle + 0.3),
          center.dy + tendrilLen * 0.6 * math.sin(angle + 0.3),
          center.dx + tendrilLen * math.cos(angle),
          center.dy + tendrilLen * math.sin(angle),
        );
      canvas.drawPath(
        tendrilPath,
        Paint()
          ..color = Color.fromARGB(
            (45 + pulse * 35).round(),
            80,
            0,
            120,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }
    // Dark mist
    canvas.drawCircle(
      center,
      bigR * 1.15,
      Paint()
        ..color = Color.fromARGB(
          (22 + pulse * 14).round(),
          50,
          0,
          80,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawCrown(Canvas canvas, Offset center, double bigR, double pulse) {
    final crownPaint = Paint()..color = const Color(0xEEFFD700);
    final crownY = center.dy - bigR * 0.72;
    final crownW = bigR * 0.65;
    final crownH = bigR * 0.40;

    final crown = Path()
      ..moveTo(center.dx - crownW, crownY + crownH)
      ..lineTo(center.dx - crownW, crownY)
      ..lineTo(center.dx - crownW * 0.5, crownY + crownH * 0.4)
      ..lineTo(center.dx - crownW * 0.2, crownY - crownH * 0.15)
      ..lineTo(center.dx, crownY + crownH * 0.3)
      ..lineTo(center.dx + crownW * 0.2, crownY - crownH * 0.15)
      ..lineTo(center.dx + crownW * 0.5, crownY + crownH * 0.4)
      ..lineTo(center.dx + crownW, crownY)
      ..lineTo(center.dx + crownW, crownY + crownH)
      ..close();

    canvas.drawPath(crown, crownPaint);
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xAACC9900)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Crown jewels
    canvas.drawCircle(
      Offset(center.dx, crownY + crownH * 0.1),
      3.5,
      Paint()..color = const Color(0xFFFF1111),
    );
    canvas.drawCircle(
      Offset(center.dx, crownY + crownH * 0.1),
      1.8,
      Paint()..color = const Color(0x88FFFFFF),
    );
    canvas.drawCircle(
      Offset(center.dx - crownW * 0.5, crownY + crownH * 0.25),
      2.8,
      Paint()..color = const Color(0xFF2288FF),
    );
    canvas.drawCircle(
      Offset(center.dx + crownW * 0.5, crownY + crownH * 0.25),
      2.8,
      Paint()..color = const Color(0xFF2288FF),
    );

    // Crown-tip sparkles
    for (final tipX in [
      center.dx - crownW,
      center.dx - crownW * 0.2,
      center.dx + crownW * 0.2,
      center.dx + crownW,
    ]) {
      canvas.drawCircle(
        Offset(tipX, crownY - crownH * 0.1),
        1.8,
        Paint()
          ..color = Color.fromARGB(
            (160 + pulse * 80).round().clamp(0, 255),
            255,
            255,
            200,
          ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Eyes
  // ---------------------------------------------------------------------------

  void _drawEyes(
    Canvas canvas,
    Offset center,
    double r,
    Color primary,
    EnemyType type,
    int frame,
  ) {
    switch (type) {
      case EnemyType.goblin:
        _drawGoblinEyes(canvas, center, r, frame);
        break;
      case EnemyType.undead:
        _drawGlowingEyes(canvas, center, r, const Color(0xEE44FF44));
        break;
      case EnemyType.troll:
        _drawSimpleEyes(canvas, center, r, const Color(0xEEFF2200));
        break;
      case EnemyType.darkKnight:
        _drawDarkKnightEyes(canvas, center, r, frame);
        break;
      case EnemyType.shadowLord:
        _drawShadowLordEyes(canvas, center, r * 1.35);
        break;
      case EnemyType.dragonEmperor:
        _drawDragonEyes(canvas, center, r * 1.35, frame);
        break;
      default:
        _drawSimpleEyes(canvas, center, r, const Color(0xDDFFFFFF));
        break;
    }
  }

  void _drawSimpleEyes(
    Canvas canvas,
    Offset center,
    double r,
    Color eyeColor,
  ) {
    final eyeR = r * 0.12;
    final eyeY = center.dy - r * 0.15;
    final eyeSpacing = r * 0.30;

    canvas.drawCircle(
      Offset(center.dx - eyeSpacing, eyeY),
      eyeR,
      Paint()..color = eyeColor,
    );
    canvas.drawCircle(
      Offset(center.dx + eyeSpacing, eyeY),
      eyeR,
      Paint()..color = eyeColor,
    );
    // Pupils
    canvas.drawCircle(
      Offset(center.dx - eyeSpacing + 1, eyeY + 1),
      eyeR * 0.45,
      Paint()..color = const Color(0xFF000000),
    );
    canvas.drawCircle(
      Offset(center.dx + eyeSpacing + 1, eyeY + 1),
      eyeR * 0.45,
      Paint()..color = const Color(0xFF000000),
    );
  }

  void _drawGlowingEyes(
    Canvas canvas,
    Offset center,
    double r,
    Color eyeColor,
  ) {
    final eyeR = r * 0.18;
    final eyeY = center.dy - r * 0.15;
    final eyeSpacing = r * 0.30;

    // Glow halo
    for (final dx in [-eyeSpacing, eyeSpacing]) {
      canvas.drawCircle(
        Offset(center.dx + dx, eyeY),
        eyeR * 1.7,
        Paint()
          ..color = eyeColor.withAlpha(40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(center.dx + dx, eyeY),
        eyeR,
        Paint()..color = eyeColor,
      );
    }
  }

  void _drawGoblinEyes(Canvas canvas, Offset center, double r, int frame) {
    final eyeR = r * 0.15;
    final eyeY = center.dy - r * 0.05;
    final eyeSpacing = r * 0.28;

    // Yellow eyes
    canvas.drawCircle(
      Offset(center.dx - eyeSpacing, eyeY),
      eyeR,
      Paint()..color = const Color(0xFFFFEE00),
    );
    canvas.drawCircle(
      Offset(center.dx + eyeSpacing, eyeY),
      eyeR,
      Paint()..color = const Color(0xFFFFEE00),
    );

    // Slit pupils
    for (final dx in [-eyeSpacing, eyeSpacing]) {
      canvas.drawLine(
        Offset(center.dx + dx, eyeY - eyeR * 0.7),
        Offset(center.dx + dx, eyeY + eyeR * 0.7),
        Paint()
          ..color = const Color(0xFF000000)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    // Sinister grin
    final grinPath = Path()
      ..moveTo(center.dx - r * 0.30, center.dy + r * 0.30)
      ..quadraticBezierTo(
        center.dx,
        center.dy + r * 0.60,
        center.dx + r * 0.30,
        center.dy + r * 0.30,
      );
    canvas.drawPath(
      grinPath,
      Paint()
        ..color = const Color(0xCCFF0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawDarkKnightEyes(
    Canvas canvas,
    Offset center,
    double r,
    int frame,
  ) {
    final pulse = (math.sin(frame * math.pi / 2) * 0.5 + 0.5);

    // Purple aura glow
    canvas.drawCircle(
      center,
      r * 0.50,
      Paint()
        ..color = Color.fromARGB(
          (55 + pulse * 45).round(),
          200,
          0,
          255,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Glowing eyes
    _drawGlowingEyes(canvas, center, r, const Color(0xEECC44FF));

    // Dark star rays
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 + frame * 0.3;
      canvas.drawLine(
        center,
        Offset(
          center.dx + r * 0.55 * math.cos(angle),
          center.dy + r * 0.55 * math.sin(angle),
        ),
        Paint()
          ..color = const Color(0xAACC44FF)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawShadowLordEyes(Canvas canvas, Offset center, double bigR) {
    final ir = bigR * 0.40;

    // Menacing eye
    canvas.drawOval(
      Rect.fromCenter(center: center, width: ir * 1.10, height: ir * 0.55),
      Paint()..color = const Color(0xEEFF0044),
    );
    // Pupil
    canvas.drawCircle(center, ir * 0.16, Paint()..color = const Color(0xFF000000));
    // Eye glow ring
    canvas.drawOval(
      Rect.fromCenter(center: center, width: ir * 1.40, height: ir * 0.75),
      Paint()
        ..color = const Color(0x44FF0044)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawDragonEyes(
    Canvas canvas,
    Offset center,
    double bigR,
    int frame,
  ) {
    final ir = bigR * 0.40;

    // Dragon eye
    canvas.drawOval(
      Rect.fromCenter(center: center, width: ir * 1.10, height: ir * 0.65),
      Paint()..color = const Color(0xEEFFCC00),
    );
    // Slit pupil
    canvas.drawLine(
      Offset(center.dx, center.dy - ir * 0.28),
      Offset(center.dx, center.dy + ir * 0.28),
      Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    // Fire wisps around
    for (int i = 0; i < 3; i++) {
      final angle = frame * math.pi / 3 + i * math.pi * 2 / 3;
      final fx = center.dx + ir * 0.80 * math.cos(angle);
      final fy = center.dy + ir * 0.80 * math.sin(angle);
      canvas.drawCircle(
        Offset(fx, fy),
        2.8,
        Paint()..color = const Color(0xCCFF6600),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Specular highlight
  // ---------------------------------------------------------------------------

  void _drawSpecular(Canvas canvas, Offset center, double r) {
    // Top-left radial highlight for 3D effect
    final specGrad = ui.Gradient.radial(
      Offset(center.dx - r * 0.35, center.dy - r * 0.35),
      r * 0.55,
      [
        const Color(0x55FFFFFF),
        const Color(0x22FFFFFF),
        const Color(0x00FFFFFF),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(
      Offset(center.dx - r * 0.20, center.dy - r * 0.25),
      r * 0.40,
      Paint()..shader = specGrad,
    );
  }

  // ---------------------------------------------------------------------------
  // Color helpers (matching enemy.dart)
  // ---------------------------------------------------------------------------

  /// Convert a 0.0–1.0 color channel to 0–255 int.
  static int _to255(double v) => (v * 255.0).round().clamp(0, 255);

  static Color _lighten(Color c, double amount) {
    final r = _to255(c.r);
    final g = _to255(c.g);
    final b = _to255(c.b);
    final a = _to255(c.a);
    return Color.fromARGB(
      a,
      (r + (255 - r) * amount).round().clamp(0, 255),
      (g + (255 - g) * amount).round().clamp(0, 255),
      (b + (255 - b) * amount).round().clamp(0, 255),
    );
  }

  static Color _darken(Color c, double amount) {
    final r = _to255(c.r);
    final g = _to255(c.g);
    final b = _to255(c.b);
    final a = _to255(c.a);
    return Color.fromARGB(
      a,
      (r * (1 - amount)).round().clamp(0, 255),
      (g * (1 - amount)).round().clamp(0, 255),
      (b * (1 - amount)).round().clamp(0, 255),
    );
  }

  static Color _enemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.soldier:
        return const Color(0xFFCC4444);
      case EnemyType.cavalry:
        return const Color(0xFFFF7711);
      case EnemyType.goblin:
        return const Color(0xFF44DD22);
      case EnemyType.armoredGiant:
        return const Color(0xFFAABBCC);
      case EnemyType.undead:
        return const Color(0xFF7799AA);
      case EnemyType.shieldBearer:
        return const Color(0xFF4488CC);
      case EnemyType.healer:
        return const Color(0xFF44CCAA);
      case EnemyType.burrower:
        return const Color(0xFF886644);
      case EnemyType.troll:
        return const Color(0xFF228833);
      case EnemyType.darkKnight:
        return const Color(0xFF6633AA);
      case EnemyType.shadowLord:
        return const Color(0xFF440066);
      case EnemyType.dragonEmperor:
        return const Color(0xFFDD3300);
    }
  }

  static bool _isBossType(EnemyType type) {
    return type == EnemyType.shadowLord || type == EnemyType.dragonEmperor;
  }
}
