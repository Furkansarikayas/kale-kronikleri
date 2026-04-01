import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../map/biome_data.dart';

class ParallaxBackground extends Component with HasGameReference {
  final BiomeData biome;
  double _time = 0;

  // World dimensions — wide enough for ultrawide screens (21:9 etc.)
  static const double _w = 1400.0;
  // X offset so the wider background is centered around the grid (768 wide)
  static const double _xOff = -316.0; // (768 - 1400) / 2
  static const double _gridH = 540.0;

  // Extended sky area above the grid (visible via camera offset)
  static const double _skyExtension = 90.0;
  // Total rendering height
  static const double _totalH = _gridH + _skyExtension;
  // Top of rendering area in world coordinates
  static const double _topY = -_skyExtension;

  // Cached biome background image (from Leonardo assets)
  ui.Image? _biomeBgImage;

  // Cached mountain images
  ui.Image? _farMountainImage;
  ui.Image? _midSilhouetteImage;

  // Stars — placed in sky area (above grid)
  late final List<_Star> _stars;

  // Ambient particles
  late final List<_Particle> _particles;

  // Moon position — in the sky strip above grid (relative to grid, not bg width)
  static const double _moonX = 630.0; // near right side of 768-wide grid
  static const double _moonY = -_skyExtension * 0.35;
  static const double _moonRadius = 16.0;

  ParallaxBackground({required this.biome}) {
    priority = -10;
  }

  @override
  Future<void> onLoad() async {
    // Try loading biome background PNG
    _biomeBgImage = await _tryLoadBiomeBg();

    final rng = math.Random(42);

    // Generate stars distributed across the sky area (above grid + top portion of grid)
    // Stars range from _topY to about 30% into the grid, spread over full width
    _stars = List.generate(50, (i) => _Star(
      x: _xOff + rng.nextDouble() * _w,
      y: _topY + rng.nextDouble() * (_skyExtension + _gridH * 0.35),
      size: 0.5 + rng.nextDouble() * 1.8,
      phase: rng.nextDouble() * math.pi * 2,
      speed: 0.5 + rng.nextDouble() * 1.5,
    ));

    // Generate ambient particles (30 particles, biome-specific)
    _particles = List.generate(30, (i) => _Particle(
      x: _xOff + rng.nextDouble() * _w,
      y: rng.nextDouble() * _gridH, // particles stay in grid area
      size: 0.8 + rng.nextDouble() * 2.0,
      speedX: 0.2 + rng.nextDouble() * 0.6,
      speedY: biome.type == BiomeType.snow
          ? 0.5 + rng.nextDouble() * 1.0
          : 0.2 + rng.nextDouble() * 0.5,
      phase: rng.nextDouble() * math.pi * 2,
    ));

    // Cache mountain layers as images
    // Mountains are in the grid area (y=0 to _gridH) but peaks reach upward
    _farMountainImage = await _generateMountainImage(
      rng: math.Random(101),
      baseY: _gridH * 0.5,
      peakMinHeight: 50,
      peakMaxHeight: 120,
      peakCount: 8,
      color: Color.lerp(biome.skyBottom, const Color(0xFF1A2A3A), 0.4)!,
    );

    _midSilhouetteImage = await _generateMountainImage(
      rng: math.Random(202),
      baseY: _gridH * 0.65,
      peakMinHeight: 25,
      peakMaxHeight: 70,
      peakCount: 12,
      color: Color.lerp(biome.skyBottom, const Color(0xFF0A1520), 0.3)!,
    );
  }

