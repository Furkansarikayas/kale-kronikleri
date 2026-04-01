import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../data/enemy_data.dart';

/// Procedural sprite-sheet generator for all 12 enemy types.
///
/// Each sprite sheet is 512x128 — four 128x128 walk-animation frames laid out
/// horizontally.
///
/// Walk cycle:
///   Frame 0: Left foot forward, right back
///   Frame 1: Both feet centered (standing)
///   Frame 2: Right foot forward, left back
///   Frame 3: Both feet centered (standing variation)
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

  Future<void> initialize() async {
    if (_initialized) return;

    for (final type in EnemyType.values) {
      final key = _cacheKey(type);
      if (!_cache.containsKey(key)) {
        // Try loading AI-generated PNG first
        final pngPath = 'assets/images/enemies/${type.name}.webp';
        final pngImage = await _tryLoadPng(pngPath);
        if (pngImage != null) {
          // Create a 4-frame sprite sheet from single image
          _cache[key] = await _createSheetFromSingle(pngImage);
          pngImage.dispose();
        } else {
          // Fallback to procedural generation
          _cache[key] = await _generateSheet(type);
        }
      }
    }

    _initialized = true;
  }

  /// Attempts to load a PNG image from asset bundle.
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

  /// Creates a 512x128 sprite sheet by tiling a single image 4 times.
  Future<ui.Image> _createSheetFromSingle(ui.Image singleFrame) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final src = Rect.fromLTWH(0, 0, singleFrame.width.toDouble(), singleFrame.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.medium;

    for (int i = 0; i < walkFrames; i++) {
      final dst = Rect.fromLTWH(
        i * spriteSize.toDouble(), 0,
        spriteSize.toDouble(), spriteSize.toDouble(),
      );
      canvas.drawImageRect(singleFrame, src, dst, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_sheetWidth, _sheetHeight);
    picture.dispose();
    return image;
  }

  ui.Image? getWalkSheet(EnemyType type) => _cache[_cacheKey(type)];

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
  // Per-frame drawing - dispatches to specific enemy painters
  // ---------------------------------------------------------------------------

  void _drawFrame(Canvas canvas, EnemyType type, int frame) {
    switch (type) {
      case EnemyType.soldier:
        _drawSoldier(canvas, frame);
      case EnemyType.cavalry:
        _drawCavalry(canvas, frame);
      case EnemyType.goblin:
        _drawGoblin(canvas, frame);
      case EnemyType.armoredGiant:
        _drawArmoredGiant(canvas, frame);
      case EnemyType.undead:
        _drawUndead(canvas, frame);
      case EnemyType.shieldBearer:
        _drawShieldBearer(canvas, frame);
      case EnemyType.healer:
        _drawHealer(canvas, frame);
      case EnemyType.burrower:
        _drawBurrower(canvas, frame);
      case EnemyType.troll:
        _drawTroll(canvas, frame);
      case EnemyType.darkKnight:
        _drawDarkKnight(canvas, frame);
      case EnemyType.shadowLord:
        _drawShadowLord(canvas, frame);
      case EnemyType.dragonEmperor:
        _drawDragonEmperor(canvas, frame);
    }
  }

  // ---------------------------------------------------------------------------
  // Walk animation helpers
  // ---------------------------------------------------------------------------

  /// Returns leg offsets for walk cycle.
  /// [0] = left leg forward amount, [1] = right leg forward amount
  /// Positive = forward (down-screen), negative = backward (up-screen)
  static List<double> _legPhase(int frame) {
    switch (frame) {
      case 0:
        return [8.0, -8.0]; // left forward, right back
      case 1:
        return [0.0, 0.0]; // centered
      case 2:
        return [-8.0, 8.0]; // right forward, left back
      case 3:
        return [0.0, 0.0]; // centered variation
      default:
        return [0.0, 0.0];
    }
  }

  /// Returns arm swing offsets (opposite to legs).
  static List<double> _armPhase(int frame) {
    final legs = _legPhase(frame);
    return [-legs[0] * 0.6, -legs[1] * 0.6];
  }

  /// Vertical body bob for walk cycle.
  static double _bodyBob(int frame) {
    switch (frame) {
      case 0:
        return -2.0;
      case 1:
        return 0.0;
      case 2:
        return -2.0;
      case 3:
        return 1.0;
      default:
        return 0.0;
    }
  }

  /// Weapon bob (slight vertical oscillation).
  static double _weaponBob(int frame) {
    return math.sin(frame * math.pi / 2) * 2.0;
  }

  // =========================================================================
  // SOLDIER - Human warrior with sword and basic armor
  // =========================================================================

  void _drawSoldier(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame);
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);
    final wBob = _weaponBob(frame);

    // Shadow
    _drawGroundShadow(canvas, s * 0.5, s * 0.92, s * 0.36, s * 0.07);

    final cx = s * 0.5;
    final baseY = s * 0.5 + bob;

    // -- Legs --
    // Left leg
    _drawLimb(
      canvas,
      Offset(cx - 8, baseY + 14),
      Offset(cx - 10, baseY + 30 + legs[0]),
      6.0,
      const Color(0xFF5A3A28),
    );
    // Left boot
    _drawBoot(canvas, Offset(cx - 10, baseY + 30 + legs[0]), const Color(0xFF3A2518));

    // Right leg
    _drawLimb(
      canvas,
      Offset(cx + 8, baseY + 14),
      Offset(cx + 10, baseY + 30 + legs[1]),
      6.0,
      const Color(0xFF5A3A28),
    );
    // Right boot
    _drawBoot(canvas, Offset(cx + 10, baseY + 30 + legs[1]), const Color(0xFF3A2518));

    // -- Torso (chainmail) --
    final torsoPath = Path()
      ..moveTo(cx - 14, baseY - 10)
      ..lineTo(cx + 14, baseY - 10)
      ..lineTo(cx + 12, baseY + 16)
      ..lineTo(cx - 12, baseY + 16)
      ..close();
    final torsoGrad = ui.Gradient.linear(
      Offset(cx - 14, baseY - 10),
      Offset(cx + 14, baseY + 16),
      [const Color(0xFF8899AA), const Color(0xFF556677), const Color(0xFF445566)],
      [0.0, 0.6, 1.0],
    );
    canvas.drawPath(torsoPath, Paint()..shader = torsoGrad);
    // Chainmail texture lines
    for (double y = baseY - 6; y < baseY + 14; y += 4) {
      canvas.drawLine(
        Offset(cx - 12, y),
        Offset(cx + 12, y),
        Paint()
          ..color = const Color(0x30FFFFFF)
          ..strokeWidth = 0.8,
      );
    }

    // Belt
    canvas.drawRect(
      Rect.fromLTWH(cx - 13, baseY + 8, 26, 4),
      Paint()..color = const Color(0xFF6B4226),
    );
    // Belt buckle
    canvas.drawRect(
      Rect.fromLTWH(cx - 3, baseY + 8.5, 6, 3),
      Paint()..color = const Color(0xFFD4A44C),
    );

    // -- Left arm (shield arm) --
    _drawLimb(
      canvas,
      Offset(cx - 14, baseY - 6),
      Offset(cx - 22, baseY + 6 + arms[0]),
      5.0,
      const Color(0xFF8899AA),
    );
    // Small round shield
    canvas.drawCircle(
      Offset(cx - 24, baseY + 2 + arms[0]),
      9,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 26, baseY - 1 + arms[0]),
          12,
          [const Color(0xFF8B4513), const Color(0xFF5C2E0A)],
        ),
    );
    canvas.drawCircle(
      Offset(cx - 24, baseY + 2 + arms[0]),
      9,
      Paint()
        ..color = const Color(0xFF3A1A08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Shield boss
    canvas.drawCircle(
      Offset(cx - 24, baseY + 2 + arms[0]),
      3,
      Paint()..color = const Color(0xFFD4A44C),
    );

    // -- Right arm (sword arm) --
    _drawLimb(
      canvas,
      Offset(cx + 14, baseY - 6),
      Offset(cx + 20, baseY + 4 + arms[1]),
      5.0,
      const Color(0xFF8899AA),
    );

    // Sword
    final swordBaseX = cx + 21;
    final swordBaseY = baseY + 4 + arms[1] + wBob;
    // Blade
    canvas.drawLine(
      Offset(swordBaseX, swordBaseY),
      Offset(swordBaseX + 4, swordBaseY - 28),
      Paint()
        ..color = const Color(0xFFD0D8E0)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    // Blade highlight
    canvas.drawLine(
      Offset(swordBaseX + 0.5, swordBaseY - 2),
      Offset(swordBaseX + 3.5, swordBaseY - 26),
      Paint()
        ..color = const Color(0x60FFFFFF)
        ..strokeWidth = 1.2,
    );
    // Guard
    canvas.drawLine(
      Offset(swordBaseX - 5, swordBaseY + 1),
      Offset(swordBaseX + 5, swordBaseY - 1),
      Paint()
        ..color = const Color(0xFFD4A44C)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    // Grip
    canvas.drawLine(
      Offset(swordBaseX, swordBaseY),
      Offset(swordBaseX - 1, swordBaseY + 6),
      Paint()
        ..color = const Color(0xFF5C3A1E)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // -- Head --
    _drawHumanHead(canvas, Offset(cx, baseY - 20 + bob), 11.0,
        const Color(0xFFDEB896), const Color(0xFFC49A78));

    // Helmet
    final helmetPath = Path()
      ..moveTo(cx - 12, baseY - 19 + bob)
      ..quadraticBezierTo(cx - 13, baseY - 34 + bob, cx, baseY - 36 + bob)
      ..quadraticBezierTo(cx + 13, baseY - 34 + bob, cx + 12, baseY - 19 + bob)
      ..close();
    canvas.drawPath(
      helmetPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 12, baseY - 36 + bob),
          Offset(cx + 12, baseY - 19 + bob),
          [const Color(0xFF8899AA), const Color(0xFF667788)],
        ),
    );
    // Helmet rim
    canvas.drawLine(
      Offset(cx - 12, baseY - 19 + bob),
      Offset(cx + 12, baseY - 19 + bob),
      Paint()
        ..color = const Color(0xFF556677)
        ..strokeWidth = 2.0,
    );
    // Visor slit
    canvas.drawLine(
      Offset(cx - 7, baseY - 22 + bob),
      Offset(cx + 7, baseY - 22 + bob),
      Paint()
        ..color = const Color(0xFF1A1A2E)
        ..strokeWidth = 2.5,
    );
    // Eyes visible through visor
    canvas.drawCircle(
      Offset(cx - 3, baseY - 22 + bob),
      1.5,
      Paint()..color = const Color(0xFFFFFFDD),
    );
    canvas.drawCircle(
      Offset(cx + 3, baseY - 22 + bob),
      1.5,
      Paint()..color = const Color(0xFFFFFFDD),
    );

    // -- Shoulder pauldrons --
    _drawPauldron(canvas, Offset(cx - 15, baseY - 10 + bob), false);
    _drawPauldron(canvas, Offset(cx + 15, baseY - 10 + bob), true);
  }

  // =========================================================================
  // CAVALRY - Rider on horseback
  // =========================================================================

  void _drawCavalry(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame);
    final legs = _legPhase(frame);
    final wBob = _weaponBob(frame);

    final cx = s * 0.5;
    final baseY = s * 0.5 + bob;

    // Shadow (wider for horse)
    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.48, s * 0.08);

    // -- Horse body --
    final horseY = baseY + 12;
    final horsePath = Path()
      ..moveTo(cx - 24, horseY - 6)
      ..cubicTo(cx - 28, horseY - 14, cx + 28, horseY - 14, cx + 24, horseY - 6)
      ..cubicTo(cx + 28, horseY + 6, cx - 28, horseY + 6, cx - 24, horseY - 6)
      ..close();
    canvas.drawPath(
      horsePath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 5, horseY - 10),
          35,
          [const Color(0xFF8B6B4A), const Color(0xFF5C3D24), const Color(0xFF3A2516)],
          [0.0, 0.5, 1.0],
        ),
    );

    // Horse legs (4 legs with walk animation)
    final horseLegY = horseY + 4;
    // Front-left
    _drawLimb(canvas, Offset(cx - 14, horseLegY),
        Offset(cx - 16, horseLegY + 18 + legs[0] * 0.7), 4.0, const Color(0xFF5C3D24));
    // Front-right
    _drawLimb(canvas, Offset(cx - 8, horseLegY),
        Offset(cx - 6, horseLegY + 18 + legs[1] * 0.7), 4.0, const Color(0xFF4A3020));
    // Hind-left
    _drawLimb(canvas, Offset(cx + 8, horseLegY),
        Offset(cx + 6, horseLegY + 18 + legs[1] * 0.7), 4.0, const Color(0xFF5C3D24));
    // Hind-right
    _drawLimb(canvas, Offset(cx + 14, horseLegY),
        Offset(cx + 16, horseLegY + 18 + legs[0] * 0.7), 4.0, const Color(0xFF4A3020));

    // Hooves
    for (final hoof in [
      Offset(cx - 16, horseLegY + 18 + legs[0] * 0.7),
      Offset(cx - 6, horseLegY + 18 + legs[1] * 0.7),
      Offset(cx + 6, horseLegY + 18 + legs[1] * 0.7),
      Offset(cx + 16, horseLegY + 18 + legs[0] * 0.7),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: hoof, width: 5, height: 3),
        Paint()..color = const Color(0xFF2A1A0E),
      );
    }

    // Horse head
    final horseHeadPath = Path()
      ..moveTo(cx - 22, horseY - 8)
      ..quadraticBezierTo(cx - 34, horseY - 18, cx - 30, horseY - 26)
      ..quadraticBezierTo(cx - 26, horseY - 30, cx - 22, horseY - 24)
      ..quadraticBezierTo(cx - 20, horseY - 16, cx - 22, horseY - 8)
      ..close();
    canvas.drawPath(
      horseHeadPath,
      Paint()..color = const Color(0xFF7A5C3E),
    );
    // Horse eye
    canvas.drawCircle(
      Offset(cx - 28, horseY - 22),
      1.8,
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // Horse tail
    final tailPath = Path()
      ..moveTo(cx + 24, horseY - 4)
      ..quadraticBezierTo(
        cx + 34, horseY + 2 + legs[0] * 0.3,
        cx + 30, horseY + 14 + legs[0] * 0.4,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = const Color(0xFF2A1A0E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );

    // Saddle
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, horseY - 12), width: 18, height: 8),
      Paint()..color = const Color(0xFF8B0000),
    );

    // -- Rider torso --
    final riderY = horseY - 24;
    final riderTorso = Path()
      ..moveTo(cx - 10, riderY - 4)
      ..lineTo(cx + 10, riderY - 4)
      ..lineTo(cx + 8, riderY + 14)
      ..lineTo(cx - 8, riderY + 14)
      ..close();
    canvas.drawPath(
      riderTorso,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 10, riderY - 4),
          Offset(cx + 10, riderY + 14),
          [const Color(0xFFCC6633), const Color(0xFF993D1A)],
        ),
    );

    // Rider legs (straddling horse)
    _drawLimb(canvas, Offset(cx - 8, riderY + 12),
        Offset(cx - 14, horseY + 2), 4.5, const Color(0xFF5A3A28));
    _drawLimb(canvas, Offset(cx + 8, riderY + 12),
        Offset(cx + 14, horseY + 2), 4.5, const Color(0xFF5A3A28));

    // Rider head
    _drawHumanHead(canvas, Offset(cx, riderY - 14), 9.0,
        const Color(0xFFDEB896), const Color(0xFFC49A78));

    // Helmet with plume
    final rHelmetPath = Path()
      ..moveTo(cx - 10, riderY - 13)
      ..quadraticBezierTo(cx - 11, riderY - 26, cx, riderY - 28)
      ..quadraticBezierTo(cx + 11, riderY - 26, cx + 10, riderY - 13)
      ..close();
    canvas.drawPath(rHelmetPath, Paint()..color = const Color(0xFF8899AA));
    // Plume
    final plumePath = Path()
      ..moveTo(cx, riderY - 28)
      ..quadraticBezierTo(cx + 6, riderY - 36, cx + 2, riderY - 40)
      ..quadraticBezierTo(cx - 4, riderY - 38, cx, riderY - 28);
    canvas.drawPath(plumePath, Paint()..color = const Color(0xFFCC2222));

    // Lance
    final lanceEndX = cx - 36.0;
    final lanceEndY = riderY - 8 + wBob;
    canvas.drawLine(
      Offset(cx + 10, riderY + 6),
      Offset(lanceEndX, lanceEndY),
      Paint()
        ..color = const Color(0xFF8B7355)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    // Lance tip
    final tipPath = Path()
      ..moveTo(lanceEndX, lanceEndY)
      ..lineTo(lanceEndX - 8, lanceEndY - 2)
      ..lineTo(lanceEndX - 2, lanceEndY + 4)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = const Color(0xFFD0D8E0));
  }

  // =========================================================================
  // GOBLIN - Small green hunched creature with dagger
  // =========================================================================

  void _drawGoblin(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame);
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);
    final wBob = _weaponBob(frame);

    final cx = s * 0.5;
    final baseY = s * 0.55 + bob; // lower center - goblin is small

    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.28, s * 0.06);

    // -- Legs (thin, bowed) --
    _drawLimb(canvas, Offset(cx - 6, baseY + 8),
        Offset(cx - 10, baseY + 22 + legs[0]), 4.0, const Color(0xFF3A8830));
    _drawLimb(canvas, Offset(cx + 6, baseY + 8),
        Offset(cx + 10, baseY + 22 + legs[1]), 4.0, const Color(0xFF3A8830));
    // Feet (clawed)
    for (final foot in [
      Offset(cx - 10, baseY + 22 + legs[0]),
      Offset(cx + 10, baseY + 22 + legs[1]),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(foot.dx, foot.dy + 2), width: 8, height: 4),
        Paint()..color = const Color(0xFF2A6620),
      );
    }

    // -- Hunched torso --
    final torsoPath = Path()
      ..moveTo(cx - 10, baseY - 8)
      ..quadraticBezierTo(cx - 14, baseY + 2, cx - 10, baseY + 10)
      ..lineTo(cx + 10, baseY + 10)
      ..quadraticBezierTo(cx + 14, baseY + 2, cx + 10, baseY - 8)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 4, baseY - 4),
          22,
          [const Color(0xFF5ABB44), const Color(0xFF3A8830), const Color(0xFF2A6620)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Tattered vest
    final vestPath = Path()
      ..moveTo(cx - 8, baseY - 6)
      ..lineTo(cx + 8, baseY - 6)
      ..lineTo(cx + 6, baseY + 8)
      ..lineTo(cx - 6, baseY + 8)
      ..close();
    canvas.drawPath(vestPath, Paint()..color = const Color(0x605A3A28));

    // -- Arms --
    // Left arm
    _drawLimb(canvas, Offset(cx - 10, baseY - 4),
        Offset(cx - 18, baseY + 8 + arms[0]), 3.5, const Color(0xFF4AA838));
    // Right arm (dagger hand)
    _drawLimb(canvas, Offset(cx + 10, baseY - 4),
        Offset(cx + 16, baseY + 4 + arms[1]), 3.5, const Color(0xFF4AA838));

    // Dagger
    final daggerX = cx + 17;
    final daggerY = baseY + 2 + arms[1] + wBob;
    canvas.drawLine(
      Offset(daggerX, daggerY),
      Offset(daggerX + 2, daggerY - 14),
      Paint()
        ..color = const Color(0xFFB8C0C8)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    // Dagger guard
    canvas.drawLine(
      Offset(daggerX - 3, daggerY + 1),
      Offset(daggerX + 3, daggerY - 1),
      Paint()
        ..color = const Color(0xFF8B7355)
        ..strokeWidth = 2.0,
    );

    // -- Head (large for goblin proportions) --
    final headY = baseY - 18 + bob;
    // Skull shape - wider, pointed chin
    final headPath = Path()
      ..moveTo(cx, headY - 12)
      ..cubicTo(cx + 16, headY - 10, cx + 14, headY + 4, cx + 4, headY + 10)
      ..lineTo(cx, headY + 12) // pointed chin
      ..lineTo(cx - 4, headY + 10)
      ..cubicTo(cx - 14, headY + 4, cx - 16, headY - 10, cx, headY - 12)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 4, headY - 6),
          18,
          [const Color(0xFF5ABB44), const Color(0xFF3A8830)],
        ),
    );

    // Pointy ears
    final leftEar = Path()
      ..moveTo(cx - 13, headY - 4)
      ..lineTo(cx - 24, headY - 10)
      ..lineTo(cx - 14, headY + 2)
      ..close();
    canvas.drawPath(leftEar, Paint()..color = const Color(0xFF4AA838));
    final rightEar = Path()
      ..moveTo(cx + 13, headY - 4)
      ..lineTo(cx + 24, headY - 10)
      ..lineTo(cx + 14, headY + 2)
      ..close();
    canvas.drawPath(rightEar, Paint()..color = const Color(0xFF4AA838));

    // Big yellow eyes
    _drawGlowingEyes(canvas, Offset(cx - 5, headY - 2), Offset(cx + 5, headY - 2),
        4.0, const Color(0xFFFFEE00), slitPupils: true);

    // Sinister grin
    final grinPath = Path()
      ..moveTo(cx - 8, headY + 4)
      ..quadraticBezierTo(cx, headY + 10, cx + 8, headY + 4);
    canvas.drawPath(
      grinPath,
      Paint()
        ..color = const Color(0xFFCC0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    // Teeth
    for (double tx = cx - 6; tx <= cx + 6; tx += 3) {
      canvas.drawLine(
        Offset(tx, headY + 5),
        Offset(tx, headY + 7.5),
        Paint()
          ..color = const Color(0xFFDDDDAA)
          ..strokeWidth = 1.2,
      );
    }
  }

  // =========================================================================
  // ARMORED GIANT - Huge figure in full plate armor, massive shield
  // =========================================================================

  void _drawArmoredGiant(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame) * 0.5; // heavy = less bob
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);

    final cx = s * 0.5;
    final baseY = s * 0.48 + bob; // slightly higher to fill more space

    _drawGroundShadow(canvas, cx, s * 0.94, s * 0.44, s * 0.09);

    // -- Massive legs --
    _drawLimb(canvas, Offset(cx - 10, baseY + 16),
        Offset(cx - 14, baseY + 34 + legs[0] * 0.5), 8.0, const Color(0xFF6A7A8A));
    _drawLimb(canvas, Offset(cx + 10, baseY + 16),
        Offset(cx + 14, baseY + 34 + legs[1] * 0.5), 8.0, const Color(0xFF6A7A8A));
    // Armored boots
    for (final foot in [
      Offset(cx - 14, baseY + 34 + legs[0] * 0.5),
      Offset(cx + 14, baseY + 34 + legs[1] * 0.5),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(foot.dx, foot.dy + 3), width: 14, height: 8),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF4A5A6A),
      );
    }

    // -- Massive torso (full plate) --
    final torsoPath = Path()
      ..moveTo(cx - 22, baseY - 14)
      ..lineTo(cx + 22, baseY - 14)
      ..lineTo(cx + 20, baseY + 18)
      ..lineTo(cx - 20, baseY + 18)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 22, baseY - 14),
          Offset(cx + 22, baseY + 18),
          [
            const Color(0xFFB0C0D0),
            const Color(0xFF8899AA),
            const Color(0xFF6A7A8A),
            const Color(0xFF556677),
          ],
          [0.0, 0.3, 0.7, 1.0],
        ),
    );
    // Armor plate lines
    canvas.drawLine(
      Offset(cx, baseY - 12),
      Offset(cx, baseY + 16),
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..strokeWidth = 1.0,
    );
    // Chest plate highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 4, baseY - 4), width: 12, height: 16),
      Paint()..color = const Color(0x20FFFFFF),
    );

    // -- Massive shoulder pauldrons --
    _drawLargePauldron(canvas, Offset(cx - 24, baseY - 16 + bob), false);
    _drawLargePauldron(canvas, Offset(cx + 24, baseY - 16 + bob), true);

    // -- Left arm holding massive shield --
    _drawLimb(canvas, Offset(cx - 22, baseY - 8),
        Offset(cx - 28, baseY + 8 + arms[0] * 0.3), 7.0, const Color(0xFF7A8A9A));

    // Tower shield
    final shieldPath = Path()
      ..moveTo(cx - 38, baseY - 20)
      ..lineTo(cx - 22, baseY - 22)
      ..lineTo(cx - 22, baseY + 18)
      ..quadraticBezierTo(cx - 30, baseY + 22, cx - 38, baseY + 16)
      ..close();
    canvas.drawPath(
      shieldPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 38, baseY - 20),
          Offset(cx - 22, baseY + 18),
          [const Color(0xFF6A7A8A), const Color(0xFF4A5A6A), const Color(0xFF3A4A5A)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Shield emblem
    canvas.drawCircle(
      Offset(cx - 30, baseY),
      6,
      Paint()..color = const Color(0xFFD4A44C),
    );
    canvas.drawCircle(
      Offset(cx - 30, baseY),
      6,
      Paint()
        ..color = const Color(0xFF8A6A2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // -- Right arm --
    _drawLimb(canvas, Offset(cx + 22, baseY - 8),
        Offset(cx + 26, baseY + 10 + arms[1] * 0.3), 7.0, const Color(0xFF7A8A9A));
    // Gauntlet fist
    canvas.drawCircle(
      Offset(cx + 27, baseY + 12 + arms[1] * 0.3),
      5,
      Paint()..color = const Color(0xFF5A6A7A),
    );

    // -- Head (small relative to body - makes body look bigger) --
    final headY = baseY - 26 + bob;
    // Enclosed helmet
    final helmetPath = Path()
      ..moveTo(cx - 11, headY + 6)
      ..lineTo(cx - 13, headY - 6)
      ..quadraticBezierTo(cx, headY - 14, cx + 13, headY - 6)
      ..lineTo(cx + 11, headY + 6)
      ..lineTo(cx + 6, headY + 10)
      ..lineTo(cx - 6, headY + 10)
      ..close();
    canvas.drawPath(
      helmetPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 13, headY - 14),
          Offset(cx + 13, headY + 10),
          [const Color(0xFFAABBCC), const Color(0xFF7A8A9A)],
        ),
    );
    // Visor
    canvas.drawRect(
      Rect.fromLTWH(cx - 8, headY - 2, 16, 4),
      Paint()..color = const Color(0xFF1A1A2E),
    );
    // Eyes
    canvas.drawCircle(Offset(cx - 3, headY), 1.5, Paint()..color = const Color(0xFFAADDFF));
    canvas.drawCircle(Offset(cx + 3, headY), 1.5, Paint()..color = const Color(0xFFAADDFF));

    // Helmet crest
    canvas.drawLine(
      Offset(cx, headY - 14),
      Offset(cx, headY - 20),
      Paint()
        ..color = const Color(0xFFD4A44C)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  // =========================================================================
  // UNDEAD - Skeletal/zombie, tattered robes, glowing green eyes
  // =========================================================================

  void _drawUndead(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame);
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);

    final cx = s * 0.5;
    final baseY = s * 0.5 + bob;

    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.32, s * 0.06);

    // Ghostly mist at feet
    for (int i = 0; i < 5; i++) {
      final mx = cx + math.sin(frame * 1.2 + i * 1.4) * 18;
      final my = s * 0.88 + math.cos(frame * 0.8 + i) * 3;
      canvas.drawCircle(
        Offset(mx, my),
        6 + i * 1.5,
        Paint()
          ..color = Color.fromARGB(20 + i * 5, 100, 200, 100)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // -- Skeletal legs --
    _drawLimb(canvas, Offset(cx - 6, baseY + 12),
        Offset(cx - 8, baseY + 28 + legs[0]), 3.0, const Color(0xFFAA9977));
    _drawLimb(canvas, Offset(cx + 6, baseY + 12),
        Offset(cx + 8, baseY + 28 + legs[1]), 3.0, const Color(0xFFAA9977));
    // Bony feet
    for (final f in [
      Offset(cx - 8, baseY + 28 + legs[0]),
      Offset(cx + 8, baseY + 28 + legs[1]),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(f.dx, f.dy + 1), width: 7, height: 3),
        Paint()..color = const Color(0xFF998866),
      );
    }

    // -- Tattered robe --
    final robePath = Path()
      ..moveTo(cx - 16, baseY - 12)
      ..lineTo(cx + 16, baseY - 12)
      ..lineTo(cx + 20, baseY + 14)
      // Tattered bottom edge
      ..lineTo(cx + 16, baseY + 18)
      ..lineTo(cx + 12, baseY + 14)
      ..lineTo(cx + 8, baseY + 20)
      ..lineTo(cx + 4, baseY + 15)
      ..lineTo(cx, baseY + 20)
      ..lineTo(cx - 4, baseY + 15)
      ..lineTo(cx - 8, baseY + 20)
      ..lineTo(cx - 12, baseY + 14)
      ..lineTo(cx - 16, baseY + 18)
      ..lineTo(cx - 20, baseY + 14)
      ..close();
    canvas.drawPath(
      robePath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, baseY - 12),
          Offset(cx, baseY + 20),
          [const Color(0xFF4A4A55), const Color(0xFF2A2A33), const Color(0xFF1A1A22)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Robe tears
    canvas.drawLine(
      Offset(cx + 10, baseY - 2),
      Offset(cx + 14, baseY + 10),
      Paint()
        ..color = const Color(0x40000000)
        ..strokeWidth = 1.5,
    );

    // -- Skeletal arms --
    _drawLimb(canvas, Offset(cx - 16, baseY - 6),
        Offset(cx - 22, baseY + 8 + arms[0]), 2.5, const Color(0xFFAA9977));
    _drawLimb(canvas, Offset(cx + 16, baseY - 6),
        Offset(cx + 22, baseY + 8 + arms[1]), 2.5, const Color(0xFFAA9977));
    // Claw-like hands
    for (final hand in [
      Offset(cx - 22, baseY + 8 + arms[0]),
      Offset(cx + 22, baseY + 8 + arms[1]),
    ]) {
      for (int f = -1; f <= 1; f++) {
        canvas.drawLine(
          hand,
          Offset(hand.dx + f * 2.5, hand.dy + 5),
          Paint()
            ..color = const Color(0xFF998866)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // -- Skull head --
    final headY = baseY - 22 + bob;
    // Skull shape
    final skullPath = Path()
      ..moveTo(cx, headY - 12)
      ..cubicTo(cx + 14, headY - 11, cx + 12, headY + 4, cx + 4, headY + 8)
      ..lineTo(cx + 3, headY + 12)
      ..lineTo(cx - 3, headY + 12)
      ..lineTo(cx - 4, headY + 8)
      ..cubicTo(cx - 12, headY + 4, cx - 14, headY - 11, cx, headY - 12)
      ..close();
    canvas.drawPath(
      skullPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 3, headY - 6),
          16,
          [const Color(0xFFDDCCAA), const Color(0xFFAA9977), const Color(0xFF887755)],
          [0.0, 0.5, 1.0],
        ),
    );

    // Eye sockets (dark hollows)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 5, headY - 2), width: 7, height: 6),
      Paint()..color = const Color(0xFF1A1A22),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 5, headY - 2), width: 7, height: 6),
      Paint()..color = const Color(0xFF1A1A22),
    );
    // Glowing green eyes
    _drawGlowingEyes(canvas, Offset(cx - 5, headY - 2), Offset(cx + 5, headY - 2),
        2.5, const Color(0xFF44FF44));

    // Nose hole
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headY + 3), width: 3, height: 4),
      Paint()..color = const Color(0xFF887755),
    );

    // Jaw / teeth
    canvas.drawLine(
      Offset(cx - 5, headY + 8),
      Offset(cx + 5, headY + 8),
      Paint()
        ..color = const Color(0xFF887755)
        ..strokeWidth = 1.5,
    );
    for (double tx = cx - 4; tx <= cx + 4; tx += 2.5) {
      canvas.drawLine(
        Offset(tx, headY + 8),
        Offset(tx, headY + 10),
        Paint()
          ..color = const Color(0xFFCCBB99)
          ..strokeWidth = 1.0,
      );
    }

    // Hood over skull
    final hoodPath = Path()
      ..moveTo(cx - 14, headY + 2)
      ..quadraticBezierTo(cx - 16, headY - 14, cx, headY - 16)
      ..quadraticBezierTo(cx + 16, headY - 14, cx + 14, headY + 2);
    canvas.drawPath(
      hoodPath,
      Paint()
        ..color = const Color(0xAA2A2A33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
  }

  // =========================================================================
  // SHIELD BEARER - Knight with tower shield covering body
  // =========================================================================

  void _drawShieldBearer(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame) * 0.7;
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);

    final cx = s * 0.5;
    final baseY = s * 0.5 + bob;

    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.38, s * 0.07);

    // -- Legs --
    _drawLimb(canvas, Offset(cx - 7, baseY + 14),
        Offset(cx - 10, baseY + 30 + legs[0] * 0.6), 5.5, const Color(0xFF445566));
    _drawLimb(canvas, Offset(cx + 7, baseY + 14),
        Offset(cx + 10, baseY + 30 + legs[1] * 0.6), 5.5, const Color(0xFF445566));
    // Boots
    _drawBoot(canvas, Offset(cx - 10, baseY + 30 + legs[0] * 0.6), const Color(0xFF334455));
    _drawBoot(canvas, Offset(cx + 10, baseY + 30 + legs[1] * 0.6), const Color(0xFF334455));

    // -- Body behind shield (partially visible) --
    final torsoPath = Path()
      ..moveTo(cx - 12, baseY - 10)
      ..lineTo(cx + 14, baseY - 10)
      ..lineTo(cx + 12, baseY + 16)
      ..lineTo(cx - 10, baseY + 16)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 12, baseY - 10),
          Offset(cx + 14, baseY + 16),
          [const Color(0xFF5577AA), const Color(0xFF3A5577)],
        ),
    );

    // -- Right arm (behind shield, sword) --
    _drawLimb(canvas, Offset(cx + 14, baseY - 4),
        Offset(cx + 22, baseY + 6 + arms[1] * 0.4), 5.0, const Color(0xFF5577AA));
    // Sword behind shield
    final sY = baseY + 4 + arms[1] * 0.4 + _weaponBob(frame);
    canvas.drawLine(
      Offset(cx + 23, sY),
      Offset(cx + 26, sY - 24),
      Paint()
        ..color = const Color(0xFFD0D8E0)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // -- TOWER SHIELD (main feature, covers most of body) --
    final shieldPath = Path()
      ..moveTo(cx - 24, baseY - 22)
      ..lineTo(cx + 8, baseY - 22)
      ..lineTo(cx + 8, baseY + 18)
      ..quadraticBezierTo(cx - 8, baseY + 24, cx - 24, baseY + 16)
      ..close();
    canvas.drawPath(
      shieldPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 24, baseY - 22),
          Offset(cx + 8, baseY + 18),
          [
            const Color(0xFF6699CC),
            const Color(0xFF4477AA),
            const Color(0xFF335588),
            const Color(0xFF224466),
          ],
          [0.0, 0.3, 0.7, 1.0],
        ),
    );
    // Shield border
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = const Color(0xFFD4A44C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Shield cross emblem
    canvas.drawLine(
      Offset(cx - 8, baseY - 14),
      Offset(cx - 8, baseY + 10),
      Paint()
        ..color = const Color(0xFFD4A44C)
        ..strokeWidth = 3.0,
    );
    canvas.drawLine(
      Offset(cx - 18, baseY - 2),
      Offset(cx + 2, baseY - 2),
      Paint()
        ..color = const Color(0xFFD4A44C)
        ..strokeWidth = 3.0,
    );
    // Shield highlight
    canvas.drawRect(
      Rect.fromLTWH(cx - 22, baseY - 20, 6, 14),
      Paint()..color = const Color(0x25FFFFFF),
    );

    // -- Head (peeking above shield) --
    final headY = baseY - 30 + bob;
    _drawHumanHead(canvas, Offset(cx - 6, headY), 9.0,
        const Color(0xFFDEB896), const Color(0xFFC49A78));
    // Helmet
    final hPath = Path()
      ..moveTo(cx - 16, headY + 2)
      ..quadraticBezierTo(cx - 17, headY - 10, cx - 6, headY - 13)
      ..quadraticBezierTo(cx + 5, headY - 10, cx + 4, headY + 2)
      ..close();
    canvas.drawPath(hPath, Paint()..color = const Color(0xFF5577AA));
    // Eyes peeking
    canvas.drawCircle(Offset(cx - 9, headY - 1), 1.8, Paint()..color = const Color(0xFFFFFFDD));
    canvas.drawCircle(Offset(cx - 3, headY - 1), 1.8, Paint()..color = const Color(0xFFFFFFDD));
  }

  // =========================================================================
  // HEALER - Robed figure with staff and green healing aura
  // =========================================================================

  void _drawHealer(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame);
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);
    final wBob = _weaponBob(frame);

    final cx = s * 0.5;
    final baseY = s * 0.5 + bob;

    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.32, s * 0.06);

    // Healing aura
    final pulse = (math.sin(frame * math.pi / 2) * 0.5 + 0.5);
    canvas.drawCircle(
      Offset(cx, baseY),
      32 + pulse * 6,
      Paint()
        ..color = Color.fromARGB((18 + (pulse * 14).round()).clamp(0, 255), 80, 220, 160)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // -- Feet visible under robe --
    _drawBoot(canvas, Offset(cx - 6, baseY + 28 + legs[0] * 0.5), const Color(0xFF5A4A3A));
    _drawBoot(canvas, Offset(cx + 6, baseY + 28 + legs[1] * 0.5), const Color(0xFF5A4A3A));

    // -- Long robe --
    final robePath = Path()
      ..moveTo(cx - 14, baseY - 14)
      ..quadraticBezierTo(cx - 18, baseY + 4, cx - 16, baseY + 26)
      ..lineTo(cx + 16, baseY + 26)
      ..quadraticBezierTo(cx + 18, baseY + 4, cx + 14, baseY - 14)
      ..close();
    canvas.drawPath(
      robePath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 14, baseY - 14),
          Offset(cx + 14, baseY + 26),
          [const Color(0xFFEEEEDD), const Color(0xFFCCCCBB), const Color(0xFFAAAA99)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Robe trim (green)
    canvas.drawLine(
      Offset(cx - 16, baseY + 26),
      Offset(cx + 16, baseY + 26),
      Paint()
        ..color = const Color(0xFF44CCAA)
        ..strokeWidth = 3.0,
    );
    // Center robe line
    canvas.drawLine(
      Offset(cx, baseY - 10),
      Offset(cx, baseY + 24),
      Paint()
        ..color = const Color(0x30000000)
        ..strokeWidth = 1.0,
    );
    // Belt/sash
    canvas.drawRect(
      Rect.fromLTWH(cx - 14, baseY + 4, 28, 4),
      Paint()..color = const Color(0xFF44CCAA),
    );

    // -- Left arm --
    _drawLimb(canvas, Offset(cx - 14, baseY - 8),
        Offset(cx - 20, baseY + 6 + arms[0]), 4.5, const Color(0xFFDDDDCC));

    // -- Right arm (holding staff) --
    _drawLimb(canvas, Offset(cx + 14, baseY - 8),
        Offset(cx + 18, baseY + 4 + arms[1]), 4.5, const Color(0xFFDDDDCC));

    // Staff
    final staffX = cx + 22.0;
    final staffTopY = baseY - 38 + wBob;
    final staffBottomY = baseY + 26.0;
    canvas.drawLine(
      Offset(staffX, staffTopY),
      Offset(staffX, staffBottomY),
      Paint()
        ..color = const Color(0xFF8B7355)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    // Staff crystal
    canvas.drawCircle(
      Offset(staffX, staffTopY),
      5,
      Paint()
        ..color = const Color(0xFF44FFAA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      Offset(staffX, staffTopY),
      3.5,
      Paint()..color = const Color(0xFF88FFCC),
    );
    canvas.drawCircle(
      Offset(staffX, staffTopY),
      1.5,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Healing particles
    for (int i = 0; i < 4; i++) {
      final angle = frame * math.pi / 2 + i * math.pi / 2;
      final dist = 12.0 + pulse * 4;
      canvas.drawCircle(
        Offset(staffX + dist * math.cos(angle), staffTopY + dist * math.sin(angle)),
        1.5 + pulse,
        Paint()..color = Color.fromARGB((120 + (pulse * 80).round()).clamp(0, 255), 80, 255, 180),
      );
    }

    // -- Head --
    final headY = baseY - 24 + bob;
    _drawHumanHead(canvas, Offset(cx, headY), 10.0,
        const Color(0xFFDEB896), const Color(0xFFC49A78));
    // Hood
    final hoodPath = Path()
      ..moveTo(cx - 14, headY + 4)
      ..quadraticBezierTo(cx - 16, headY - 12, cx, headY - 16)
      ..quadraticBezierTo(cx + 16, headY - 12, cx + 14, headY + 4);
    canvas.drawPath(
      hoodPath,
      Paint()
        ..color = const Color(0xFFDDDDCC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round,
    );
    // Kind eyes
    canvas.drawCircle(Offset(cx - 4, headY - 1), 1.8, Paint()..color = const Color(0xFF44AA88));
    canvas.drawCircle(Offset(cx + 4, headY - 1), 1.8, Paint()..color = const Color(0xFF44AA88));
  }

  // =========================================================================
  // BURROWER - Mole/worm creature partially underground
  // =========================================================================

  void _drawBurrower(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame);
    final legs = _legPhase(frame);

    final cx = s * 0.5;
    final baseY = s * 0.62 + bob; // lower - partially underground

    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.42, s * 0.08);

    // Dirt mound (ground line)
    final dirtPath = Path()
      ..moveTo(cx - 40, s * 0.88)
      ..quadraticBezierTo(cx - 20, s * 0.72, cx, s * 0.74)
      ..quadraticBezierTo(cx + 20, s * 0.72, cx + 40, s * 0.88)
      ..lineTo(cx + 40, s * 0.95)
      ..lineTo(cx - 40, s * 0.95)
      ..close();
    canvas.drawPath(
      dirtPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, s * 0.72),
          Offset(cx, s * 0.95),
          [const Color(0xFF6B5533), const Color(0xFF4A3A22), const Color(0xFF3A2A18)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Dirt chunks
    for (int i = 0; i < 6; i++) {
      final dx = cx + math.sin(frame * 1.5 + i * 2) * 24 - 12;
      final dy = s * 0.76 + math.cos(i * 1.8) * 6;
      canvas.drawCircle(
        Offset(dx, dy),
        2.5 + i * 0.3,
        Paint()..color = const Color(0xFF5A4A2A),
      );
    }

    // -- Body (worm/mole, emerging from ground) --
    final bodyPath = Path()
      ..moveTo(cx - 20, baseY + 10)
      ..cubicTo(cx - 24, baseY - 8, cx - 12, baseY - 24, cx, baseY - 26)
      ..cubicTo(cx + 12, baseY - 24, cx + 24, baseY - 8, cx + 20, baseY + 10)
      ..close();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 4, baseY - 14),
          28,
          [const Color(0xFFAA8855), const Color(0xFF886644), const Color(0xFF664422)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Segmented body lines
    for (double y = baseY - 18; y < baseY + 6; y += 6) {
      canvas.drawLine(
        Offset(cx - 16, y),
        Offset(cx + 16, y),
        Paint()
          ..color = const Color(0x30000000)
          ..strokeWidth = 1.0,
      );
    }

    // -- Claws (visible, digging) --
    // Left claw
    final lcX = cx - 18.0;
    final lcY = baseY - 6 + legs[0] * 0.4;
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(lcX, lcY),
        Offset(lcX - 10, lcY + 4 + i * 5),
        Paint()
          ..color = const Color(0xFF553322)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
    // Right claw
    final rcX = cx + 18.0;
    final rcY = baseY - 6 + legs[1] * 0.4;
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(rcX, rcY),
        Offset(rcX + 10, rcY + 4 + i * 5),
        Paint()
          ..color = const Color(0xFF553322)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // -- Head (mole face) --
    final headY = baseY - 28 + bob;
    final headPath = Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, headY), width: 24, height: 20));
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 3, headY - 4),
          14,
          [const Color(0xFFBB9966), const Color(0xFF886644)],
        ),
    );
    // Snout
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headY + 4), width: 10, height: 7),
      Paint()..color = const Color(0xFFCC8855),
    );
    // Nose
    canvas.drawCircle(
      Offset(cx, headY + 3),
      3,
      Paint()..color = const Color(0xFF553333),
    );
    // Tiny eyes
    canvas.drawCircle(Offset(cx - 6, headY - 3), 2.0, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(Offset(cx + 6, headY - 3), 2.0, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(Offset(cx - 6, headY - 3.5), 0.8, Paint()..color = const Color(0x88FFFFFF));
    canvas.drawCircle(Offset(cx + 6, headY - 3.5), 0.8, Paint()..color = const Color(0x88FFFFFF));
  }

  // =========================================================================
  // TROLL - Large muscular green creature with club
  // =========================================================================

  void _drawTroll(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame) * 0.6;
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);
    final wBob = _weaponBob(frame);

    final cx = s * 0.5;
    final baseY = s * 0.46 + bob;

    _drawGroundShadow(canvas, cx, s * 0.94, s * 0.42, s * 0.09);

    // -- Thick legs --
    _drawLimb(canvas, Offset(cx - 12, baseY + 18),
        Offset(cx - 16, baseY + 36 + legs[0] * 0.5), 9.0, const Color(0xFF2A7733));
    _drawLimb(canvas, Offset(cx + 12, baseY + 18),
        Offset(cx + 16, baseY + 36 + legs[1] * 0.5), 9.0, const Color(0xFF2A7733));
    // Big feet
    for (final f in [
      Offset(cx - 16, baseY + 36 + legs[0] * 0.5),
      Offset(cx + 16, baseY + 36 + legs[1] * 0.5),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(f.dx, f.dy + 3), width: 16, height: 7),
        Paint()..color = const Color(0xFF1A5522),
      );
    }

    // -- Massive torso --
    final torsoPath = Path()
      ..moveTo(cx - 24, baseY - 14)
      ..quadraticBezierTo(cx - 28, baseY + 4, cx - 22, baseY + 20)
      ..lineTo(cx + 22, baseY + 20)
      ..quadraticBezierTo(cx + 28, baseY + 4, cx + 24, baseY - 14)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 6, baseY - 6),
          34,
          [const Color(0xFF44AA44), const Color(0xFF2A7733), const Color(0xFF1A5522)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Belly
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY + 6), width: 28, height: 20),
      Paint()..color = const Color(0xFF3A9938),
    );
    // Loincloth
    final clothPath = Path()
      ..moveTo(cx - 16, baseY + 14)
      ..lineTo(cx + 16, baseY + 14)
      ..lineTo(cx + 10, baseY + 26)
      ..lineTo(cx - 10, baseY + 26)
      ..close();
    canvas.drawPath(clothPath, Paint()..color = const Color(0xFF6B4226));

    // -- Left arm --
    _drawLimb(canvas, Offset(cx - 24, baseY - 8),
        Offset(cx - 30, baseY + 14 + arms[0]), 8.0, const Color(0xFF2A7733));
    // Fist
    canvas.drawCircle(
      Offset(cx - 31, baseY + 16 + arms[0]),
      5,
      Paint()..color = const Color(0xFF1A5522),
    );

    // -- Right arm (club) --
    _drawLimb(canvas, Offset(cx + 24, baseY - 8),
        Offset(cx + 28, baseY + 10 + arms[1]), 8.0, const Color(0xFF2A7733));

    // Club
    final clubBaseX = cx + 30;
    final clubBaseY = baseY + 10 + arms[1] + wBob;
    // Handle
    canvas.drawLine(
      Offset(clubBaseX, clubBaseY),
      Offset(clubBaseX + 6, clubBaseY - 28),
      Paint()
        ..color = const Color(0xFF6B4A22)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    // Club head
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(clubBaseX + 7, clubBaseY - 32),
        width: 16,
        height: 12,
      ),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(clubBaseX + 5, clubBaseY - 34),
          10,
          [const Color(0xFF8B6B3A), const Color(0xFF5A4422)],
        ),
    );
    // Club spikes
    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 4 + i * math.pi / 3;
      canvas.drawLine(
        Offset(clubBaseX + 7, clubBaseY - 32),
        Offset(
          clubBaseX + 7 + 10 * math.cos(angle),
          clubBaseY - 32 + 10 * math.sin(angle),
        ),
        Paint()
          ..color = const Color(0xFF8A8A8A)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // -- Head (small relative to body) --
    final headY = baseY - 26 + bob;
    final headPath = Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, headY), width: 28, height: 24));
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 4, headY - 4),
          16,
          [const Color(0xFF44AA44), const Color(0xFF2A7733)],
        ),
    );
    // Heavy brow
    canvas.drawLine(
      Offset(cx - 12, headY - 4),
      Offset(cx + 12, headY - 4),
      Paint()
        ..color = const Color(0xFF1A5522)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
    // Angry eyes under brow
    canvas.drawCircle(Offset(cx - 5, headY - 1), 2.5, Paint()..color = const Color(0xFFFF3300));
    canvas.drawCircle(Offset(cx + 5, headY - 1), 2.5, Paint()..color = const Color(0xFFFF3300));
    canvas.drawCircle(Offset(cx - 5, headY - 1), 1.0, Paint()..color = const Color(0xFF000000));
    canvas.drawCircle(Offset(cx + 5, headY - 1), 1.0, Paint()..color = const Color(0xFF000000));

    // Underbite with tusks
    canvas.drawLine(
      Offset(cx - 8, headY + 6),
      Offset(cx + 8, headY + 6),
      Paint()
        ..color = const Color(0xFF1A3A18)
        ..strokeWidth = 2.5,
    );
    // Tusks
    canvas.drawLine(
      Offset(cx - 6, headY + 6),
      Offset(cx - 5, headY + 1),
      Paint()
        ..color = const Color(0xFFDDDDAA)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 6, headY + 6),
      Offset(cx + 5, headY + 1),
      Paint()
        ..color = const Color(0xFFDDDDAA)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  // =========================================================================
  // DARK KNIGHT - Ominous knight in black armor, purple energy sword
  // =========================================================================

  void _drawDarkKnight(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame);
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);
    final wBob = _weaponBob(frame);
    final pulse = (math.sin(frame * math.pi / 2) * 0.5 + 0.5);

    final cx = s * 0.5;
    final baseY = s * 0.5 + bob;

    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.36, s * 0.07);

    // Purple energy aura
    canvas.drawCircle(
      Offset(cx, baseY),
      36 + pulse * 4,
      Paint()
        ..color = Color.fromARGB((14 + (pulse * 10).round()).clamp(0, 255), 140, 40, 200)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // -- Legs (dark armored) --
    _drawLimb(canvas, Offset(cx - 8, baseY + 14),
        Offset(cx - 10, baseY + 30 + legs[0]), 6.0, const Color(0xFF222233));
    _drawLimb(canvas, Offset(cx + 8, baseY + 14),
        Offset(cx + 10, baseY + 30 + legs[1]), 6.0, const Color(0xFF222233));
    _drawBoot(canvas, Offset(cx - 10, baseY + 30 + legs[0]), const Color(0xFF111122));
    _drawBoot(canvas, Offset(cx + 10, baseY + 30 + legs[1]), const Color(0xFF111122));

    // -- Dark armor torso --
    final torsoPath = Path()
      ..moveTo(cx - 16, baseY - 12)
      ..lineTo(cx + 16, baseY - 12)
      ..lineTo(cx + 14, baseY + 16)
      ..lineTo(cx - 14, baseY + 16)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 16, baseY - 12),
          Offset(cx + 16, baseY + 16),
          [const Color(0xFF2A2A3A), const Color(0xFF1A1A2A), const Color(0xFF0A0A1A)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Purple rune on chest
    canvas.drawCircle(
      Offset(cx, baseY),
      6,
      Paint()
        ..color = Color.fromARGB((80 + (pulse * 60).round()).clamp(0, 255), 160, 60, 220)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      Offset(cx, baseY),
      3,
      Paint()..color = const Color(0xFFCC66FF),
    );

    // Spiked pauldrons
    _drawDarkPauldron(canvas, Offset(cx - 18, baseY - 14 + bob), false);
    _drawDarkPauldron(canvas, Offset(cx + 18, baseY - 14 + bob), true);

    // -- Left arm --
    _drawLimb(canvas, Offset(cx - 16, baseY - 6),
        Offset(cx - 22, baseY + 8 + arms[0]), 5.5, const Color(0xFF222233));

    // -- Right arm (energy sword) --
    _drawLimb(canvas, Offset(cx + 16, baseY - 6),
        Offset(cx + 20, baseY + 4 + arms[1]), 5.5, const Color(0xFF222233));

    // Purple energy sword
    final swordX = cx + 22;
    final swordY = baseY + 2 + arms[1] + wBob;
    // Blade glow
    canvas.drawLine(
      Offset(swordX, swordY),
      Offset(swordX + 4, swordY - 30),
      Paint()
        ..color = Color.fromARGB((60 + (pulse * 40).round()).clamp(0, 255), 180, 80, 255)
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Blade core
    canvas.drawLine(
      Offset(swordX, swordY),
      Offset(swordX + 4, swordY - 30),
      Paint()
        ..color = const Color(0xFFDD88FF)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    // Blade bright center
    canvas.drawLine(
      Offset(swordX + 0.5, swordY - 2),
      Offset(swordX + 3.5, swordY - 28),
      Paint()
        ..color = const Color(0xFFFFDDFF)
        ..strokeWidth = 1.2,
    );
    // Guard
    canvas.drawLine(
      Offset(swordX - 6, swordY + 2),
      Offset(swordX + 6, swordY),
      Paint()
        ..color = const Color(0xFF3A3A4A)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // -- Head (dark helmet with glowing eyes) --
    final headY = baseY - 22 + bob;
    final helmetPath = Path()
      ..moveTo(cx - 13, headY + 6)
      ..lineTo(cx - 14, headY - 4)
      ..quadraticBezierTo(cx, headY - 16, cx + 14, headY - 4)
      ..lineTo(cx + 13, headY + 6)
      ..lineTo(cx + 4, headY + 10)
      ..quadraticBezierTo(cx, headY + 12, cx - 4, headY + 10)
      ..close();
    canvas.drawPath(
      helmetPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 14, headY - 16),
          Offset(cx + 14, headY + 10),
          [const Color(0xFF2A2A3A), const Color(0xFF1A1A2A), const Color(0xFF0A0A1A)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Visor slit
    canvas.drawLine(
      Offset(cx - 8, headY),
      Offset(cx + 8, headY),
      Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 3.0,
    );
    // Glowing purple eyes
    _drawGlowingEyes(canvas, Offset(cx - 4, headY), Offset(cx + 4, headY),
        2.5, const Color(0xFFCC44FF));

    // Helmet horns
    canvas.drawLine(
      Offset(cx - 10, headY - 6),
      Offset(cx - 16, headY - 18),
      Paint()
        ..color = const Color(0xFF2A2A3A)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 10, headY - 6),
      Offset(cx + 16, headY - 18),
      Paint()
        ..color = const Color(0xFF2A2A3A)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Cape
    final capePath = Path()
      ..moveTo(cx - 12, baseY - 10)
      ..quadraticBezierTo(cx - 18, baseY + 10, cx - 14, baseY + 28 + legs[0] * 0.3)
      ..lineTo(cx + 14, baseY + 28 + legs[1] * 0.3)
      ..quadraticBezierTo(cx + 18, baseY + 10, cx + 12, baseY - 10)
      ..close();
    canvas.drawPath(
      capePath,
      Paint()..color = const Color(0x602A1A3A),
    );
  }

  // =========================================================================
  // SHADOW LORD (BOSS) - Floating dark entity with wings/cape, purple energy
  // =========================================================================

  void _drawShadowLord(Canvas canvas, int frame) {
    const s = 128.0;
    final pulse = (math.sin(frame * math.pi / 2) * 0.5 + 0.5);
    final float = math.sin(frame * math.pi / 2) * 4; // floating motion

    final cx = s * 0.5;
    final baseY = s * 0.46 + float;

    _drawGroundShadow(canvas, cx, s * 0.92, s * 0.40, s * 0.06);

    // Boss aura - multiple layers
    canvas.drawCircle(
      Offset(cx, baseY),
      50 + pulse * 6,
      Paint()
        ..color = Color.fromARGB((12 + (pulse * 8).round()).clamp(0, 255), 100, 0, 160)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(
      Offset(cx, baseY),
      40 + pulse * 4,
      Paint()
        ..color = Color.fromARGB((18 + (pulse * 12).round()).clamp(0, 255), 120, 20, 180)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Shadow tendrils
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 + frame * 0.4;
      final len = 30 + math.sin(frame * math.pi / 2 + i) * 10;
      final tendrilPath = Path()
        ..moveTo(cx, baseY + 10)
        ..quadraticBezierTo(
          cx + len * 0.5 * math.cos(angle + 0.3),
          baseY + 10 + len * 0.5 * math.sin(angle + 0.3),
          cx + len * math.cos(angle),
          baseY + 10 + len * math.sin(angle),
        );
      canvas.drawPath(
        tendrilPath,
        Paint()
          ..color = Color.fromARGB((40 + (pulse * 30).round()).clamp(0, 255), 80, 0, 120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // -- Wings/cape spread --
    final wingL = Path()
      ..moveTo(cx - 10, baseY - 10)
      ..cubicTo(cx - 40, baseY - 28, cx - 48, baseY - 6, cx - 42, baseY + 16)
      ..cubicTo(cx - 36, baseY + 24, cx - 20, baseY + 16, cx - 12, baseY + 10)
      ..close();
    canvas.drawPath(
      wingL,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 10, baseY - 10),
          Offset(cx - 48, baseY + 16),
          [const Color(0xCC2A1A3A), const Color(0xAA1A0A2A), const Color(0x880A0018)],
          [0.0, 0.5, 1.0],
        ),
    );
    final wingR = Path()
      ..moveTo(cx + 10, baseY - 10)
      ..cubicTo(cx + 40, baseY - 28, cx + 48, baseY - 6, cx + 42, baseY + 16)
      ..cubicTo(cx + 36, baseY + 24, cx + 20, baseY + 16, cx + 12, baseY + 10)
      ..close();
    canvas.drawPath(
      wingR,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx + 10, baseY - 10),
          Offset(cx + 48, baseY + 16),
          [const Color(0xCC2A1A3A), const Color(0xAA1A0A2A), const Color(0x880A0018)],
          [0.0, 0.5, 1.0],
        ),
    );

    // -- Body (robed, floating) --
    final bodyPath = Path()
      ..moveTo(cx - 16, baseY - 12)
      ..lineTo(cx + 16, baseY - 12)
      ..lineTo(cx + 20, baseY + 20)
      // Tattered bottom
      ..lineTo(cx + 14, baseY + 26)
      ..lineTo(cx + 8, baseY + 20)
      ..lineTo(cx + 2, baseY + 28)
      ..lineTo(cx - 2, baseY + 22)
      ..lineTo(cx - 8, baseY + 28)
      ..lineTo(cx - 14, baseY + 22)
      ..lineTo(cx - 20, baseY + 20)
      ..close();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, baseY - 12),
          Offset(cx, baseY + 28),
          [const Color(0xFF2A1A3A), const Color(0xFF1A0A2A), const Color(0xFF0A0018)],
          [0.0, 0.5, 1.0],
        ),
    );

    // Purple energy rune on chest
    canvas.drawCircle(
      Offset(cx, baseY + 2),
      8,
      Paint()
        ..color = Color.fromARGB((60 + (pulse * 50).round()).clamp(0, 255), 160, 60, 220)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Rune symbol (star)
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawLine(
        Offset(cx, baseY + 2),
        Offset(cx + 5 * math.cos(angle), baseY + 2 + 5 * math.sin(angle)),
        Paint()
          ..color = const Color(0xCCCC66FF)
          ..strokeWidth = 1.0,
      );
    }

    // -- Skeletal hands reaching out --
    final la = _armPhase(frame);
    // Left arm
    _drawLimb(canvas, Offset(cx - 16, baseY - 4),
        Offset(cx - 26, baseY + 8 + la[0]), 3.5, const Color(0xFF3A2A4A));
    // Claw fingers
    for (int f = -1; f <= 1; f++) {
      canvas.drawLine(
        Offset(cx - 26, baseY + 8 + la[0]),
        Offset(cx - 30 + f * 2, baseY + 14 + la[0]),
        Paint()
          ..color = const Color(0xFF887766)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
    // Right arm
    _drawLimb(canvas, Offset(cx + 16, baseY - 4),
        Offset(cx + 26, baseY + 8 + la[1]), 3.5, const Color(0xFF3A2A4A));
    for (int f = -1; f <= 1; f++) {
      canvas.drawLine(
        Offset(cx + 26, baseY + 8 + la[1]),
        Offset(cx + 30 + f * 2, baseY + 14 + la[1]),
        Paint()
          ..color = const Color(0xFF887766)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // -- Head --
    final headY = baseY - 22;
    // Dark hood
    final hoodPath = Path()
      ..moveTo(cx - 16, headY + 8)
      ..quadraticBezierTo(cx - 20, headY - 10, cx, headY - 16)
      ..quadraticBezierTo(cx + 20, headY - 10, cx + 16, headY + 8)
      ..close();
    canvas.drawPath(
      hoodPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, headY - 16),
          Offset(cx, headY + 8),
          [const Color(0xFF2A1A3A), const Color(0xFF0A0018)],
        ),
    );
    // Skull face in shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headY + 2), width: 16, height: 12),
      Paint()..color = const Color(0xFF1A1A22),
    );
    // Glowing red eyes
    _drawGlowingEyes(canvas, Offset(cx - 4, headY), Offset(cx + 4, headY),
        3.0, const Color(0xFFFF0044));

    // Crown
    _drawBossCrown(canvas, Offset(cx, headY - 14), pulse, const Color(0xFFAA44DD));

    // Boss border glow
    canvas.drawCircle(
      Offset(cx, baseY),
      42,
      Paint()
        ..color = Color.fromARGB((25 + (pulse * 20).round()).clamp(0, 255), 180, 80, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // =========================================================================
  // DRAGON EMPEROR (BOSS) - Dragon-humanoid in golden armor, fire, massive
  // =========================================================================

  void _drawDragonEmperor(Canvas canvas, int frame) {
    const s = 128.0;
    final bob = _bodyBob(frame) * 0.4;
    final legs = _legPhase(frame);
    final arms = _armPhase(frame);
    final pulse = (math.sin(frame * math.pi / 2) * 0.5 + 0.5);

    final cx = s * 0.5;
    final baseY = s * 0.46 + bob;

    _drawGroundShadow(canvas, cx, s * 0.94, s * 0.48, s * 0.10);

    // Boss aura - gold/red glow
    canvas.drawCircle(
      Offset(cx, baseY),
      52 + pulse * 6,
      Paint()
        ..color = Color.fromARGB((14 + (pulse * 10).round()).clamp(0, 255), 220, 140, 0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(
      Offset(cx, baseY),
      44 + pulse * 4,
      Paint()
        ..color = Color.fromARGB((18 + (pulse * 14).round()).clamp(0, 255), 255, 80, 0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Fire particles orbiting
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + frame * math.pi / 6;
      final dist = 42 + math.sin(frame * math.pi / 2 + i) * 6;
      final px = cx + dist * math.cos(angle);
      final py = baseY + dist * math.sin(angle);
      canvas.drawCircle(
        Offset(px, py),
        2.5 + pulse * 1.5,
        Paint()
          ..color = Color.fromARGB(
            (180 + (pulse * 60).round()).clamp(0, 255),
            255,
            (100 + i * 15).clamp(0, 255),
            0,
          ),
      );
    }

    // -- Dragon wings --
    final wAngle = pulse * 0.15;
    final wingLP = Path()
      ..moveTo(cx - 14, baseY - 14)
      ..cubicTo(
        cx - 44 - wAngle * 20, baseY - 36,
        cx - 52, baseY - 10,
        cx - 44, baseY + 12,
      )
      ..cubicTo(cx - 36, baseY + 18, cx - 22, baseY + 6, cx - 14, baseY - 2)
      ..close();
    canvas.drawPath(
      wingLP,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 14, baseY - 14),
          Offset(cx - 52, baseY + 12),
          [const Color(0xDD8B2500), const Color(0xCC5A1800), const Color(0xAA3A1000)],
          [0.0, 0.5, 1.0],
        ),
    );
    // Wing membrane lines
    for (int i = 0; i < 3; i++) {
      final startX = cx - 14.0;
      final startY = baseY - 12.0 + i * 6;
      canvas.drawLine(
        Offset(startX, startY),
        Offset(cx - 40 - i * 3, baseY - 20 + i * 14),
        Paint()
          ..color = const Color(0x60000000)
          ..strokeWidth = 1.0,
      );
    }

    final wingRP = Path()
      ..moveTo(cx + 14, baseY - 14)
      ..cubicTo(
        cx + 44 + wAngle * 20, baseY - 36,
        cx + 52, baseY - 10,
        cx + 44, baseY + 12,
      )
      ..cubicTo(cx + 36, baseY + 18, cx + 22, baseY + 6, cx + 14, baseY - 2)
      ..close();
    canvas.drawPath(
      wingRP,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx + 14, baseY - 14),
          Offset(cx + 52, baseY + 12),
          [const Color(0xDD8B2500), const Color(0xCC5A1800), const Color(0xAA3A1000)],
          [0.0, 0.5, 1.0],
        ),
    );
    for (int i = 0; i < 3; i++) {
      final startX = cx + 14.0;
      final startY = baseY - 12.0 + i * 6;
      canvas.drawLine(
        Offset(startX, startY),
        Offset(cx + 40 + i * 3, baseY - 20 + i * 14),
        Paint()
          ..color = const Color(0x60000000)
          ..strokeWidth = 1.0,
      );
    }

    // -- Massive legs (dragon/armored) --
    _drawLimb(canvas, Offset(cx - 12, baseY + 18),
        Offset(cx - 16, baseY + 36 + legs[0] * 0.4), 8.0, const Color(0xFFA07030));
    _drawLimb(canvas, Offset(cx + 12, baseY + 18),
        Offset(cx + 16, baseY + 36 + legs[1] * 0.4), 8.0, const Color(0xFFA07030));
    // Clawed feet
    for (final f in [
      Offset(cx - 16, baseY + 36 + legs[0] * 0.4),
      Offset(cx + 16, baseY + 36 + legs[1] * 0.4),
    ]) {
      for (int c = -1; c <= 1; c++) {
        canvas.drawLine(
          f,
          Offset(f.dx + c * 4, f.dy + 5),
          Paint()
            ..color = const Color(0xFF3A2A1A)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // -- Golden armor torso --
    final torsoPath = Path()
      ..moveTo(cx - 20, baseY - 16)
      ..lineTo(cx + 20, baseY - 16)
      ..lineTo(cx + 18, baseY + 20)
      ..lineTo(cx - 18, baseY + 20)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx - 20, baseY - 16),
          Offset(cx + 20, baseY + 20),
          [
            const Color(0xFFE8C84C),
            const Color(0xFFD4A44C),
            const Color(0xFFB8862C),
            const Color(0xFF8A6820),
          ],
          [0.0, 0.3, 0.7, 1.0],
        ),
    );
    // Armor detail lines
    canvas.drawLine(
      Offset(cx, baseY - 14),
      Offset(cx, baseY + 18),
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..strokeWidth = 1.2,
    );
    // Fire emblem on chest
    canvas.drawCircle(
      Offset(cx, baseY),
      7,
      Paint()
        ..color = Color.fromARGB((80 + (pulse * 60).round()).clamp(0, 255), 255, 100, 0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      Offset(cx, baseY),
      4,
      Paint()..color = const Color(0xFFFF6600),
    );

    // Golden pauldrons
    _drawLargePauldron(canvas, Offset(cx - 22, baseY - 18 + bob), false,
        color: const Color(0xFFE8C84C));
    _drawLargePauldron(canvas, Offset(cx + 22, baseY - 18 + bob), true,
        color: const Color(0xFFE8C84C));

    // -- Arms --
    _drawLimb(canvas, Offset(cx - 20, baseY - 8),
        Offset(cx - 28, baseY + 10 + arms[0] * 0.4), 7.0, const Color(0xFFD4A44C));
    _drawLimb(canvas, Offset(cx + 20, baseY - 8),
        Offset(cx + 28, baseY + 10 + arms[1] * 0.4), 7.0, const Color(0xFFD4A44C));

    // Clawed hands
    for (final hand in [
      Offset(cx - 28, baseY + 12 + arms[0] * 0.4),
      Offset(cx + 28, baseY + 12 + arms[1] * 0.4),
    ]) {
      for (int c = -1; c <= 1; c++) {
        canvas.drawLine(
          hand,
          Offset(hand.dx + c * 3, hand.dy + 5),
          Paint()
            ..color = const Color(0xFF3A2A1A)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // -- Fire breath (from mouth area) --
    if (frame == 0 || frame == 2) {
      final fireBaseX = cx;
      final fireBaseY = baseY - 24;
      for (int i = 0; i < 5; i++) {
        final fx = fireBaseX + math.sin(i * 1.2) * (4 + i * 2);
        final fy = fireBaseY - 6 - i * 4;
        canvas.drawCircle(
          Offset(fx, fy),
          4.0 - i * 0.5,
          Paint()
            ..color = Color.fromARGB(
              (180 - i * 30).clamp(0, 255),
              255,
              (200 - i * 40).clamp(0, 255),
              0,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // -- Dragon head --
    final headY = baseY - 28 + bob;
    // Dragon skull shape
    final headPath = Path()
      ..moveTo(cx, headY - 14)
      ..cubicTo(cx + 16, headY - 12, cx + 14, headY + 6, cx + 6, headY + 10)
      ..lineTo(cx + 4, headY + 14) // snout
      ..lineTo(cx - 4, headY + 14)
      ..lineTo(cx - 6, headY + 10)
      ..cubicTo(cx - 14, headY + 6, cx - 16, headY - 12, cx, headY - 14)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx - 3, headY - 6),
          18,
          [const Color(0xFFC85020), const Color(0xFF8B3218), const Color(0xFF5A2010)],
          [0.0, 0.5, 1.0],
        ),
    );

    // Horns
    canvas.drawLine(
      Offset(cx - 10, headY - 8),
      Offset(cx - 20, headY - 22),
      Paint()
        ..color = const Color(0xFF4A3A2A)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 10, headY - 8),
      Offset(cx + 20, headY - 22),
      Paint()
        ..color = const Color(0xFF4A3A2A)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Dragon eyes (golden, slit pupils)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 5, headY), width: 6, height: 5),
      Paint()..color = const Color(0xFFFFCC00),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 5, headY), width: 6, height: 5),
      Paint()..color = const Color(0xFFFFCC00),
    );
    // Slit pupils
    canvas.drawLine(
      Offset(cx - 5, headY - 2),
      Offset(cx - 5, headY + 2),
      Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(cx + 5, headY - 2),
      Offset(cx + 5, headY + 2),
      Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 1.5,
    );
    // Eye glow
    for (final eyePos in [Offset(cx - 5, headY), Offset(cx + 5, headY)]) {
      canvas.drawCircle(
        eyePos,
        5,
        Paint()
          ..color = const Color(0x40FFCC00)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Nostrils
    canvas.drawCircle(Offset(cx - 2, headY + 8), 1.5, Paint()..color = const Color(0xFF3A1A0A));
    canvas.drawCircle(Offset(cx + 2, headY + 8), 1.5, Paint()..color = const Color(0xFF3A1A0A));

    // Teeth
    for (double tx = cx - 4; tx <= cx + 4; tx += 2) {
      canvas.drawLine(
        Offset(tx, headY + 11),
        Offset(tx, headY + 14),
        Paint()
          ..color = const Color(0xFFEEDDCC)
          ..strokeWidth = 1.2,
      );
    }

    // Crown
    _drawBossCrown(canvas, Offset(cx, headY - 16), pulse, const Color(0xFFFFD700));

    // Boss border glow (gold)
    canvas.drawCircle(
      Offset(cx, baseY),
      46,
      Paint()
        ..color = Color.fromARGB((20 + (pulse * 18).round()).clamp(0, 255), 255, 215, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Tail
    final tailPath = Path()
      ..moveTo(cx + 16, baseY + 14)
      ..quadraticBezierTo(
        cx + 32, baseY + 20 + legs[0] * 0.3,
        cx + 38, baseY + 30,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = const Color(0xFF8B3218)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round,
    );
    // Tail tip
    canvas.drawCircle(
      Offset(cx + 38, baseY + 31),
      3,
      Paint()..color = const Color(0xFF5A2010),
    );
  }

  // =========================================================================
  // SHARED DRAWING HELPERS
  // =========================================================================

  /// Draws a ground shadow ellipse.
  void _drawGroundShadow(
      Canvas canvas, double cx, double cy, double width, double height) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: width, height: height),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy), width: width * 0.7, height: height * 0.6),
      Paint()..color = const Color(0x33000000),
    );
  }

  /// Draws a limb (arm or leg) as a thick line with round caps.
  void _drawLimb(Canvas canvas, Offset start, Offset end, double thickness,
      Color color) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
    // Slight highlight on left side
    canvas.drawLine(
      Offset(start.dx - 0.5, start.dy),
      Offset(end.dx - 0.5, end.dy),
      Paint()
        ..color = _lighten(color, 0.2).withAlpha(60)
        ..strokeWidth = thickness * 0.4
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draws a boot shape at the given position.
  void _drawBoot(Canvas canvas, Offset pos, Color color) {
    final bootPath = Path()
      ..moveTo(pos.dx - 5, pos.dy - 2)
      ..lineTo(pos.dx + 5, pos.dy - 2)
      ..lineTo(pos.dx + 6, pos.dy + 3)
      ..lineTo(pos.dx - 4, pos.dy + 3)
      ..close();
    canvas.drawPath(bootPath, Paint()..color = color);
  }

  /// Draws a basic human head shape (oval, not a circle).
  void _drawHumanHead(Canvas canvas, Offset center, double radius,
      Color skinLight, Color skinDark) {
    canvas.drawOval(
      Rect.fromCenter(
          center: center, width: radius * 2, height: radius * 2.2),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
          radius * 1.5,
          [skinLight, skinDark],
        ),
    );
  }

  /// Draws a shoulder pauldron.
  void _drawPauldron(Canvas canvas, Offset pos, bool isRight) {
    final dir = isRight ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(pos.dx, pos.dy + 6)
      ..quadraticBezierTo(
          pos.dx + dir * 8, pos.dy - 4, pos.dx, pos.dy - 4)
      ..quadraticBezierTo(
          pos.dx - dir * 2, pos.dy - 2, pos.dx, pos.dy + 6)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(pos.dx, pos.dy - 4),
          Offset(pos.dx, pos.dy + 6),
          [const Color(0xFF99AABB), const Color(0xFF667788)],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x50FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  /// Draws a large shoulder pauldron (for giants and bosses).
  void _drawLargePauldron(Canvas canvas, Offset pos, bool isRight,
      {Color color = const Color(0xFF8899AA)}) {
    final dir = isRight ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(pos.dx, pos.dy + 10)
      ..quadraticBezierTo(
          pos.dx + dir * 14, pos.dy - 6, pos.dx, pos.dy - 6)
      ..quadraticBezierTo(
          pos.dx - dir * 4, pos.dy, pos.dx, pos.dy + 10)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(pos.dx, pos.dy - 6),
          Offset(pos.dx, pos.dy + 10),
          [_lighten(color, 0.2), color, _darken(color, 0.3)],
          [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _lighten(color, 0.4).withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Rivets
    canvas.drawCircle(
      Offset(pos.dx + dir * 4, pos.dy),
      1.5,
      Paint()..color = _darken(color, 0.2),
    );
  }

  /// Draws spiked dark pauldron for Dark Knight.
  void _drawDarkPauldron(Canvas canvas, Offset pos, bool isRight) {
    final dir = isRight ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(pos.dx, pos.dy + 8)
      ..quadraticBezierTo(
          pos.dx + dir * 12, pos.dy - 4, pos.dx, pos.dy - 4)
      ..quadraticBezierTo(
          pos.dx - dir * 3, pos.dy, pos.dx, pos.dy + 8)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(pos.dx, pos.dy - 4),
          Offset(pos.dx, pos.dy + 8),
          [const Color(0xFF2A2A3A), const Color(0xFF1A1A2A)],
        ),
    );
    // Spike
    canvas.drawLine(
      Offset(pos.dx + dir * 6, pos.dy - 2),
      Offset(pos.dx + dir * 14, pos.dy - 10),
      Paint()
        ..color = const Color(0xFF3A3A4A)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draws a boss crown.
  void _drawBossCrown(Canvas canvas, Offset pos, double pulse, Color color) {
    final crownW = 12.0;
    final crownH = 8.0;
    final cx = pos.dx;
    final cy = pos.dy;

    final crown = Path()
      ..moveTo(cx - crownW, cy + crownH)
      ..lineTo(cx - crownW, cy)
      ..lineTo(cx - crownW * 0.5, cy + crownH * 0.4)
      ..lineTo(cx, cy - crownH * 0.3)
      ..lineTo(cx + crownW * 0.5, cy + crownH * 0.4)
      ..lineTo(cx + crownW, cy)
      ..lineTo(cx + crownW, cy + crownH)
      ..close();
    canvas.drawPath(crown, Paint()..color = color);
    canvas.drawPath(
      crown,
      Paint()
        ..color = _darken(color, 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Crown jewel
    canvas.drawCircle(
      Offset(cx, cy + crownH * 0.2),
      2.5,
      Paint()..color = const Color(0xFFFF2222),
    );
    canvas.drawCircle(
      Offset(cx, cy + crownH * 0.2),
      1.2,
      Paint()..color = const Color(0x88FFFFFF),
    );
    // Tip sparkles
    for (final tipX in [cx - crownW, cx, cx + crownW]) {
      canvas.drawCircle(
        Offset(tipX, cy - 2),
        1.2,
        Paint()
          ..color = Color.fromARGB(
            (140 + (pulse * 80).round()).clamp(0, 255),
            255,
            255,
            200,
          ),
      );
    }
  }

  /// Draws glowing eyes at two positions.
  void _drawGlowingEyes(Canvas canvas, Offset left, Offset right,
      double radius, Color color,
      {bool slitPupils = false}) {
    for (final pos in [left, right]) {
      // Glow
      canvas.drawCircle(
        pos,
        radius * 2.2,
        Paint()
          ..color = color.withAlpha(50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      // Eye
      canvas.drawCircle(pos, radius, Paint()..color = color);
      // Bright center
      canvas.drawCircle(
        pos,
        radius * 0.4,
        Paint()..color = const Color(0xDDFFFFFF),
      );
      if (slitPupils) {
        canvas.drawLine(
          Offset(pos.dx, pos.dy - radius * 0.8),
          Offset(pos.dx, pos.dy + radius * 0.8),
          Paint()
            ..color = const Color(0xFF000000)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Color helpers
  // ---------------------------------------------------------------------------

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
}
