import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/tower_data.dart';
import '../../data/game_config.dart';
import 'projectile.dart';

enum TargetingMode { nearest, first, strongest }

class Tower extends RectangleComponent {
  final TowerType type;
  int _tier = 1;
  int _totalSpent = 0;
  double _cooldown = 0;
  double _synergyDamageMultiplier = 1.0;
  double _synergyRangeBonus = 0.0;
  double _synergyFireRateMultiplier = 1.0;
  final int col;
  final int row;
  final double cellSize;

  double artifactDamageMultiplier = 1.0;
  double artifactRangeMultiplier = 1.0;
  double artifactFireRateMultiplier = 1.0;
  double supportDamageMultiplier = 1.0;
  double supportRangeMultiplier = 1.0;
  double kaleRuhuMultiplier = 1.0;
  bool showRange = false;
  int kills = 0;
  int totalDamageDealt = 0;
  TargetingMode targetingMode = TargetingMode.nearest;

  // Animation state
  double _animTimer = 0;

  Tower({
    required this.type,
    required this.col,
    required this.row,
    required this.cellSize,
  }) : super(
    position: Vector2(col * cellSize, row * cellSize),
    size: Vector2.all(cellSize),
    paint: Paint()..color = Colors.transparent, // We draw everything custom
    anchor: Anchor.topLeft,
  ) {
    _totalSpent = stats.cost;
  }

  TowerStats get stats => TowerData.getStats(type);
  int get tier => _tier;
  int get totalSpent => _totalSpent;

  int get currentDamage => (stats.damageAtTier(_tier) * _synergyDamageMultiplier * artifactDamageMultiplier * supportDamageMultiplier * kaleRuhuMultiplier).round();
  double get currentRange => (stats.rangeAtTier(_tier) + _synergyRangeBonus) * artifactRangeMultiplier * supportRangeMultiplier;
  double get currentFireRate => stats.fireRate * _synergyFireRateMultiplier * artifactFireRateMultiplier;

  int get sellValue => (totalSpent * GameConfig.sellRefundRatio).round();

  bool get canUpgrade => _tier < 4;
  int get upgradeCost => stats.upgradeCost(_tier + 1);

  bool upgrade() {
    if (!canUpgrade) return false;
    final cost = upgradeCost;
    _tier++;
    _totalSpent += cost;
    return true;
  }

  void applySynergyBonus({double damageMultiplier = 1.0, double rangeBonus = 0.0, double fireRateMultiplier = 1.0}) {
    _synergyDamageMultiplier = damageMultiplier;
    _synergyRangeBonus = rangeBonus;
    _synergyFireRateMultiplier = fireRateMultiplier;
  }

