import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../map/biome_data.dart';

class ParallaxBackground extends Component with HasGameReference {
  final BiomeData biome;
  double _time = 0;

  // World dimensions
  static const double _w = 880.0;
  static const double _h = 400.0;

  // Cached mountain images
  ui.Image? _farMountainImage;
  ui.Image? _midSilhouetteImage;

  // Stars
  late final List<_Star> _stars;

  // Ambient particles
  late final List<_Particle> _particles;

  // Moon position
  static const double _moonX = _w * 0.85;
  static const double _moonY = _h * 0.12;
  static const double _moonRadius = 18.0;

  ParallaxBackground({required this.biome}) {
    priority = -10;
  }

  @override
  Future<void> onLoad() async {
    final rng = math.Random(42);

    // Generate stars (40 stars in top 40% of screen)
    _stars = List.generate(40, (i) => _Star(
      x: rng.nextDouble() * _w,
      y: rng.nextDouble() * _h * 0.4,
      size: 0.5 + rng.nextDouble() * 1.5,
      phase: rng.nextDouble() * math.pi * 2,
      speed: 0.5 + rng.nextDouble() * 1.5,
    ));

    // Generate ambient particles (30 particles, biome-specific)
    _particles = List.generate(30, (i) => _Particle(
      x: rng.nextDouble() * _w,
      y: rng.nextDouble() * _h,
      size: 0.8 + rng.nextDouble() * 2.0,
      speedX: 0.2 + rng.nextDouble() * 0.6,
      speedY: biome.type == BiomeType.snow
          ? 0.5 + rng.nextDouble() * 1.0 // snow drifts downward
          : 0.2 + rng.nextDouble() * 0.5,
      phase: rng.nextDouble() * math.pi * 2,
    ));

    // Cache mountain layers as images
    _farMountainImage = await _generateMountainImage(
      rng: math.Random(101),
      baseY: _h * 0.45,
      peakMinHeight: 40,
      peakMaxHeight: 100,
      peakCount: 8,
      color: Color.lerp(biome.skyBottom, const Color(0xFF000000), 0.3)!,
    );

    _midSilhouetteImage = await _generateMountainImage(
      rng: math.Random(202),
      baseY: _h * 0.6,
      peakMinHeight: 20,
      peakMaxHeight: 60,
      peakCount: 12,
      color: Color.lerp(biome.skyBottom, const Color(0xFF000000), 0.15)!,
    );
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
    path.moveTo(0, _h);
    path.lineTo(0, baseY);

    final segmentWidth = _w / peakCount;
    for (int i = 0; i <= peakCount; i++) {
      final x = i * segmentWidth;
      final peakHeight = peakMinHeight + rng.nextDouble() * (peakMaxHeight - peakMinHeight);
      final peakY = baseY - peakHeight;

      if (i == 0) {
        path.lineTo(0, peakY + peakHeight * 0.5);
      }

      // Create smooth mountain peak with quadratic bezier
      final cpX = x + segmentWidth * 0.5;
      final nextX = (i + 1) * segmentWidth;
      final nextPeakHeight = peakMinHeight + rng.nextDouble() * (peakMaxHeight - peakMinHeight);
      final nextBaseY = baseY - nextPeakHeight * 0.3;

      path.quadraticBezierTo(cpX, peakY, math.min(nextX, _w), nextBaseY);
    }

    path.lineTo(_w, _h);
    path.close();

    canvas.drawPath(path, Paint()..color = color);

    final picture = recorder.endRecording();
    return picture.toImage(_w.toInt(), _h.toInt());
  }

