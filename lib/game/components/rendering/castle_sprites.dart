import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Procedural sprite generator for the castle at 3 damage phases.
///
/// Generates 512x512 sprites for:
/// - **Phase 0 (Intact)**: Grand medieval castle with 4 cylindrical corner towers,
///   central keep, crenellated walls, arched gate with portcullis, glowing windows,
///   banner, detailed stone brick texture.
/// - **Phase 1 (Damaged, HP 40-70%)**: One tower partially collapsed, wall cracks,
///   missing crenellations, torn flag, debris, broken window, smoke wisps.
/// - **Phase 2 (Ruined, HP < 40%)**: Two towers collapsed, large wall sections
///   missing, fire/embers through gaps, heavy smoke, broken gate, rubble piles.
class CastleSpriteGenerator {
  static final CastleSpriteGenerator instance = CastleSpriteGenerator._();
  CastleSpriteGenerator._();

  final Map<int, ui.Image> _cache = {}; // key: damage phase 0, 1, 2
  static const int spriteSize = 512;
  static const double _s = 512.0;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Generates all 3 castle phase sprites. Safe to call multiple times.
  /// Tries to load AI-generated PNGs first, falls back to procedural.
  Future<void> initialize() async {
    if (_initialized) return;

    for (int phase = 0; phase <= 2; phase++) {
      final pngPath = 'assets/images/castle/castle_phase$phase.png';
      final pngImage = await _tryLoadPng(pngPath);
      if (pngImage != null) {
        _cache[phase] = pngImage;
      } else {
        _cache[phase] = await _renderPhase(phase);
      }
    }

    _initialized = true;
  }

  /// Attempts to load a PNG image from the asset bundle.
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

  // ---------------------------------------------------------------------------
  //  Main paint orchestrator
  // ---------------------------------------------------------------------------

  void _paintCastle(Canvas canvas, int phase) {
    // Layer order: ground -> walls -> towers -> keep -> details -> windows ->
    //              gate -> banner/flags -> damage -> effects

    // 1. Ground / base
    _drawGround(canvas, phase);

    // 2. Rear wall sections (between towers)
    _drawCurtainWalls(canvas, phase);

    // 3. Four corner towers (cylindrical with conical roofs)
    _drawCornerTowers(canvas, phase);

    // 4. Central keep (tallest tower)
    _drawCentralKeep(canvas, phase);

    // 5. Gate with portcullis
    _drawGate(canvas, phase);

    // 6. Banner on central keep
    _drawBanner(canvas, phase);

    // 7. Flags on towers
    _drawFlags(canvas, phase);

    // 8. Damage overlays
    if (phase >= 1) _drawDamagePhase1(canvas);
    if (phase >= 2) _drawDamagePhase2(canvas);
  }

  // ---------------------------------------------------------------------------
  //  Ground / base platform
  // ---------------------------------------------------------------------------

