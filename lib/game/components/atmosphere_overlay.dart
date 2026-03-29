import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'map/biome_data.dart';

/// Renders heavy atmospheric post-processing on top of the game world.
/// Creates a dramatic dark, moody look with vignette, darkness gradients,
/// biome-colored fog wisps, and subtle animated particles.
class AtmosphereOverlay extends Component with HasGameReference {
  double _time = 0;
  BiomeType _biomeType;

  // Fog wisp particles
  late final List<_FogWisp> _fogWisps;

  AtmosphereOverlay({
    BiomeType biomeType = BiomeType.forest,
    Color biomeFogTint = const Color(0x0AAABBCC),
  })  : _biomeType = biomeType {
    priority = 100; // Render on top of the game world
  }

  /// Allow the game to configure biome after construction.
  void configureBiome(BiomeData biome) {
    _biomeType = biome.type;
  }

  @override
  Future<void> onLoad() async {
    final rng = math.Random(77);
    // Generate fog wisps
    _fogWisps = List.generate(18, (i) => _FogWisp(
      x: rng.nextDouble() * _w,
      y: _h * 0.3 + rng.nextDouble() * _h * 0.7,
      width: 60 + rng.nextDouble() * 120,
      height: 8 + rng.nextDouble() * 20,
      speedX: 0.15 + rng.nextDouble() * 0.4,
      phase: rng.nextDouble() * math.pi * 2,
      opacity: 0.02 + rng.nextDouble() * 0.05,
    ));
  }

  // Use slightly larger dimensions to cover area including sky strip
  static const double _w = 880.0;
  static const double _h = 480.0; // covers the full viewport including sky
  static const double _skyOffset = 60.0; // sky area above grid

  @override
  void update(double dt) {
    _time += dt;

    // Animate fog wisps
    for (final wisp in _fogWisps) {
      wisp.x += wisp.speedX * dt * 12;
      wisp.y += math.sin(_time * 0.5 + wisp.phase) * dt * 3;
      if (wisp.x > _w + wisp.width) {
        wisp.x = -wisp.width;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final topY = -_skyOffset;
    final fullH = _h;

    // Light vignette only — keep the scene bright and readable
    _renderLightVignette(canvas, topY, fullH);

    // Biome-colored fog wisps (animated, subtle)
    _renderFogWisps(canvas);
  }

  void _renderLightVignette(Canvas canvas, double topY, double fullH) {
    final centerX = _w / 2;
    final centerY = topY + fullH / 2;
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(centerX, centerY),
        _w * 0.6,
        [
          const Color(0x00000000),
          const Color(0x00000000),
          const Color(0x18000000),
          const Color(0x35000000),
        ],
        [0.0, 0.5, 0.8, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, topY, _w, fullH), vignette);
  }

  void _renderRadialVignette(Canvas canvas, double topY, double fullH) {
    final centerX = _w / 2;
    final centerY = topY + fullH / 2;
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(centerX, centerY),
        _w * 0.55,
        [
          const Color(0x00000000), // center: fully transparent
          const Color(0x00000000), // still clear
          const Color(0x45000000), // darkening starts
          const Color(0x90000000), // heavy darkness at edges
        ],
        [0.0, 0.35, 0.7, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, topY, _w, fullH), vignette);
  }

  void _renderDarknessGradient(
      Canvas canvas, double topY, double fullH, double bottomY) {
    canvas.drawRect(
      Rect.fromLTWH(0, topY, _w, fullH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, topY),
          Offset(0, bottomY),
          [
            const Color(0x70000008), // dark top (night sky)
            const Color(0x25000005), // lighter middle
            const Color(0x15000003), // lightest ground area
            const Color(0x40000008), // darker bottom
          ],
          [0.0, 0.25, 0.65, 1.0],
        ),
    );
  }

  void _renderFogWisps(Canvas canvas) {
    final fogBaseColor = _getBiomeFogColor();
    for (final wisp in _fogWisps) {
      final alpha =
          (math.sin(_time * 0.8 + wisp.phase) * 0.5 + 0.5) * wisp.opacity;
      final a = (alpha * 255).round().clamp(2, 40);

      final fogColor = Color.fromARGB(
        a,
        (fogBaseColor.r * 255.0).round().clamp(0, 255),
        (fogBaseColor.g * 255.0).round().clamp(0, 255),
        (fogBaseColor.b * 255.0).round().clamp(0, 255),
      );

      // Draw soft elliptical fog wisp
      final rect = Rect.fromCenter(
        center: Offset(wisp.x, wisp.y),
        width: wisp.width,
        height: wisp.height,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = fogColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  Color _getBiomeFogColor() {
    switch (_biomeType) {
      case BiomeType.forest:
        return const Color(0xFF88BBAA); // misty green
      case BiomeType.desert:
        return const Color(0xFFDDBB88); // sandy haze
      case BiomeType.snow:
        return const Color(0xFFCCDDEE); // icy blue
      case BiomeType.volcano:
        return const Color(0xFFFF6620); // ember glow
      case BiomeType.dark:
        return const Color(0xFF8844FF); // purple mist
    }
  }

  void _renderCornerShadows(Canvas canvas, double topY, double fullH) {
    // Top-left corner
    canvas.drawRect(
      Rect.fromLTWH(0, topY, _w * 0.4, fullH * 0.4),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(0, topY),
          _w * 0.4,
          [const Color(0x50000000), const Color(0x00000000)],
        ),
    );
    // Top-right corner
    canvas.drawRect(
      Rect.fromLTWH(_w * 0.6, topY, _w * 0.4, fullH * 0.4),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(_w, topY),
          _w * 0.4,
          [const Color(0x50000000), const Color(0x00000000)],
        ),
    );
    // Bottom-left corner
    canvas.drawRect(
      Rect.fromLTWH(0, topY + fullH * 0.6, _w * 0.4, fullH * 0.4),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(0, topY + fullH),
          _w * 0.4,
          [const Color(0x50000000), const Color(0x00000000)],
        ),
    );
    // Bottom-right corner
    canvas.drawRect(
      Rect.fromLTWH(_w * 0.6, topY + fullH * 0.6, _w * 0.4, fullH * 0.4),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(_w, topY + fullH),
          _w * 0.4,
          [const Color(0x50000000), const Color(0x00000000)],
        ),
    );
  }

  void _renderEdgeVignettes(
      Canvas canvas, double topY, double fullH, double bottomY) {
    // Top edge — strong (simulates night sky)
    canvas.drawRect(
      Rect.fromLTWH(0, topY, _w, 70),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, topY),
          Offset(0, topY + 70),
          [const Color(0x70000000), const Color(0x00000000)],
        ),
    );
    // Bottom edge
    canvas.drawRect(
      Rect.fromLTWH(0, bottomY - 50, _w, 50),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, bottomY - 50),
          Offset(0, bottomY),
          [const Color(0x00000000), const Color(0x60000000)],
        ),
    );
    // Left edge
    canvas.drawRect(
      Rect.fromLTWH(0, topY, 50, fullH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          const Offset(50, 0),
          [const Color(0x55000000), const Color(0x00000000)],
        ),
    );
    // Right edge
    canvas.drawRect(
      Rect.fromLTWH(_w - 50, topY, 50, fullH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(_w - 50, 0),
          Offset(_w, 0),
          [const Color(0x00000000), const Color(0x55000000)],
        ),
    );
  }
}

class _FogWisp {
  double x;
  double y;
  final double width;
  final double height;
  final double speedX;
  final double phase;
  final double opacity;

  _FogWisp({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speedX,
    required this.phase,
    required this.opacity,
  });
}