  Future<ui.Image?> _tryLoadBiomeBg() async {
    try {
      final path = 'assets/images/backgrounds/${biome.type.name}_bg.webp';
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _generateMountainImage({
    required math.Random rng,
    required double baseY,
    required double peakMinHeight,
    required double peakMaxHeight,
    required int peakCount,
    required Color color,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final path = Path();
    path.moveTo(0, _gridH);
    path.lineTo(0, baseY);

    final segmentWidth = _w / peakCount;
    for (int i = 0; i <= peakCount; i++) {
      final x = i * segmentWidth;
      final peakHeight = peakMinHeight + rng.nextDouble() * (peakMaxHeight - peakMinHeight);
      final peakY = baseY - peakHeight;

      if (i == 0) {
        path.lineTo(0, peakY + peakHeight * 0.5);
      }

      final cpX = x + segmentWidth * 0.5;
      final nextX = (i + 1) * segmentWidth;
      final nextPeakHeight = peakMinHeight + rng.nextDouble() * (peakMaxHeight - peakMinHeight);
      final nextBaseY = baseY - nextPeakHeight * 0.3;

      path.quadraticBezierTo(cpX, peakY, math.min(nextX, _w), nextBaseY);
    }

    path.lineTo(_w, _gridH);
    path.close();

    canvas.drawPath(path, Paint()..color = color);

    final picture = recorder.endRecording();
    return picture.toImage(_w.toInt(), _gridH.toInt());
  }

  @override
  void update(double dt) {
    _time += dt;

    // Update particle positions
    final xEnd = _xOff + _w;
    for (final p in _particles) {
      if (biome.type == BiomeType.snow) {
        p.y += p.speedY * dt * 30;
        p.x += math.sin(_time * p.speedX + p.phase) * dt * 10;
        if (p.y > _gridH) {
          p.y = -5;
          p.x = _xOff + math.Random().nextDouble() * _w;
        }
      } else {
        p.x += p.speedX * dt * 8;
        p.y += math.sin(_time * p.speedY * 2 + p.phase) * dt * 6;
        if (p.x > xEnd) p.x = _xOff;
        if (p.x < _xOff) p.x = xEnd;
        if (p.y > _gridH) p.y = _gridH;
        if (p.y < 0) p.y = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_biomeBgImage != null) {
      // Draw the Leonardo background image, scaled to cover the full area
      final src = Rect.fromLTWH(0, 0, _biomeBgImage!.width.toDouble(), _biomeBgImage!.height.toDouble());
      final dst = Rect.fromLTWH(_xOff - 10, _topY - 10, _w + 20, _totalH + 20);
      canvas.drawImageRect(_biomeBgImage!, src, dst, Paint()..filterQuality = FilterQuality.medium);
      // Still draw fog, particles, and vignette on top for atmosphere
      _renderFog(canvas);
      _renderParticles(canvas);
      _renderVignette(canvas);
    } else {
      // Procedural fallback
      _renderSkyGradient(canvas);
      _renderStars(canvas);
      _renderMoon(canvas);
      _renderFarMountains(canvas);
      _renderMidSilhouettes(canvas);
      _renderFog(canvas);
      _renderParticles(canvas);
      _renderVignette(canvas);
    }
  }

  void _renderSkyGradient(Canvas canvas) {
    // Draw sky from _topY (above grid) all the way down to _gridH + 20
    // Extra wide to cover widescreen displays
    final grad = ui.Gradient.linear(
      Offset(0, _topY - 10),
      Offset(0, _gridH + 20),
      [biome.skyTop, biome.skyBottom],
      [0.0, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(_xOff - 10, _topY - 10, _w + 20, _totalH + 20),
      Paint()..shader = grad,
    );
  }

  void _renderStars(Canvas canvas) {
    for (final s in _stars) {
      final alpha = (math.sin(_time * s.speed + s.phase) * 0.5 + 0.5);
      final a = (alpha * 255).round().clamp(80, 255);

      // Soft glow — bigger and brighter
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.size * 3.5,
        Paint()..color = Color.fromARGB((a * 0.25).round(), 200, 220, 255),
      );
      // Bright core
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.size,
        Paint()..color = Color.fromARGB(a, 255, 255, 255),
      );
    }
  }

  void _renderMoon(Canvas canvas) {
    // Outer glow — larger for more dramatic effect
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_moonX, _moonY),
        _moonRadius * 5,
        [
          const Color(0x25EEEEFF),
          const Color(0x0ACCCCDD),
          Colors.transparent,
        ],
        [0.0, 0.35, 1.0],
      );
    canvas.drawCircle(
      const Offset(_moonX, _moonY),
      _moonRadius * 5,
      glowPaint,
    );

    // Moon body
    final moonPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_moonX - 3, _moonY - 3),
        _moonRadius,
        [
          const Color(0xFFEEEEDD),
          const Color(0xFFCCCCBB),
          const Color(0xFFAAAA99),
        ],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(
      const Offset(_moonX, _moonY),
      _moonRadius,
      moonPaint,
    );

    // Crescent shadow (dark side of moon)
    canvas.drawCircle(
      const Offset(_moonX + 5, _moonY - 2),
      _moonRadius * 0.85,
      Paint()..color = Color.lerp(biome.skyTop, const Color(0xFF000000), 0.5)!,
    );
  }

  void _renderFarMountains(Canvas canvas) {
    if (_farMountainImage != null) {
      canvas.drawImage(_farMountainImage!, Offset(_xOff, 0), Paint());
    }
  }

  void _renderMidSilhouettes(Canvas canvas) {
    if (_midSilhouetteImage != null) {
      canvas.drawImage(_midSilhouetteImage!, Offset(_xOff, 0), Paint());
    }
  }

  void _renderFog(Canvas canvas) {
    final fogGrad = ui.Gradient.linear(
      Offset(0, _gridH * 0.6),
      Offset(0, _gridH),
      [Colors.transparent, biome.fogColor],
    );
    canvas.drawRect(
      Rect.fromLTWH(_xOff, _gridH * 0.6, _w, _gridH * 0.4),
      Paint()..shader = fogGrad,
    );
  }

  void _renderParticles(Canvas canvas) {
    final particleColor = _getParticleColor();

    for (final p in _particles) {
      final alpha = (math.sin(_time * 1.5 + p.phase) * 0.5 + 0.5);
      final a = (alpha * 80).round().clamp(10, 80);

      final glowColor = Color((particleColor & 0x00FFFFFF) | ((a * 0.3).round() << 24));
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * 3,
        Paint()..color = glowColor,
      );

      final coreColor = Color((particleColor & 0x00FFFFFF) | (a << 24));
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size,
        Paint()..color = coreColor,
      );
    }
  }

  int _getParticleColor() {
    switch (biome.type) {
      case BiomeType.forest:
        return 0xFFAADD44; // green fireflies
      case BiomeType.desert:
        return 0xFFDDBB88; // sand dust
      case BiomeType.snow:
        return 0xFFDDEEFF; // snowflakes
      case BiomeType.volcano:
        return 0xFFFF6600; // orange sparks
      case BiomeType.dark:
        return 0xFF8844FF; // purple energy orbs
    }
  }

  void _renderVignette(Canvas canvas) {
    // Top edge (from sky area)
    canvas.drawRect(
      Rect.fromLTWH(_xOff, _topY, _w, 50),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, _topY),
          Offset(0, _topY + 50),
          [const Color(0x60000000), Colors.transparent],
        ),
    );
    // Bottom edge
    canvas.drawRect(
      Rect.fromLTWH(_xOff, _gridH - 30, _w, 30),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, _gridH - 30),
          Offset(0, _gridH),
          [Colors.transparent, const Color(0x40000000)],
        ),
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;

  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });
}

class _Particle {
  double x;
  double y;
  final double size;
  final double speedX;
  final double speedY;
  final double phase;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.phase,
  });
}