  @override
  void update(double dt) {
    _time += dt;

    // Update particle positions
    for (final p in _particles) {
      if (biome.type == BiomeType.snow) {
        // Snow particles drift downward and sideways
        p.y += p.speedY * dt * 30;
        p.x += math.sin(_time * p.speedX + p.phase) * dt * 10;
        // Wrap around
        if (p.y > _h) {
          p.y = -5;
          p.x = math.Random().nextDouble() * _w;
        }
      } else {
        // Other particles float with sin-based wobble
        p.x += p.speedX * dt * 8;
        p.y += math.sin(_time * p.speedY * 2 + p.phase) * dt * 6;
        // Wrap horizontally
        if (p.x > _w) p.x = -5;
        if (p.x < -5) p.x = _w;
        // Clamp vertically
        if (p.y > _h) p.y = _h;
        if (p.y < 0) p.y = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _renderSkyGradient(canvas);
    _renderStars(canvas);
    _renderMoon(canvas);
    _renderFarMountains(canvas);
    _renderMidSilhouettes(canvas);
    _renderFog(canvas);
    _renderParticles(canvas);
    _renderVignette(canvas);
  }

  void _renderSkyGradient(Canvas canvas) {
    final grad = ui.Gradient.linear(
      const Offset(0, -20),
      const Offset(0, _h + 20),
      [biome.skyTop, biome.skyBottom],
      [0.0, 1.0],
    );
    canvas.drawRect(
      const Rect.fromLTWH(-10, -20, _w + 20, _h + 40),
      Paint()..shader = grad,
    );
  }

  void _renderStars(Canvas canvas) {
    for (final s in _stars) {
      // Twinkle: sin-based alpha pulse
      final alpha = (math.sin(_time * s.speed + s.phase) * 0.5 + 0.5);
      final a = (alpha * 200).round().clamp(30, 200);

      // Soft glow
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.size * 2.5,
        Paint()..color = Color.fromARGB((a * 0.15).round(), 200, 210, 255),
      );
      // Bright core
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.size * 0.8,
        Paint()..color = Color.fromARGB(a, 240, 245, 255),
      );
    }
  }

  void _renderMoon(Canvas canvas) {
    // Outer glow
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_moonX, _moonY),
        _moonRadius * 4,
        [
          const Color(0x20EEEEFF),
          const Color(0x08CCCCDD),
          Colors.transparent,
        ],
        [0.0, 0.4, 1.0],
      );
    canvas.drawCircle(
      const Offset(_moonX, _moonY),
      _moonRadius * 4,
      glowPaint,
    );

    // Moon body with radial gradient
    final moonPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_moonX - 4, _moonY - 4),
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
  }

  void _renderFarMountains(Canvas canvas) {
    if (_farMountainImage != null) {
      canvas.drawImage(_farMountainImage!, Offset.zero, Paint());
    }
  }

  void _renderMidSilhouettes(Canvas canvas) {
    if (_midSilhouetteImage != null) {
      canvas.drawImage(_midSilhouetteImage!, Offset.zero, Paint());
    }
  }

  void _renderFog(Canvas canvas) {
    final fogGrad = ui.Gradient.linear(
      Offset(0, _h * 0.6),
      const Offset(0, _h),
      [Colors.transparent, biome.fogColor],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, _h * 0.6, _w, _h * 0.4),
      Paint()..shader = fogGrad,
    );
  }

  void _renderParticles(Canvas canvas) {
    final particleColor = _getParticleColor();

    for (final p in _particles) {
      // Alpha based on sin wobble
      final alpha = (math.sin(_time * 1.5 + p.phase) * 0.5 + 0.5);
      final a = (alpha * 80).round().clamp(10, 80);

      // Soft glow
      final glowColor = Color((particleColor & 0x00FFFFFF) | ((a * 0.3).round() << 24));
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * 3,
        Paint()..color = glowColor,
      );

      // Bright core
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
    // Top edge
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, 40),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, 40),
          [const Color(0x50000000), Colors.transparent],
        ),
    );
    // Bottom edge
    canvas.drawRect(
      const Rect.fromLTWH(0, _h - 30, _w, 30),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, _h - 30),
          const Offset(0, _h),
          [Colors.transparent, const Color(0x40000000)],
        ),
    );
    // Left edge
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 30, _h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(30, 0),
          [const Color(0x35000000), Colors.transparent],
        ),
    );
    // Right edge
    canvas.drawRect(
      const Rect.fromLTWH(_w - 30, 0, 30, _h),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(_w - 30, 0),
          const Offset(_w, 0),
          [Colors.transparent, const Color(0x35000000)],
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