  void _drawGround(Canvas canvas, int phase) {
    // Ground shadow ellipse
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(_s * 0.5, _s * 0.96),
        width: _s * 0.94,
        height: _s * 0.07,
      ),
      Paint()..color = const Color(0x66000000),
    );

    // Stone base platform with gradient
    final basePath = Path()
      ..moveTo(_s * 0.03, _s * 0.88)
      ..lineTo(_s * 0.08, _s * 0.82)
      ..lineTo(_s * 0.92, _s * 0.82)
      ..lineTo(_s * 0.97, _s * 0.88)
      ..lineTo(_s * 0.97, _s * 0.95)
      ..lineTo(_s * 0.03, _s * 0.95)
      ..close();

    final baseGrad = ui.Gradient.linear(
      Offset(0, _s * 0.82),
      Offset(0, _s * 0.95),
      [
        const Color(0xFF5A5048),
        const Color(0xFF3A3230),
        const Color(0xFF2A2220),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawPath(basePath, Paint()..shader = baseGrad);

    // Base brick texture
    final baseBrick = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 0.8;
    for (double y = _s * 0.84; y < _s * 0.94; y += 6) {
      canvas.drawLine(Offset(_s * 0.05, y), Offset(_s * 0.95, y), baseBrick);
    }
    for (double x = _s * 0.08; x < _s * 0.95; x += 14) {
      final row = ((x - _s * 0.08) / 14).floor();
      final yOff = (row.isEven) ? 0.0 : 3.0;
      for (double y = _s * 0.84 + yOff; y < _s * 0.94; y += 12) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 6), baseBrick);
      }
    }

    // Base platform highlight top edge
    canvas.drawLine(
      Offset(_s * 0.08, _s * 0.82),
      Offset(_s * 0.92, _s * 0.82),
      Paint()
        ..color = const Color(0x33AAAAAA)
        ..strokeWidth = 1.5,
    );

    // Rubble at base for phase 2
    if (phase >= 2) {
      _drawRubblePile(canvas, _s * 0.05, _s * 0.86, _s * 0.35, _s * 0.10, 42);
      _drawRubblePile(canvas, _s * 0.60, _s * 0.86, _s * 0.35, _s * 0.10, 99);
    }
  }

  // ---------------------------------------------------------------------------
  //  Curtain walls (connecting the towers)
  // ---------------------------------------------------------------------------

  void _drawCurtainWalls(Canvas canvas, int phase) {
    final wallTop = _s * 0.32;
    final wallBottom = _s * 0.82;
    final wallLeft = _s * 0.14;
    final wallRight = _s * 0.86;

    // Main wall gradient - dark stone
    final wallGrad = ui.Gradient.linear(
      Offset(0, wallTop),
      Offset(0, wallBottom),
      [
        const Color(0xFF706058),
        const Color(0xFF585048),
        const Color(0xFF484038),
        const Color(0xFF383028),
      ],
      [0.0, 0.3, 0.7, 1.0],
    );

    // Left wall section
    if (phase < 2) {
      canvas.drawRect(
        Rect.fromLTWH(wallLeft, wallTop, _s * 0.20, wallBottom - wallTop),
        Paint()..shader = wallGrad,
      );
    } else {
      // Partially destroyed left wall
      final leftWallPath = Path()
        ..moveTo(wallLeft, wallTop)
        ..lineTo(wallLeft + _s * 0.20, wallTop)
        ..lineTo(wallLeft + _s * 0.20, wallBottom)
        ..lineTo(wallLeft, wallBottom)
        ..lineTo(wallLeft, wallTop + _s * 0.10)
        ..lineTo(wallLeft + _s * 0.04, wallTop + _s * 0.06)
        ..lineTo(wallLeft + _s * 0.02, wallTop + _s * 0.02)
        ..close();
      canvas.drawPath(leftWallPath, Paint()..shader = wallGrad);
    }

    // Right wall section
    if (phase < 2) {
      canvas.drawRect(
        Rect.fromLTWH(
            wallRight - _s * 0.20, wallTop, _s * 0.20, wallBottom - wallTop),
        Paint()..shader = wallGrad,
      );
    } else {
      // Large section of right wall missing
      final rightWallPath = Path()
        ..moveTo(wallRight - _s * 0.20, wallTop)
        ..lineTo(wallRight - _s * 0.06, wallTop)
        ..lineTo(wallRight - _s * 0.08, wallTop + _s * 0.15)
        ..lineTo(wallRight - _s * 0.03, wallTop + _s * 0.20)
        ..lineTo(wallRight, wallTop + _s * 0.25)
        ..lineTo(wallRight, wallBottom)
        ..lineTo(wallRight - _s * 0.20, wallBottom)
        ..close();
      canvas.drawPath(rightWallPath, Paint()..shader = wallGrad);
    }

    // Front wall (center section between towers)
    canvas.drawRect(
      Rect.fromLTWH(wallLeft + _s * 0.06, wallTop, _s * 0.60, wallBottom - wallTop),
      Paint()..shader = wallGrad,
    );

    // Left side illumination on front wall
    final wallHighlight = ui.Gradient.linear(
      Offset(wallLeft, 0),
      Offset(wallLeft + _s * 0.25, 0),
      [const Color(0x18FFFFFF), Colors.transparent],
    );
    canvas.drawRect(
      Rect.fromLTWH(wallLeft, wallTop, _s * 0.72, wallBottom - wallTop),
      Paint()..shader = wallHighlight,
    );

    // Detailed brick pattern on walls
    _drawStoneBricks(
        canvas, wallLeft + _s * 0.06, wallTop, _s * 0.60, wallBottom - wallTop, phase);

    // Crenellations on top of wall
    _drawWallCrenellations(canvas, phase);
  }

  // ---------------------------------------------------------------------------
  //  Detailed stone brick texture
  // ---------------------------------------------------------------------------

  void _drawStoneBricks(
      Canvas canvas, double x, double y, double w, double h, int phase) {
    final brickH = 10.0;
    final brickW = 22.0;
    final mortarPaint = Paint()
      ..color = const Color(0x20000000)
      ..strokeWidth = 0.7;
    final mortarLight = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 0.5;
    final rng = math.Random(17);

    int row = 0;
    for (double by = y + 2; by < y + h - 2; by += brickH + 1.5) {
      final offset = (row.isEven) ? 0.0 : brickW * 0.5;
      for (double bx = x + 2 + offset; bx < x + w - 2; bx += brickW + 1.5) {
        final bw = math.min(brickW, (x + w - 2) - bx);
        if (bw < 4) continue;

        // Slight color variation per brick
        final variation = rng.nextInt(20) - 10;
        final brickColor = Color.fromARGB(
          14 + rng.nextInt(10),
          50 + variation,
          40 + variation,
          30 + variation,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, brickH),
            const Radius.circular(1.0),
          ),
          Paint()..color = brickColor,
        );

        // Mortar lines
        canvas.drawLine(Offset(bx, by), Offset(bx + bw, by), mortarPaint);
        canvas.drawLine(
            Offset(bx, by + 0.7), Offset(bx + bw, by + 0.7), mortarLight);
        if (bx > x + 4) {
          canvas.drawLine(
              Offset(bx, by), Offset(bx, by + brickH), mortarPaint);
        }
      }
      row++;
    }
  }

  // ---------------------------------------------------------------------------
  //  Wall crenellations (battlements)
  // ---------------------------------------------------------------------------

  void _drawWallCrenellations(Canvas canvas, int phase) {
    final crenW = 16.0;
    final crenH = 14.0;
    final crenTop = _s * 0.32 - crenH;
    final wallLeft = _s * 0.22;
    final wallRight = _s * 0.78;

    final crenGrad = ui.Gradient.linear(
      Offset(0, crenTop),
      Offset(0, crenTop + crenH),
      [const Color(0xFF706058), const Color(0xFF585048)],
    );

    final rng = math.Random(33);
    int idx = 0;
    for (double cx = wallLeft; cx < wallRight - crenW; cx += crenW * 2) {
      // Phase 1+: some crenellations missing
      if (phase >= 1 && (idx == 2 || idx == 5 || idx == 8)) {
        idx++;
        continue;
      }
      if (phase >= 2 && (idx == 1 || idx == 4 || idx == 6 || idx == 9)) {
        idx++;
        continue;
      }

      // Slight height variation
      final hVar = rng.nextDouble() * 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx, crenTop - hVar, crenW, crenH + hVar),
          const Radius.circular(1.0),
        ),
        Paint()..shader = crenGrad,
      );
      // Highlight on top
      canvas.drawLine(
        Offset(cx + 1, crenTop - hVar),
        Offset(cx + crenW - 1, crenTop - hVar),
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..strokeWidth = 1.0,
      );
      idx++;
    }
  }

  // ---------------------------------------------------------------------------
  //  Corner towers (cylindrical with conical roofs)
  // ---------------------------------------------------------------------------

  void _drawCornerTowers(Canvas canvas, int phase) {
    // Tower positions: [x_center, y_top, y_bottom, collapsed?]
    // Front-left, front-right, back-left, back-right
    final towers = <_TowerDef>[
      _TowerDef(_s * 0.15, _s * 0.22, _s * 0.82, false),        // front-left
      _TowerDef(_s * 0.85, _s * 0.22, _s * 0.82, phase >= 1),   // front-right (damaged p1)
      _TowerDef(_s * 0.28, _s * 0.18, _s * 0.62, false),        // back-left
      _TowerDef(_s * 0.72, _s * 0.18, _s * 0.62, phase >= 2),   // back-right (collapsed p2)
    ];

    // Draw back towers first, then front
    _drawSingleTower(canvas, towers[2], phase, 2); // back-left
    _drawSingleTower(canvas, towers[3], phase, 3); // back-right
    _drawSingleTower(canvas, towers[0], phase, 0); // front-left
    _drawSingleTower(canvas, towers[1], phase, 1); // front-right
  }

  void _drawSingleTower(
      Canvas canvas, _TowerDef tower, int phase, int towerIndex) {
    final towerRadius = 30.0;
    final cx = tower.centerX;
    var top = tower.yTop;
    final bottom = tower.yBottom;
    final collapsed = tower.collapsed;

    if (collapsed && phase >= 2 && towerIndex == 3) {
      // Completely collapsed tower - just rubble
      _drawRubblePile(canvas, cx - 35, bottom - 30, 70, 35, towerIndex * 13);
      return;
    }

    // Collapse adjustment for partially collapsed tower
    final drawTop = collapsed ? top + (bottom - top) * 0.35 : top;

    // Tower body - cylindrical shading
    final bodyGrad = ui.Gradient.linear(
      Offset(cx - towerRadius, 0),
      Offset(cx + towerRadius, 0),
      [
        const Color(0xFF484038),
        const Color(0xFF686058),
        const Color(0xFF787068),
        const Color(0xFF686058),
        const Color(0xFF3A3230),
      ],
      [0.0, 0.2, 0.45, 0.75, 1.0],
    );

    final bodyRect =
        Rect.fromLTWH(cx - towerRadius, drawTop, towerRadius * 2, bottom - drawTop);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(2)),
      Paint()..shader = bodyGrad,
    );

    // Brick texture on tower
    _drawTowerBricks(canvas, cx - towerRadius, drawTop, towerRadius * 2,
        bottom - drawTop);

    // Arrow slit windows on tower
    if (!collapsed) {
      _drawArrowSlit(canvas, cx, drawTop + (bottom - drawTop) * 0.30, phase,
          towerIndex * 2);
      _drawArrowSlit(canvas, cx, drawTop + (bottom - drawTop) * 0.55, phase,
          towerIndex * 2 + 1);
    } else {
      // One window on collapsed tower
      _drawArrowSlit(canvas, cx, drawTop + (bottom - drawTop) * 0.40, phase,
          towerIndex * 2);
    }

    // Conical roof (skip for collapsed towers)
    if (!collapsed) {
      _drawConicalRoof(canvas, cx, drawTop, towerRadius);

      // Tower crenellations (small ring at base of roof)
      _drawTowerCrenellations(canvas, cx, drawTop, towerRadius);
    } else {
      // Jagged top for collapsed tower
      _drawJaggedTop(canvas, cx, drawTop, towerRadius);
      // Rubble from collapsed top
      _drawRubblePile(
          canvas, cx - 40, bottom - 15, 80, 20, towerIndex * 7 + 3);
    }
  }

  void _drawTowerBricks(
      Canvas canvas, double x, double y, double w, double h) {
    final mortarPaint = Paint()
      ..color = const Color(0x15000000)
      ..strokeWidth = 0.6;

    for (double by = y + 4; by < y + h - 2; by += 8) {
      canvas.drawLine(Offset(x + 3, by), Offset(x + w - 3, by), mortarPaint);
    }
    final rng = math.Random(((x + y) * 7).toInt());
    int row = 0;
    for (double by = y + 4; by < y + h - 2; by += 8) {
      final offset = row.isEven ? 0.0 : 8.0;
      for (double bx = x + 4 + offset; bx < x + w - 4; bx += 16) {
        canvas.drawLine(
            Offset(bx, by), Offset(bx, by + 8), mortarPaint);
        // Occasional color variation
        if (rng.nextInt(5) == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(bx + 1, by + 1, 14, 6),
              const Radius.circular(0.5),
            ),
            Paint()..color = Color.fromARGB(8 + rng.nextInt(8), 80, 60, 40),
          );
        }
      }
      row++;
    }
  }

  void _drawConicalRoof(Canvas canvas, double cx, double towerTop, double radius) {
    final roofHeight = 40.0;
    final roofTop = towerTop - roofHeight;
    final overhang = 6.0;

    // Roof shape: triangle with slight curve
    final roofPath = Path()
      ..moveTo(cx, roofTop)
      ..quadraticBezierTo(
          cx + radius * 0.3, roofTop + roofHeight * 0.4,
          cx + radius + overhang, towerTop + 2)
      ..lineTo(cx - radius - overhang, towerTop + 2)
      ..quadraticBezierTo(
          cx - radius * 0.3, roofTop + roofHeight * 0.4,
          cx, roofTop)
      ..close();

    // Roof gradient (dark slate/blue-grey)
    final roofGrad = ui.Gradient.linear(
      Offset(cx - radius, 0),
      Offset(cx + radius, 0),
      [
        const Color(0xFF2A3040),
        const Color(0xFF4A5568),
        const Color(0xFF3A4555),
        const Color(0xFF252D3A),
      ],
      [0.0, 0.35, 0.65, 1.0],
    );
    canvas.drawPath(roofPath, Paint()..shader = roofGrad);

    // Roof ridge lines for tile detail
    final ridgePaint = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 0.6;
    for (double ry = roofTop + 8; ry < towerTop; ry += 6) {
      final t = (ry - roofTop) / roofHeight;
      final halfW = (radius + overhang) * t;
      canvas.drawLine(Offset(cx - halfW, ry), Offset(cx + halfW, ry), ridgePaint);
    }

    // Pointed tip ornament
    canvas.drawCircle(
      Offset(cx, roofTop - 2),
      2.5,
      Paint()..color = const Color(0xFFCCBB88),
    );
  }

  void _drawTowerCrenellations(
      Canvas canvas, double cx, double towerTop, double radius) {
    final crenH = 8.0;
    final crenW = 8.0;
    final crenY = towerTop - 2;

    final crenPaint = Paint()..color = const Color(0xFF5A5248);

    // Small crenellations in a row across the tower top
    for (double angle = -0.8; angle <= 0.8; angle += 0.35) {
      final px = cx + math.sin(angle) * (radius + 2);
      canvas.drawRect(
        Rect.fromLTWH(px - crenW / 2, crenY, crenW, crenH),
        crenPaint,
      );
    }
  }

  void _drawJaggedTop(Canvas canvas, double cx, double top, double radius) {
    final rng = math.Random((cx * 3 + top * 7).toInt());
    final jaggedPath = Path()..moveTo(cx - radius, top + 10);
    double x = cx - radius;
    while (x < cx + radius) {
      final jh = rng.nextDouble() * 16 + 4;
      jaggedPath.lineTo(x, top - jh + 10);
      x += 6 + rng.nextDouble() * 8;
      jaggedPath.lineTo(x, top + 10);
      x += 4;
    }
    jaggedPath.lineTo(cx + radius, top + 10);
    jaggedPath.close();

    canvas.drawPath(jaggedPath, Paint()..color = const Color(0xFF585048));
    canvas.drawPath(
      jaggedPath,
      Paint()
        ..color = const Color(0xFF2A2220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  // ---------------------------------------------------------------------------
  //  Arrow slit windows (narrow glowing)
  // ---------------------------------------------------------------------------

  void _drawArrowSlit(
      Canvas canvas, double cx, double cy, int phase, int windowIdx) {
    final slitW = 8.0;
    final slitH = 20.0;

    // Phase 1+: window index 3 broken (no light)
    final isBroken = (phase >= 1 && windowIdx == 3) ||
        (phase >= 2 && (windowIdx >= 3));

    // Dark recess
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: slitW + 4, height: slitH + 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF0A0805),
    );

    if (isBroken) {
      // Broken window - dark
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: slitW, height: slitH),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF080604),
      );
      return;
    }

    // Warm golden glow
    final glowGrad = ui.Gradient.radial(
      Offset(cx, cy),
      slitH * 0.8,
      [
        const Color(0xAAFFBB44),
        const Color(0x66FF9922),
        const Color(0x22FF7711),
        Colors.transparent,
      ],
      [0.0, 0.25, 0.5, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: slitW, height: slitH),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFFFFBB44),
    );
    // Outer glow halo
    canvas.drawCircle(
      Offset(cx, cy),
      slitH * 0.7,
      Paint()
        ..shader = glowGrad
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  // ---------------------------------------------------------------------------
  //  Central keep (main tower, tallest)
  // ---------------------------------------------------------------------------

  void _drawCentralKeep(Canvas canvas, int phase) {
    final keepCx = _s * 0.50;
    final keepWidth = _s * 0.22;
    final keepTop = _s * 0.08;
    final keepBottom = _s * 0.70;
    final keepLeft = keepCx - keepWidth / 2;

    // Phase 2: keep is partially destroyed
    final actualTop = phase >= 2 ? keepTop + _s * 0.06 : keepTop;

    // Keep body gradient
    final keepGrad = ui.Gradient.linear(
      Offset(keepLeft, 0),
      Offset(keepLeft + keepWidth, 0),
      [
        const Color(0xFF484038),
        const Color(0xFF686058),
        const Color(0xFF787068),
        const Color(0xFF686058),
        const Color(0xFF3A3230),
      ],
      [0.0, 0.2, 0.45, 0.75, 1.0],
    );

    if (phase < 2) {
      canvas.drawRect(
        Rect.fromLTWH(keepLeft, actualTop, keepWidth, keepBottom - actualTop),
        Paint()..shader = keepGrad,
      );
    } else {
      // Partially damaged keep - jagged top
      final keepPath = Path()
        ..moveTo(keepLeft, keepBottom)
        ..lineTo(keepLeft, actualTop + 10)
        ..lineTo(keepLeft + 8, actualTop + 4)
        ..lineTo(keepLeft + 16, actualTop + 12)
        ..lineTo(keepLeft + 24, actualTop)
        ..lineTo(keepLeft + 36, actualTop + 8)
        ..lineTo(keepLeft + 48, actualTop + 3)
        ..lineTo(keepLeft + 56, actualTop + 14)
        ..lineTo(keepLeft + 68, actualTop + 6)
        ..lineTo(keepLeft + 80, actualTop + 10)
        ..lineTo(keepLeft + keepWidth - 8, actualTop + 2)
        ..lineTo(keepLeft + keepWidth, actualTop + 16)
        ..lineTo(keepLeft + keepWidth, keepBottom)
        ..close();
      canvas.drawPath(keepPath, Paint()..shader = keepGrad);
    }

    // Brick texture on keep
    _drawStoneBricks(
        canvas, keepLeft, actualTop, keepWidth, keepBottom - actualTop, phase);

    // Large arched windows on keep
    _drawKeepWindow(canvas, keepCx, actualTop + (keepBottom - actualTop) * 0.20,
        18, 28, phase, 0);
    _drawKeepWindow(canvas, keepCx, actualTop + (keepBottom - actualTop) * 0.50,
        18, 28, phase, 1);
    _drawKeepWindow(canvas, keepCx - 28, actualTop + (keepBottom - actualTop) * 0.35,
        12, 22, phase, 2);
    _drawKeepWindow(canvas, keepCx + 28, actualTop + (keepBottom - actualTop) * 0.35,
        12, 22, phase, 3);

    // Keep crenellations at top
    if (phase < 2) {
      _drawKeepCrenellations(canvas, keepLeft, actualTop, keepWidth);
    }

    // Conical roof on keep (tallest - only in phase 0 and 1)
    if (phase == 0) {
      _drawKeepRoof(canvas, keepCx, actualTop, keepWidth / 2);
    } else if (phase == 1) {
      // Slightly damaged roof
      _drawKeepRoof(canvas, keepCx, actualTop, keepWidth / 2);
    }
  }

  void _drawKeepWindow(Canvas canvas, double cx, double cy, double w, double h,
      int phase, int idx) {
    // Phase 2: most windows dark with fire glow
    final isDark = phase >= 2 && idx != 0;
    final hasFireGlow = phase >= 2;

    // Arched window frame
    final framePath = Path();
    final frameRect = Rect.fromCenter(
        center: Offset(cx, cy + h * 0.15), width: w + 6, height: h * 0.7 + 6);
    framePath.addRect(frameRect);
    // Arch top
    framePath.addOval(Rect.fromCenter(
        center: Offset(cx, cy - h * 0.15), width: w + 6, height: w + 6));
    canvas.drawPath(framePath, Paint()..color = const Color(0xFF2A2220));

    // Window interior
    final winPath = Path();
    final winRect = Rect.fromCenter(
        center: Offset(cx, cy + h * 0.15), width: w, height: h * 0.7);
    winPath.addRect(winRect);
    winPath.addOval(
        Rect.fromCenter(center: Offset(cx, cy - h * 0.15), width: w, height: w));

    if (isDark) {
      canvas.drawPath(winPath, Paint()..color = const Color(0xFF0A0805));
      if (hasFireGlow) {
        // Red/orange fire glow from inside
        final fireGrad = ui.Gradient.radial(
          Offset(cx, cy),
          w * 1.5,
          [
            const Color(0x66FF4400),
            const Color(0x33FF2200),
            Colors.transparent,
          ],
          [0.0, 0.4, 1.0],
        );
        canvas.drawCircle(
          Offset(cx, cy),
          w * 1.2,
          Paint()
            ..shader = fireGrad
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    } else {
      // Warm golden glow
      final glowGrad = ui.Gradient.radial(
        Offset(cx, cy - h * 0.1),
        h * 0.7,
        [
          const Color(0xCCFFCC55),
          const Color(0x88FFAA33),
          const Color(0x44FF8811),
          Colors.transparent,
        ],
        [0.0, 0.3, 0.6, 1.0],
      );
      canvas.drawPath(winPath, Paint()..color = const Color(0xFFFFBB44));
      canvas.drawCircle(
        Offset(cx, cy),
        h * 0.6,
        Paint()
          ..shader = glowGrad
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // Window mullion (cross bar)
      canvas.drawLine(
        Offset(cx, cy - h * 0.35),
        Offset(cx, cy + h * 0.45),
        Paint()
          ..color = const Color(0x99332211)
          ..strokeWidth = 2.0,
      );
      canvas.drawLine(
        Offset(cx - w * 0.4, cy + h * 0.05),
        Offset(cx + w * 0.4, cy + h * 0.05),
        Paint()
          ..color = const Color(0x99332211)
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawKeepCrenellations(
      Canvas canvas, double keepLeft, double keepTop, double keepWidth) {
    final crenW = 10.0;
    final crenH = 10.0;
    final crenY = keepTop - crenH;

    final crenPaint = Paint()..color = const Color(0xFF5A5248);

    for (double cx = keepLeft + 2; cx < keepLeft + keepWidth - crenW; cx += crenW * 2) {
      canvas.drawRect(
        Rect.fromLTWH(cx, crenY, crenW, crenH + 2),
        crenPaint,
      );
      canvas.drawLine(
        Offset(cx + 1, crenY),
        Offset(cx + crenW - 1, crenY),
        Paint()
          ..color = const Color(0x22FFFFFF)
          ..strokeWidth = 0.8,
      );
    }
  }

  void _drawKeepRoof(Canvas canvas, double cx, double keepTop, double radius) {
    final roofHeight = 50.0;
    final roofTop = keepTop - roofHeight;

    final roofPath = Path()
      ..moveTo(cx, roofTop)
      ..quadraticBezierTo(
          cx + radius * 0.4, roofTop + roofHeight * 0.35,
          cx + radius + 8, keepTop + 2)
      ..lineTo(cx - radius - 8, keepTop + 2)
      ..quadraticBezierTo(
          cx - radius * 0.4, roofTop + roofHeight * 0.35,
          cx, roofTop)
      ..close();

    final roofGrad = ui.Gradient.linear(
      Offset(cx - radius, 0),
      Offset(cx + radius, 0),
      [
        const Color(0xFF1E2838),
        const Color(0xFF3A4A5C),
        const Color(0xFF4A5A6C),
        const Color(0xFF2A3A4C),
        const Color(0xFF1A2535),
      ],
      [0.0, 0.25, 0.45, 0.7, 1.0],
    );
    canvas.drawPath(roofPath, Paint()..shader = roofGrad);

    // Tile lines
    final tilePaint = Paint()
      ..color = const Color(0x15000000)
      ..strokeWidth = 0.5;
    for (double ry = roofTop + 6; ry < keepTop; ry += 5) {
      final t = (ry - roofTop) / roofHeight;
      final halfW = (radius + 8) * t;
      canvas.drawLine(Offset(cx - halfW, ry), Offset(cx + halfW, ry), tilePaint);
    }

    // Spire tip
    canvas.drawCircle(
      Offset(cx, roofTop - 3),
      3.5,
      Paint()..color = const Color(0xFFDDCC88),
    );
    // Spire pole
    canvas.drawLine(
      Offset(cx, roofTop - 6),
      Offset(cx, roofTop + 4),
      Paint()
        ..color = const Color(0xFFBBAA77)
        ..strokeWidth = 2.0,
    );
  }

  // ---------------------------------------------------------------------------
  //  Gate with arch and portcullis
  // ---------------------------------------------------------------------------

  void _drawGate(Canvas canvas, int phase) {
    final gateW = _s * 0.18;
    final gateH = _s * 0.22;
    final gateCx = _s * 0.50;
    final gateLeft = gateCx - gateW / 2;
    final gateBottom = _s * 0.82;
    final gateTop = gateBottom - gateH;
    final archRadius = gateW / 2;

    // Gate stone surround (arch frame)
    final framePath = Path()
      ..moveTo(gateLeft - 8, gateBottom + 2)
      ..lineTo(gateLeft - 8, gateTop + archRadius)
      ..arcTo(
        Rect.fromLTWH(
            gateLeft - 8, gateTop - 8, gateW + 16, archRadius * 2 + 8),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(gateLeft + gateW + 8, gateBottom + 2)
      ..close();

    canvas.drawPath(
      framePath,
      Paint()..color = const Color(0xFF4A4238),
    );
    // Stone texture on frame
    final frameStone = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 0.6;
    for (double fy = gateTop; fy < gateBottom; fy += 7) {
      canvas.drawLine(
          Offset(gateLeft - 7, fy), Offset(gateLeft - 2, fy), frameStone);
      canvas.drawLine(Offset(gateLeft + gateW + 2, fy),
          Offset(gateLeft + gateW + 7, fy), frameStone);
    }

    // Keystone at arch apex
    final keystonePath = Path()
      ..moveTo(gateCx - 6, gateTop - 6)
      ..lineTo(gateCx + 6, gateTop - 6)
      ..lineTo(gateCx + 5, gateTop + 6)
      ..lineTo(gateCx - 5, gateTop + 6)
      ..close();
    canvas.drawPath(keystonePath, Paint()..color = const Color(0xFF6A6258));

    // Gate interior (deep dark)
    final interiorPath = Path()
      ..moveTo(gateLeft, gateBottom)
      ..lineTo(gateLeft, gateTop + archRadius)
      ..arcTo(
        Rect.fromLTWH(gateLeft, gateTop, gateW, archRadius * 2),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(gateLeft + gateW, gateBottom)
      ..close();

    final interiorGrad = ui.Gradient.linear(
      Offset(0, gateTop),
      Offset(0, gateBottom),
      [
        const Color(0xFF0A0604),
        const Color(0xFF120C08),
        const Color(0xFF080502),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawPath(interiorPath, Paint()..shader = interiorGrad);

    // Warm light spilling from gate interior
    final gateGlow = ui.Gradient.radial(
      Offset(gateCx, gateBottom - gateH * 0.3),
      gateW * 0.6,
      [
        const Color(0x33FFAA33),
        const Color(0x18FF8811),
        Colors.transparent,
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawPath(
      interiorPath,
      Paint()..shader = gateGlow,
    );

    // Portcullis grid
    if (phase < 2) {
      final portPaint = Paint()
        ..color = const Color(0x66555555)
        ..strokeWidth = 2.0;
      final portThin = Paint()
        ..color = const Color(0x44555555)
        ..strokeWidth = 1.0;

      // Vertical bars
      for (double gx = gateLeft + 6; gx < gateLeft + gateW - 4; gx += 10) {
        // Clip to arch shape (approximate)
        final dx = (gx - gateCx).abs();
        final archY = gateTop + archRadius - math.sqrt(
            math.max(0, archRadius * archRadius - dx * dx));
        canvas.drawLine(
          Offset(gx, archY + 4),
          Offset(gx, gateBottom),
          portPaint,
        );
      }
      // Horizontal bars
      for (double gy = gateTop + archRadius + 4;
          gy < gateBottom;
          gy += 10) {
        canvas.drawLine(
          Offset(gateLeft + 4, gy),
          Offset(gateLeft + gateW - 4, gy),
          portThin,
        );
      }

      // Metal studs at intersections
      for (double gx = gateLeft + 6; gx < gateLeft + gateW - 4; gx += 20) {
        for (double gy = gateTop + archRadius + 8; gy < gateBottom; gy += 20) {
          canvas.drawCircle(
            Offset(gx, gy),
            1.5,
            Paint()..color = const Color(0x55888888),
          );
        }
      }
    } else {
      // Phase 2: broken gate - portcullis partially raised/bent
      final brokenPort = Paint()
        ..color = const Color(0x55666666)
        ..strokeWidth = 2.0;
      // Only partial vertical bars remaining, bent
      for (double gx = gateLeft + 8; gx < gateLeft + gateW - 6; gx += 12) {
        if (gx > gateCx - 10 && gx < gateCx + 10) continue; // Gap in middle
        final bendY = gateBottom - 20 - (gx - gateCx).abs() * 0.3;
        canvas.drawLine(
          Offset(gx, gateTop + archRadius + 10),
          Offset(gx + 2, bendY),
          brokenPort,
        );
      }

      // Fire glow from inside through broken gate
      final fireGlow = ui.Gradient.radial(
        Offset(gateCx, gateBottom - gateH * 0.4),
        gateW * 0.8,
        [
          const Color(0x55FF5500),
          const Color(0x33FF3300),
          Colors.transparent,
        ],
        [0.0, 0.4, 1.0],
      );
      canvas.drawCircle(
        Offset(gateCx, gateBottom - gateH * 0.3),
        gateW * 0.7,
        Paint()
          ..shader = fireGlow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Banner / coat of arms on central keep
  // ---------------------------------------------------------------------------

  void _drawBanner(Canvas canvas, int phase) {
    if (phase >= 2) return; // No banner in ruined state

    final bx = _s * 0.42;
    final by = _s * 0.36;
    final bw = _s * 0.16;
    final bh = _s * 0.14;

    // Banner pennant shape
    final bannerPath = Path()
      ..moveTo(bx, by)
      ..lineTo(bx + bw, by)
      ..lineTo(bx + bw, by + bh * 0.82)
      ..lineTo(bx + bw * 0.5, by + bh)
      ..lineTo(bx, by + bh * 0.82)
      ..close();

    // Deep crimson banner
    final bannerGrad = ui.Gradient.linear(
      Offset(bx, by),
      Offset(bx, by + bh),
      [const Color(0xCC9B1515), const Color(0xCC6B0C0C)],
    );
    canvas.drawPath(bannerPath, Paint()..shader = bannerGrad);

    // Gold border
    canvas.drawPath(
      bannerPath,
      Paint()
        ..color = const Color(0x88DDBB44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Banner rod at top
    canvas.drawLine(
      Offset(bx - 4, by),
      Offset(bx + bw + 4, by),
      Paint()
        ..color = const Color(0xFFBBAA77)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Shield emblem
    final cx = bx + bw * 0.5;
    final cy = by + bh * 0.40;
    final sw = bw * 0.40;
    final sh = bh * 0.35;
    final shieldPath = Path()
      ..moveTo(cx - sw * 0.5, cy - sh * 0.5)
      ..lineTo(cx + sw * 0.5, cy - sh * 0.5)
      ..lineTo(cx + sw * 0.5, cy + sh * 0.1)
      ..quadraticBezierTo(cx, cy + sh * 0.55, cx - sw * 0.5, cy + sh * 0.1)
      ..close();
    canvas.drawPath(shieldPath, Paint()..color = const Color(0x99DDBB44));

    // Shield cross
    canvas.drawLine(
      Offset(cx, cy - sh * 0.35),
      Offset(cx, cy + sh * 0.30),
      Paint()
        ..color = const Color(0x668B1111)
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      Offset(cx - sw * 0.35, cy - sh * 0.05),
      Offset(cx + sw * 0.35, cy - sh * 0.05),
      Paint()
        ..color = const Color(0x668B1111)
        ..strokeWidth = 2.5,
    );

    // Phase 1: banner slightly torn
    if (phase >= 1) {
      // Tear marks
      canvas.drawLine(
        Offset(bx + bw * 0.7, by + bh * 0.5),
        Offset(bx + bw * 0.85, by + bh * 0.75),
        Paint()
          ..color = const Color(0xFF2A1A10)
          ..strokeWidth = 2.5,
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  Flags on towers
  // ---------------------------------------------------------------------------

  void _drawFlags(Canvas canvas, int phase) {
    // Flag on front-left tower
    _drawSingleFlag(
        canvas, _s * 0.15, _s * 0.22 - 40 - 6, const Color(0xFFCC2222), phase,
        torn: false, skip: false);

    // Flag on front-right tower
    _drawSingleFlag(canvas, _s * 0.85, _s * 0.22 - 40 - 6,
        const Color(0xFFCC2222), phase,
        torn: phase >= 1, skip: phase >= 2);

    // Flag on central keep (tallest)
    if (phase == 0) {
      _drawSingleFlag(canvas, _s * 0.50, _s * 0.08 - 50 - 10,
          const Color(0xFFDDBB33), phase,
          torn: false, skip: false, large: true);
    }
  }

  void _drawSingleFlag(
      Canvas canvas, double x, double y, Color color, int phase,
      {bool torn = false, bool skip = false, bool large = false}) {
    if (skip) return;

    final flagW = large ? 28.0 : 20.0;
    final flagH = large ? 14.0 : 10.0;

    // Pole
    canvas.drawLine(
      Offset(x, y + 24),
      Offset(x, y - 2),
      Paint()
        ..color = const Color(0xFFAAAAAA)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    // Pole cap
    canvas.drawCircle(
      Offset(x, y - 3),
      2.5,
      Paint()..color = const Color(0xFFDDCC99),
    );

    if (torn) {
      // Tattered flag
      final flagPath = Path()
        ..moveTo(x, y - 2)
        ..lineTo(x + flagW * 0.7, y + 1)
        ..lineTo(x + flagW * 0.5, y + 3)
        ..lineTo(x + flagW * 0.65, y + flagH * 0.5)
        ..lineTo(x + flagW * 0.4, y + flagH * 0.7)
        ..lineTo(x, y + flagH * 0.8)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = color.withAlpha(160));
    } else {
      // Full waving flag
      final flagPath = Path()
        ..moveTo(x, y - 2)
        ..quadraticBezierTo(x + flagW * 0.4, y - 4, x + flagW, y + 2)
        ..lineTo(x + flagW * 0.95, y + flagH)
        ..quadraticBezierTo(x + flagW * 0.5, y + flagH - 2, x, y + flagH - 1)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = color);
      // Highlight
      final highlightPath = Path()
        ..moveTo(x + 2, y)
        ..quadraticBezierTo(x + flagW * 0.3, y - 2, x + flagW * 0.6, y + 2)
        ..lineTo(x + flagW * 0.5, y + flagH * 0.5)
        ..quadraticBezierTo(x + flagW * 0.2, y + flagH * 0.4, x + 2, y + flagH * 0.5)
        ..close();
      canvas.drawPath(highlightPath, Paint()..color = const Color(0x33FFFFFF));
    }
  }

  // ---------------------------------------------------------------------------
  //  Rubble pile helper
  // ---------------------------------------------------------------------------

  void _drawRubblePile(
      Canvas canvas, double x, double y, double w, double h, int seed) {
    final rng = math.Random(seed);
    final colors = [
      const Color(0xFF585048),
      const Color(0xFF484038),
      const Color(0xFF686058),
      const Color(0xFF3A3230),
      const Color(0xFF706860),
    ];

    for (int i = 0; i < 20; i++) {
      final rx = x + rng.nextDouble() * w;
      final ry = y + rng.nextDouble() * h;
      final rw = 4.0 + rng.nextDouble() * 12.0;
      final rh = 3.0 + rng.nextDouble() * 8.0;
      final color = colors[rng.nextInt(colors.length)];

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rx, ry, rw, rh),
          Radius.circular(1.0 + rng.nextDouble() * 2.0),
        ),
        Paint()..color = color,
      );
    }

    // Dust cloud around rubble
    canvas.drawOval(
      Rect.fromLTWH(x - 5, y + h * 0.3, w + 10, h * 0.8),
      Paint()
        ..color = const Color(0x18584838)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  // ---------------------------------------------------------------------------
  //  Damage Phase 1 -- cracks, minor damage, smoke wisps
  // ---------------------------------------------------------------------------

  void _drawDamagePhase1(Canvas canvas) {
    final crackPaint = Paint()
      ..color = const Color(0x99000000)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final crackThin = Paint()
      ..color = const Color(0x77000000)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final crackGlowPaint = Paint()
      ..color = const Color(0x22FF8844)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Primary crack on left wall
    final crack1 = [
      Offset(_s * 0.28, _s * 0.38),
      Offset(_s * 0.32, _s * 0.48),
      Offset(_s * 0.30, _s * 0.58),
      Offset(_s * 0.33, _s * 0.68),
    ];
    _drawCrackLine(canvas, crack1, crackPaint, crackGlowPaint);

    // Branch crack
    canvas.drawLine(
        Offset(_s * 0.32, _s * 0.48), Offset(_s * 0.38, _s * 0.52), crackThin);
    canvas.drawLine(
        Offset(_s * 0.38, _s * 0.52), Offset(_s * 0.41, _s * 0.58), crackThin);

    // Secondary crack upper right
    canvas.drawLine(
        Offset(_s * 0.63, _s * 0.36), Offset(_s * 0.60, _s * 0.44), crackThin);
    canvas.drawLine(
        Offset(_s * 0.60, _s * 0.44), Offset(_s * 0.65, _s * 0.50), crackThin);

    // Dust marks near cracks
    final dustPaint = Paint()
      ..color = const Color(0x1A443322)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(_s * 0.32, _s * 0.48), 10, dustPaint);
    canvas.drawCircle(Offset(_s * 0.30, _s * 0.58), 8, dustPaint);

    // Small debris fallen from wall
    _drawSmallDebris(canvas, _s * 0.25, _s * 0.80, 8, 21);

    // Light smoke wisps from damaged areas
    _drawSmokeWisps(canvas, _s * 0.82, _s * 0.15, 3, 0.4, 55);
  }

  // ---------------------------------------------------------------------------
  //  Damage Phase 2 -- heavy destruction, fire, heavy smoke
  // ---------------------------------------------------------------------------

  void _drawDamagePhase2(Canvas canvas) {
    final crackPaint = Paint()
      ..color = const Color(0xBB000000)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    final crackGlowPaint = Paint()
      ..color = const Color(0x44FF6622)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final crackMed = Paint()
      ..color = const Color(0x99000000)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Major crack network across front wall
    final crack1 = [
      Offset(_s * 0.55, _s * 0.34),
      Offset(_s * 0.60, _s * 0.44),
      Offset(_s * 0.54, _s * 0.55),
      Offset(_s * 0.58, _s * 0.68),
    ];
    _drawCrackLine(canvas, crack1, crackPaint, crackGlowPaint);

    // Branches
    canvas.drawLine(
        Offset(_s * 0.60, _s * 0.44), Offset(_s * 0.70, _s * 0.42), crackMed);
    canvas.drawLine(
        Offset(_s * 0.54, _s * 0.55), Offset(_s * 0.46, _s * 0.52), crackMed);
    canvas.drawLine(
        Offset(_s * 0.46, _s * 0.52), Offset(_s * 0.42, _s * 0.44), crackMed);

    // Cracks on base platform
    canvas.drawLine(
        Offset(_s * 0.20, _s * 0.84), Offset(_s * 0.35, _s * 0.87), crackMed);
    canvas.drawLine(
        Offset(_s * 0.62, _s * 0.83), Offset(_s * 0.78, _s * 0.86), crackMed);

    // Fire glow from cracks
    final fireGlow = Paint()
      ..color = const Color(0x55FF5511)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(_s * 0.60, _s * 0.44), 16, fireGlow);
    canvas.drawCircle(Offset(_s * 0.54, _s * 0.55), 14, fireGlow);
    canvas.drawCircle(Offset(_s * 0.58, _s * 0.68), 12, fireGlow);

    // Ember-like fire lines along cracks
    final fireLine = Paint()
      ..color = const Color(0x66FF8833)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(_s * 0.56, _s * 0.36), Offset(_s * 0.60, _s * 0.44), fireLine);
    canvas.drawLine(
        Offset(_s * 0.60, _s * 0.44), Offset(_s * 0.54, _s * 0.55), fireLine);

    // Scorch marks
    final scorchPaint = Paint()
      ..color = const Color(0x33221100)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(_s * 0.38, _s * 0.48), 18, scorchPaint);
    canvas.drawCircle(Offset(_s * 0.66, _s * 0.50), 16, scorchPaint);

    // Fire glow emanating from gaps in walls
    _drawFireGlow(canvas, _s * 0.78, _s * 0.38, 20.0);
    _drawFireGlow(canvas, _s * 0.24, _s * 0.42, 16.0);

    // Heavy smoke wisps
    _drawSmokeWisps(canvas, _s * 0.30, _s * 0.06, 5, 0.8, 88);
    _drawSmokeWisps(canvas, _s * 0.55, _s * 0.02, 6, 0.9, 123);
    _drawSmokeWisps(canvas, _s * 0.75, _s * 0.10, 4, 0.7, 77);

    // Scattered debris at base
    _drawSmallDebris(canvas, _s * 0.10, _s * 0.82, 15, 42);
    _drawSmallDebris(canvas, _s * 0.65, _s * 0.80, 12, 66);

    // Embers floating up (small bright dots)
    _drawEmbers(canvas, 99);
  }

  // ---------------------------------------------------------------------------
  //  Damage helper methods
  // ---------------------------------------------------------------------------

  void _drawCrackLine(Canvas canvas, List<Offset> points, Paint crackPaint,
      Paint glowPaint) {
    for (int i = 0; i < points.length - 1; i++) {
      // Glow underneath
      canvas.drawLine(points[i], points[i + 1], glowPaint);
      // Crack line on top
      canvas.drawLine(points[i], points[i + 1], crackPaint);
    }
  }

  void _drawSmokeWisps(Canvas canvas, double startX, double startY,
      int count, double opacity, int seed) {
    final rng = math.Random(seed);
    for (int i = 0; i < count; i++) {
      final sx = startX + rng.nextDouble() * _s * 0.15 - _s * 0.075;
      final sy = startY + rng.nextDouble() * _s * 0.10;
      final smokeSize = 10.0 + rng.nextDouble() * 16.0;
      final alpha = ((30 + rng.nextInt(30)) * opacity).round().clamp(0, 255);

      // Outer diffuse smoke
      canvas.drawCircle(
        Offset(sx, sy),
        smokeSize + 8,
        Paint()
          ..color = Color.fromARGB((alpha * 0.3).round(), 35, 35, 40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Core smoke
      canvas.drawCircle(
        Offset(sx, sy),
        smokeSize,
        Paint()
          ..color = Color.fromARGB(alpha, 50, 48, 52)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _drawFireGlow(Canvas canvas, double x, double y, double radius) {
    final fireGrad = ui.Gradient.radial(
      Offset(x, y),
      radius,
      [
        const Color(0x66FF6622),
        const Color(0x33FF4411),
        const Color(0x11FF2200),
        Colors.transparent,
      ],
      [0.0, 0.3, 0.6, 1.0],
    );
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()
        ..shader = fireGrad
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawSmallDebris(
      Canvas canvas, double startX, double startY, int count, int seed) {
    final rng = math.Random(seed);
    final colors = [
      const Color(0xFF585048),
      const Color(0xFF484038),
      const Color(0xFF686058),
      const Color(0xFF3A3230),
    ];
    for (int i = 0; i < count; i++) {
      final dx = startX + rng.nextDouble() * _s * 0.12;
      final dy = startY + rng.nextDouble() * _s * 0.04;
      final ds = 2.0 + rng.nextDouble() * 5.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, dy, ds, ds * 0.7),
          const Radius.circular(1.0),
        ),
        Paint()..color = colors[rng.nextInt(colors.length)],
      );
    }
  }

  void _drawEmbers(Canvas canvas, int seed) {
    final rng = math.Random(seed);
    for (int i = 0; i < 12; i++) {
      final ex = _s * 0.15 + rng.nextDouble() * _s * 0.70;
      final ey = _s * 0.05 + rng.nextDouble() * _s * 0.60;
      final es = 1.5 + rng.nextDouble() * 2.5;

      canvas.drawCircle(
        Offset(ex, ey),
        es,
        Paint()
          ..color = Color.fromARGB(
            80 + rng.nextInt(80),
            255,
            100 + rng.nextInt(100),
            0,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }
}

// ---------------------------------------------------------------------------
//  Internal tower definition helper
// ---------------------------------------------------------------------------

class _TowerDef {
  final double centerX;
  final double yTop;
  final double yBottom;
  final bool collapsed;

  const _TowerDef(this.centerX, this.yTop, this.yBottom, this.collapsed);
}