  void clearSynergyBonus() {
    _synergyDamageMultiplier = 1.0;
    _synergyRangeBonus = 0.0;
    _synergyFireRateMultiplier = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldown > 0) _cooldown -= dt;
    _animTimer += dt;
  }

  bool canFire() => _cooldown <= 0 && type != TowerType.spikeWall && type != TowerType.support;

  Projectile? tryFire(Vector2 targetPos) {
    if (!canFire()) return null;
    _cooldown = currentFireRate;
    return Projectile(
      startPos: position + size / 2,
      target: targetPos,
      damage: currentDamage,
      color: _primaryColor(type),
    );
  }

  bool isInRange(Vector2 targetPos) {
    final center = position + size / 2;
    final dist = center.distanceTo(targetPos);
    return dist <= currentRange * cellSize;
  }

  @override
  void render(Canvas canvas) {
    // Don't call super - we draw everything custom
    final center = Offset(size.x / 2, size.y / 2);
    final r = size.x * 0.42; // main body radius
    final primary = _primaryColor(type);
    final secondary = _secondaryColor(type);
    final pulse = (math.sin(_animTimer * 2.5) * 0.5 + 0.5); // 0..1 pulse
    final fireFlash = _cooldown > 0 ? (_cooldown / currentFireRate).clamp(0.0, 1.0) : 0.0;

    // --- TOWER BASE PLATFORM (stone/brick) ---
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 1, center.dy + 3), width: size.x * 0.88, height: size.y * 0.38),
      Paint()..color = const Color(0x44000000),
    );
    // Stone platform base
    final platformRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.7), width: size.x * 0.88, height: size.y * 0.28),
      const Radius.circular(3),
    );
    final platformGrad = ui.Gradient.linear(
      Offset(center.dx - size.x * 0.4, 0),
      Offset(center.dx + size.x * 0.4, 0),
      [const Color(0xFF6B6B6B), const Color(0xFF555555), const Color(0xFF404040)],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(platformRect, Paint()..shader = platformGrad);
    // Brick lines on platform
    final brickPaint = Paint()..color = const Color(0x22000000)..strokeWidth = 0.5;
    final platTop = center.dy + r * 0.7 - size.y * 0.14;
    final platBot = center.dy + r * 0.7 + size.y * 0.14;
    final platLeft = center.dx - size.x * 0.44;
    final platRight = center.dx + size.x * 0.44;
    // Horizontal brick line
    final midY = (platTop + platBot) / 2;
    canvas.drawLine(Offset(platLeft + 3, midY), Offset(platRight - 3, midY), brickPaint);
    // Vertical brick lines (staggered)
    for (double bx = platLeft + 8; bx < platRight - 4; bx += 10) {
      canvas.drawLine(Offset(bx, platTop + 1), Offset(bx, midY), brickPaint);
    }
    for (double bx = platLeft + 13; bx < platRight - 4; bx += 10) {
      canvas.drawLine(Offset(bx, midY), Offset(bx, platBot - 1), brickPaint);
    }
    // Platform border
    canvas.drawRRect(platformRect, Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
    );

    // --- TOWER BODY ---
    if (type == TowerType.spikeWall) {
      _drawSpikeWall(canvas, center, r);
    } else if (type == TowerType.support) {
      _drawSupportTower(canvas, center, r, pulse);
    } else {
      // Main tower body with 3D gradient (highlight left, shadow right)
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: r * 1.6, height: r * 1.85),
        Radius.circular(r * 0.25),
      );
      final bodyGrad = ui.Gradient.linear(
        Offset(center.dx - r * 0.8, center.dy - r * 0.5),
        Offset(center.dx + r * 0.8, center.dy + r * 0.5),
        [_lighten(primary, 0.45), _lighten(primary, 0.15), primary, _darken(primary, 0.25), _darken(primary, 0.4)],
        [0.0, 0.2, 0.45, 0.75, 1.0],
      );
      canvas.drawRRect(bodyRect, Paint()..shader = bodyGrad);

      // Left highlight edge (3D effect)
      final highlightPath = Path();
      final hlRect = Rect.fromCenter(center: center, width: r * 1.6, height: r * 1.85);
      highlightPath.moveTo(hlRect.left + r * 0.25, hlRect.top + r * 0.25);
      highlightPath.lineTo(hlRect.left + r * 0.25, hlRect.bottom - r * 0.25);
      canvas.drawPath(highlightPath, Paint()
        ..color = _lighten(primary, 0.5).withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
      );

      // Right shadow edge (3D effect)
      final shadowPath = Path();
      shadowPath.moveTo(hlRect.right - r * 0.25, hlRect.top + r * 0.35);
      shadowPath.lineTo(hlRect.right - r * 0.25, hlRect.bottom - r * 0.25);
      canvas.drawPath(shadowPath, Paint()
        ..color = _darken(primary, 0.5).withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
      );

      // Window/detail line (small dark slit)
      final windowRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + r * 0.35),
          width: r * 0.35,
          height: r * 0.18,
        ),
        Radius.circular(r * 0.06),
      );
      canvas.drawRRect(windowRect, Paint()..color = _darken(primary, 0.55).withAlpha(140));
      canvas.drawRRect(windowRect, Paint()
        ..color = _lighten(primary, 0.2).withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
      );

      // Body border
      canvas.drawRRect(bodyRect, Paint()
        ..color = _lighten(primary, 0.2).withAlpha(100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
      );

      // Tower top crenellations (more defined)
      final topY = center.dy - r * 0.92;
      final crenW = r * 0.32;
      final crenCount = 4;
      final totalCrenWidth = crenCount * crenW;
      final startX = center.dx - totalCrenWidth / 2;
      for (int i = 0; i < crenCount; i++) {
        final cx = startX + i * crenW;
        final crenRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + crenW * 0.1, topY - r * 0.28, crenW * 0.6, r * 0.32),
          Radius.circular(r * 0.06),
        );
        // Crenellation body gradient
        final crenGrad = ui.Gradient.linear(
          Offset(cx, topY - r * 0.28),
          Offset(cx + crenW * 0.6, topY),
          [_lighten(primary, 0.1), _darken(primary, 0.2)],
        );
        canvas.drawRRect(crenRect, Paint()..shader = crenGrad);
        canvas.drawRRect(crenRect, Paint()
          ..color = _darken(primary, 0.3).withAlpha(80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
        );
      }

      // --- FIRING FLASH (when tower just fired) ---
      if (fireFlash > 0.3) {
        final flashIntensity = ((fireFlash - 0.3) / 0.7).clamp(0.0, 1.0);
        final flashAlpha = (flashIntensity * 100).round();
        final flashColor = Color.fromARGB(flashAlpha, secondary.red, secondary.green, secondary.blue);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: r * 1.8, height: r * 2.1),
            Radius.circular(r * 0.3),
          ),
          Paint()..color = flashColor,
        );
        // Small bright flash at tower top
        canvas.drawCircle(
          Offset(center.dx, center.dy - r * 0.6),
          r * 0.35 * flashIntensity,
          Paint()..color = Color.fromARGB((flashIntensity * 180).round(), 255, 255, 230),
        );
      }
    }

    // --- TOWER ICON ---
    _drawTowerIcon(canvas, center, type, primary, secondary);

    // --- TIER INDICATORS ---
    if (_tier >= 2) {
      // Tier stars at bottom
      for (int i = 0; i < _tier; i++) {
        final sx = center.dx - (_tier - 1) * 3.5 + i * 7;
        final sy = size.y - 5;
        _drawStar(canvas, sx, sy, 2.5, _tier >= 4 ? const Color(0xFFFFD700) : const Color(0xCCFFD700));
      }
    }

    // --- SYNERGY GLOW ---
    if (_synergyDamageMultiplier > 1.0 || _synergyRangeBonus > 0) {
      final glowAlpha = (40 + pulse * 25).round();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-2, -2, size.x + 4, size.y + 4),
          const Radius.circular(4),
        ),
        Paint()
          ..color = Color.fromARGB(glowAlpha, 255, 215, 0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // --- SUPPORT AURA GLOW ---
    if (supportDamageMultiplier > 1.0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
          const Radius.circular(3),
        ),
        Paint()..color = Color.fromARGB((20 + pulse * 15).round(), 255, 255, 0),
      );
    }

    // --- RANGE CIRCLE ---
    if (showRange && currentRange > 0) {
      final rangePixels = currentRange * cellSize;
      canvas.drawCircle(center, rangePixels, Paint()
        ..color = const Color(0x18FFFFFF)
        ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(center, rangePixels, Paint()
        ..color = const Color(0x44FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
      );
    }

    // --- TARGETING MODE INDICATOR ---
    if (targetingMode != TargetingMode.nearest && type != TowerType.spikeWall && type != TowerType.support) {
      final tx = size.x - 6;
      const ty = 4.0;
      final tmBg = Paint()..color = const Color(0x88000000);
      canvas.drawCircle(Offset(tx, ty), 4, tmBg);
      final tmPaint = Paint()..color = const Color(0xDDFFFFFF)..strokeWidth = 1.2..strokeCap = StrokeCap.round;
      if (targetingMode == TargetingMode.first) {
        canvas.drawLine(Offset(tx - 2, ty), Offset(tx + 2, ty), tmPaint);
        canvas.drawLine(Offset(tx + 1, ty - 2), Offset(tx + 2, ty), tmPaint);
        canvas.drawLine(Offset(tx + 1, ty + 2), Offset(tx + 2, ty), tmPaint);
      } else {
        canvas.drawLine(Offset(tx, ty - 3), Offset(tx + 3, ty), tmPaint..style = PaintingStyle.stroke);
        canvas.drawLine(Offset(tx + 3, ty), Offset(tx, ty + 3), tmPaint);
        canvas.drawLine(Offset(tx, ty + 3), Offset(tx - 3, ty), tmPaint);
        canvas.drawLine(Offset(tx - 3, ty), Offset(tx, ty - 3), tmPaint);
      }
    }
  }

  void _drawSpikeWall(Canvas canvas, Offset center, double r) {
    // Wooden base with wood grain
    final baseRect = Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.2), width: r * 1.8, height: r * 0.8);
    final woodGrad = ui.Gradient.linear(
      Offset(baseRect.left, 0),
      Offset(baseRect.right, 0),
      [const Color(0xFF6D4C2A), const Color(0xFF5C4020), const Color(0xFF4A3518)],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(baseRect, Paint()..shader = woodGrad);
    // Wood grain lines
    for (double gy = baseRect.top + 3; gy < baseRect.bottom - 2; gy += 4) {
      canvas.drawLine(Offset(baseRect.left + 2, gy), Offset(baseRect.right - 2, gy),
        Paint()..color = const Color(0x22000000)..strokeWidth = 0.5);
    }
    canvas.drawRect(baseRect, Paint()..color = const Color(0xFF3C2810)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Metal spikes with better shading
    for (int i = 0; i < 4; i++) {
      final sx = center.dx - r * 0.6 + i * r * 0.4;
      final spikeGrad = ui.Gradient.linear(
        Offset(sx - r * 0.05, center.dy - r * 0.7),
        Offset(sx + r * 0.08, center.dy + r * 0.2),
        [const Color(0xFFE0E0E0), const Color(0xFF999999), const Color(0xFF555555)],
        [0.0, 0.4, 1.0],
      );
      final spike = Path()
        ..moveTo(sx - r * 0.1, center.dy + r * 0.2)
        ..lineTo(sx, center.dy - r * 0.75)
        ..lineTo(sx + r * 0.1, center.dy + r * 0.2)
        ..close();
      canvas.drawPath(spike, Paint()..shader = spikeGrad);
      // Spike edge highlight
      canvas.drawLine(
        Offset(sx - r * 0.05, center.dy + r * 0.1),
        Offset(sx, center.dy - r * 0.65),
        Paint()..color = const Color(0x44FFFFFF)..strokeWidth = 0.5,
      );
    }
  }

  void _drawSupportTower(Canvas canvas, Offset center, double r, double pulse) {
    // Glowing orb with richer color
    final orbGrad = ui.Gradient.radial(
      Offset(center.dx - r * 0.15, center.dy - r * 0.15),
      r * 1.2,
      [
        const Color(0xFFFFFF99),
        const Color(0xFFEECC00),
        const Color(0xFFAA9900),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawCircle(center, r * 0.7, Paint()..shader = orbGrad);

    // Inner bright core
    canvas.drawCircle(
      Offset(center.dx - r * 0.1, center.dy - r * 0.1),
      r * 0.25,
      Paint()..color = const Color(0x66FFFFFF),
    );

    // Outer glow pulse
    final glowRadius = r * (0.85 + pulse * 0.15);
    canvas.drawCircle(center, glowRadius, Paint()
      ..color = Color.fromARGB((35 + pulse * 25).round(), 255, 255, 0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
    );
    // Secondary outer ring
    canvas.drawCircle(center, glowRadius + 2, Paint()
      ..color = Color.fromARGB((15 + pulse * 10).round(), 255, 230, 0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
    );

    // Plus sign (thicker)
    final plusPaint = Paint()..color = const Color(0xCC1A150E)..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx, center.dy - r * 0.3), Offset(center.dx, center.dy + r * 0.3), plusPaint);
    canvas.drawLine(Offset(center.dx - r * 0.3, center.dy), Offset(center.dx + r * 0.3, center.dy), plusPaint);
  }

  void _drawTowerIcon(Canvas canvas, Offset center, TowerType type, Color primary, Color secondary) {
    final iconPaint = Paint()..color = const Color(0xDDFFFFFF);
    final r = size.x * 0.17; // slightly larger icon area

    switch (type) {
      case TowerType.arrow:
        // Bow and arrow (thicker strokes)
        final bowPath = Path()
          ..moveTo(center.dx - r * 0.3, center.dy + r * 1.2)
          ..quadraticBezierTo(center.dx + r * 1.3, center.dy, center.dx - r * 0.3, center.dy - r * 1.2);
        canvas.drawPath(bowPath, iconPaint..style = PaintingStyle.stroke..strokeWidth = 2.5);
        canvas.drawLine(
          Offset(center.dx - r * 0.9, center.dy + r * 0.9),
          Offset(center.dx + r * 0.9, center.dy - r * 0.9),
          iconPaint..strokeWidth = 2.0,
        );
        // Arrow tip
        canvas.drawLine(
          Offset(center.dx + r * 0.9, center.dy - r * 0.9),
          Offset(center.dx + r * 0.4, center.dy - r * 0.7),
          iconPaint..strokeWidth = 2.0,
        );
        canvas.drawLine(
          Offset(center.dx + r * 0.9, center.dy - r * 0.9),
          Offset(center.dx + r * 0.7, center.dy - r * 0.4),
          iconPaint..strokeWidth = 2.0,
        );
        break;
      case TowerType.ice:
        // Snowflake (thicker, 6-fold symmetry)
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          canvas.drawLine(
            Offset(center.dx - r * 0.9 * math.cos(angle), center.dy - r * 0.9 * math.sin(angle)),
            Offset(center.dx + r * 0.9 * math.cos(angle), center.dy + r * 0.9 * math.sin(angle)),
            Paint()..color = const Color(0xDDBBEEFF)..strokeWidth = 2.0..strokeCap = StrokeCap.round,
          );
          // Small branches on each arm
          final bx = center.dx + r * 0.5 * math.cos(angle);
          final by = center.dy + r * 0.5 * math.sin(angle);
          final branchAngle1 = angle + math.pi / 4;
          final branchAngle2 = angle - math.pi / 4;
          canvas.drawLine(
            Offset(bx, by),
            Offset(bx + r * 0.3 * math.cos(branchAngle1), by + r * 0.3 * math.sin(branchAngle1)),
            Paint()..color = const Color(0xAACCEEFF)..strokeWidth = 1.5..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            Offset(bx, by),
            Offset(bx + r * 0.3 * math.cos(branchAngle2), by + r * 0.3 * math.sin(branchAngle2)),
            Paint()..color = const Color(0xAACCEEFF)..strokeWidth = 1.5..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(center, r * 0.2, Paint()..color = const Color(0xAAFFFFFF));
        break;
      case TowerType.fire:
        // Flame (bolder)
        final flamePath = Path()
          ..moveTo(center.dx, center.dy - r * 1.3)
          ..quadraticBezierTo(center.dx + r * 1.1, center.dy - r * 0.2, center.dx + r * 0.55, center.dy + r * 1.0)
          ..quadraticBezierTo(center.dx, center.dy + r * 0.4, center.dx - r * 0.55, center.dy + r * 1.0)
          ..quadraticBezierTo(center.dx - r * 1.1, center.dy - r * 0.2, center.dx, center.dy - r * 1.3);
        canvas.drawPath(flamePath, Paint()..color = const Color(0xEEFF6600));
        // Inner bright flame
        final innerFlame = Path()
          ..moveTo(center.dx, center.dy - r * 0.6)
          ..quadraticBezierTo(center.dx + r * 0.45, center.dy + r * 0.1, center.dx + r * 0.2, center.dy + r * 0.55)
          ..quadraticBezierTo(center.dx, center.dy + r * 0.25, center.dx - r * 0.2, center.dy + r * 0.55)
          ..quadraticBezierTo(center.dx - r * 0.45, center.dy + r * 0.1, center.dx, center.dy - r * 0.6);
        canvas.drawPath(innerFlame, Paint()..color = const Color(0xEEFFDD00));
        // White hot core
        canvas.drawCircle(Offset(center.dx, center.dy + r * 0.15), r * 0.15, Paint()..color = const Color(0x88FFFFFF));
        break;
      case TowerType.lightning:
        // Bold lightning bolt
        final bolt = Path()
          ..moveTo(center.dx + r * 0.35, center.dy - r * 1.3)
          ..lineTo(center.dx - r * 0.15, center.dy - r * 0.1)
          ..lineTo(center.dx + r * 0.35, center.dy - r * 0.1)
          ..lineTo(center.dx - r * 0.15, center.dy + r * 1.3);
        canvas.drawPath(bolt, Paint()..color = const Color(0xEEFFEE00)..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
        // Glow around bolt
        canvas.drawPath(bolt, Paint()..color = const Color(0x33FFFF88)..style = PaintingStyle.stroke..strokeWidth = 5.0..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
        break;
      case TowerType.cannon:
        // Cannon barrel (thicker, metallic)
        final barrelGrad = ui.Gradient.linear(
          Offset(center.dx - r * 0.3, center.dy - r * 0.35),
          Offset(center.dx - r * 0.3, center.dy + r * 0.35),
          [const Color(0xCC666666), const Color(0xCC333333), const Color(0xCC555555)],
          [0.0, 0.5, 1.0],
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(center.dx + r * 0.15, center.dy), width: r * 1.7, height: r * 0.8),
            Radius.circular(r * 0.15),
          ),
          Paint()..shader = barrelGrad,
        );
        // Barrel rings
        canvas.drawLine(
          Offset(center.dx - r * 0.3, center.dy - r * 0.35),
          Offset(center.dx - r * 0.3, center.dy + r * 0.35),
          Paint()..color = const Color(0xAA888888)..strokeWidth = 1.5,
        );
        canvas.drawLine(
          Offset(center.dx + r * 0.3, center.dy - r * 0.35),
          Offset(center.dx + r * 0.3, center.dy + r * 0.35),
          Paint()..color = const Color(0xAA888888)..strokeWidth = 1.5,
        );
        // Cannonball
        final ballGrad = ui.Gradient.radial(
          Offset(center.dx + r * 0.8, center.dy - r * 0.1),
          r * 0.4,
          [const Color(0xCC444444), const Color(0xCC111111)],
        );
        canvas.drawCircle(Offset(center.dx + r * 0.9, center.dy), r * 0.28, Paint()..shader = ballGrad);
        break;
      case TowerType.spikeWall:
        break; // handled separately
      case TowerType.support:
        break; // handled separately
      case TowerType.water:
        // Water drop (bigger, bolder)
        final dropPath = Path()
          ..moveTo(center.dx, center.dy - r * 1.1)
          ..quadraticBezierTo(center.dx + r * 0.9, center.dy + r * 0.35, center.dx, center.dy + r * 0.9)
          ..quadraticBezierTo(center.dx - r * 0.9, center.dy + r * 0.35, center.dx, center.dy - r * 1.1);
        canvas.drawPath(dropPath, Paint()..color = const Color(0xDD44CCEE));
        // Inner ripple
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - r * 0.4)
            ..quadraticBezierTo(center.dx + r * 0.4, center.dy + r * 0.15, center.dx, center.dy + r * 0.45)
            ..quadraticBezierTo(center.dx - r * 0.4, center.dy + r * 0.15, center.dx, center.dy - r * 0.4),
          Paint()..color = const Color(0x66FFFFFF),
        );
        // Highlight
        canvas.drawCircle(Offset(center.dx - r * 0.18, center.dy - r * 0.15), r * 0.18, Paint()..color = const Color(0x77FFFFFF));
        break;
      case TowerType.wizard:
        // Arcane pentagram (thicker)
        for (int i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5 - math.pi / 2;
          final nextAngle = ((i + 2) % 5) * math.pi * 2 / 5 - math.pi / 2;
          canvas.drawLine(
            Offset(center.dx + r * 1.05 * math.cos(angle), center.dy + r * 1.05 * math.sin(angle)),
            Offset(center.dx + r * 1.05 * math.cos(nextAngle), center.dy + r * 1.05 * math.sin(nextAngle)),
            Paint()..color = const Color(0xDDDD88FF)..strokeWidth = 2.0,
          );
        }
        // Bright arcane center
        canvas.drawCircle(center, r * 0.28, Paint()..color = const Color(0xBBDD88FF));
        canvas.drawCircle(center, r * 0.15, Paint()..color = const Color(0x88FFFFFF));
        break;
      case TowerType.poison:
        // Skull (bigger, bolder)
        canvas.drawCircle(Offset(center.dx, center.dy - r * 0.1), r * 0.65, Paint()..color = const Color(0xDD00FF44));
        // Eye sockets
        canvas.drawCircle(Offset(center.dx - r * 0.25, center.dy - r * 0.25), r * 0.16, Paint()..color = const Color(0xFF0A0A0A));
        canvas.drawCircle(Offset(center.dx + r * 0.25, center.dy - r * 0.25), r * 0.16, Paint()..color = const Color(0xFF0A0A0A));
        // Glowing eye dots
        canvas.drawCircle(Offset(center.dx - r * 0.25, center.dy - r * 0.25), r * 0.06, Paint()..color = const Color(0xCC00FF00));
        canvas.drawCircle(Offset(center.dx + r * 0.25, center.dy - r * 0.25), r * 0.06, Paint()..color = const Color(0xCC00FF00));
        // Jaw with teeth
        canvas.drawRect(
          Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.35), width: r * 0.6, height: r * 0.22),
          Paint()..color = const Color(0xDD00FF44),
        );
        // Teeth
        for (double tx = center.dx - r * 0.25; tx <= center.dx + r * 0.25; tx += r * 0.17) {
          canvas.drawRect(
            Rect.fromLTWH(tx, center.dy + r * 0.24, r * 0.08, r * 0.1),
            Paint()..color = const Color(0xFF0A0A0A),
          );
        }
        break;
      case TowerType.dark:
        // Dark orb with crescent (bolder)
        canvas.drawCircle(center, r * 0.7, Paint()..color = const Color(0xDD7700EE));
        canvas.drawCircle(Offset(center.dx + r * 0.2, center.dy - r * 0.1), r * 0.5, Paint()..color = _darken(primary, 0.6));
        // Orbiting dark particles
        for (int i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5 + _animTimer * 0.7;
          final px = center.dx + r * 0.9 * math.cos(angle);
          final py = center.dy + r * 0.9 * math.sin(angle);
          canvas.drawCircle(Offset(px, py), 1.8, Paint()..color = const Color(0xBB9900FF));
        }
        // Inner glow
        canvas.drawCircle(Offset(center.dx - r * 0.15, center.dy + r * 0.05), r * 0.18, Paint()..color = const Color(0x44CC66FF));
        break;
      case TowerType.holy:
        // Radiant sun (bigger, brighter)
        canvas.drawCircle(center, r * 0.4, Paint()..color = const Color(0xEEFFF5CC));
        canvas.drawCircle(center, r * 0.28, Paint()..color = const Color(0xDDFFFFEE));
        for (int i = 0; i < 8; i++) {
          final angle = i * math.pi / 4 + _animTimer * 0.3;
          // Main ray
          canvas.drawLine(
            Offset(center.dx + r * 0.5 * math.cos(angle), center.dy + r * 0.5 * math.sin(angle)),
            Offset(center.dx + r * 0.95 * math.cos(angle), center.dy + r * 0.95 * math.sin(angle)),
            Paint()..color = const Color(0xCCFFEE66)..strokeWidth = 2.5..strokeCap = StrokeCap.round,
          );
          // Short secondary ray between main rays
          final halfAngle = angle + math.pi / 8;
          canvas.drawLine(
            Offset(center.dx + r * 0.45 * math.cos(halfAngle), center.dy + r * 0.45 * math.sin(halfAngle)),
            Offset(center.dx + r * 0.65 * math.cos(halfAngle), center.dy + r * 0.65 * math.sin(halfAngle)),
            Paint()..color = const Color(0x88FFE844)..strokeWidth = 1.5..strokeCap = StrokeCap.round,
          );
        }
        break;
    }
  }

  void _drawStar(Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = i * math.pi * 2 / 5 - math.pi / 2;
      final innerAngle = outerAngle + math.pi / 5;
      if (i == 0) {
        path.moveTo(cx + r * math.cos(outerAngle), cy + r * math.sin(outerAngle));
      } else {
        path.lineTo(cx + r * math.cos(outerAngle), cy + r * math.sin(outerAngle));
      }
      path.lineTo(cx + r * 0.45 * math.cos(innerAngle), cy + r * 0.45 * math.sin(innerAngle));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  static Color _primaryColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFF9E5B3C);     // rich mahogany/copper
      case TowerType.ice: return const Color(0xFF22CCEE);        // brilliant cyan/frost
      case TowerType.fire: return const Color(0xFFFF5511);       // bright orange-red
      case TowerType.lightning: return const Color(0xFFFFDD00);  // electric bright yellow
      case TowerType.poison: return const Color(0xFF33FF33);     // toxic neon green
      case TowerType.cannon: return const Color(0xFF4A5568);     // dark steel/gunmetal
      case TowerType.spikeWall: return const Color(0xFF555555);
      case TowerType.support: return const Color(0xFFDDCC00);
      case TowerType.water: return const Color(0xFF00BBCC);      // ocean turquoise
      case TowerType.wizard: return const Color(0xFFAA33DD);     // vibrant violet
      case TowerType.dark: return const Color(0xFF3311AA);       // deep indigo
      case TowerType.holy: return const Color(0xFFFFDD66);       // radiant warm white-gold
    }
  }

  static Color _secondaryColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFFCC8866);
      case TowerType.ice: return const Color(0xFFAAEEFF);
      case TowerType.fire: return const Color(0xFFFFAA22);
      case TowerType.lightning: return const Color(0xFFFFFF88);
      case TowerType.poison: return const Color(0xFF88FF88);
      case TowerType.cannon: return const Color(0xFF8899AA);
      case TowerType.spikeWall: return const Color(0xFF888888);
      case TowerType.support: return const Color(0xFFFFFF88);
      case TowerType.water: return const Color(0xFF77EEFF);
      case TowerType.wizard: return const Color(0xFFDD99FF);
      case TowerType.dark: return const Color(0xFF9944FF);
      case TowerType.holy: return const Color(0xFFFFF5DD);
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
}
