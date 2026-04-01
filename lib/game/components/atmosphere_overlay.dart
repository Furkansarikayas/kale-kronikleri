import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'map/biome_data.dart';

/// Renders subtle atmospheric post-processing on top of the game world.
/// Creates ambient life with light vignette, biome-colored fog wisps,
/// drifting dust motes, and state-reactive mood overlays.
class AtmosphereOverlay extends Component with HasGameReference {
  double _time = 0;
  BiomeType _biomeType;

  // Fog wisp particles
  late final List<_FogWisp> _fogWisps;

  // Ambient dust motes (math-driven, no object allocation)
  late final List<_DustMote> _dustMotes;

  // State-reactive atmosphere (set externally by game each frame)
  double hpRatio = 1.0;     // castle HP 0→1
  bool isBossWave = false;  // stronger atmosphere during boss waves

  // Smoothed values for gradual transitions
  double _smoothBoss = 0;    // 0→1, lerps toward isBossWave target
  double _smoothDanger = 0;  // 0→1, lerps toward danger level from hpRatio

  // Event pulse: short-lived intensity boost (set via triggerEventPulse)
  double _eventPulse = 0;
  double _eventPulseDuration = 0;

  // Release pulse: brief atmospheric "exhale" after boss death
  double _releasePulse = 0;   // 1→0, linear decay
  double _releaseDuration = 0;

  /// Trigger a short ambient intensity surge for major events.
  void triggerEventPulse(double duration) {
    _eventPulse = 1.0;
    _eventPulseDuration = duration;
  }

  /// Trigger a brief atmospheric release / exhale (boss death relief).
  void triggerRelease(double duration) {
    _releasePulse = 1.0;
    _releaseDuration = duration;
  }

  AtmosphereOverlay({
    BiomeType biomeType = BiomeType.forest,
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
    _fogWisps = List.generate(14, (i) => _FogWisp(
      x: rng.nextDouble() * _w,
      y: _h * 0.3 + rng.nextDouble() * _h * 0.7,
      width: 60 + rng.nextDouble() * 120,
      height: 8 + rng.nextDouble() * 20,
      speedX: 0.15 + rng.nextDouble() * 0.4,
      phase: rng.nextDouble() * math.pi * 2,
      opacity: 0.02 + rng.nextDouble() * 0.02,
    ));
    // Generate ambient dust motes (lightweight drifting specks)
    _dustMotes = List.generate(10, (i) => _DustMote(
      x: rng.nextDouble() * _w,
      y: rng.nextDouble() * _h,
      speedX: 0.1 + rng.nextDouble() * 0.3,
      speedY: -0.05 - rng.nextDouble() * 0.15,
      phase: rng.nextDouble() * math.pi * 2,
      size: 0.7 + rng.nextDouble() * 0.8,
      baseAlpha: 0.06 + rng.nextDouble() * 0.08,
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

    // Animate dust motes — gentle drift with slight wave motion
    for (final mote in _dustMotes) {
      mote.x += mote.speedX * dt * 10;
      mote.y += mote.speedY * dt * 10 + math.sin(_time * 0.7 + mote.phase) * dt * 2;
      // Wrap around screen
      if (mote.x > _w + 5) mote.x = -5;
      if (mote.y < -5) mote.y = _h + 5;
    }

    // Smooth state transitions (lerp toward targets)
    // During release pulse, boss pressure drops faster (exhale effect)
    final bossTarget = isBossWave ? 1.0 : 0.0;
    final bossSpeed = _releasePulse > 0.3 ? 6.0 : 2.0; // fast drop during release
    _smoothBoss += (bossTarget - _smoothBoss) * dt * bossSpeed;

    final dangerTarget = hpRatio < 0.4 ? ((0.4 - hpRatio) / 0.4).clamp(0.0, 1.0) : 0.0;
    _smoothDanger += (dangerTarget - _smoothDanger) * dt * 1.2; // ~0.8s ramp

    // Event pulse decay
    if (_eventPulse > 0 && _eventPulseDuration > 0) {
      _eventPulse -= dt / _eventPulseDuration;
      if (_eventPulse < 0) _eventPulse = 0;
    }

    // Release pulse decay (boss death exhale)
    if (_releasePulse > 0 && _releaseDuration > 0) {
      _releasePulse -= dt / _releaseDuration;
      if (_releasePulse < 0) _releasePulse = 0;
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

    // Ambient dust motes
    _renderDustMotes(canvas);

    // State-reactive tint: subtle darkening at low HP or during boss waves
    _renderStateOverlay(canvas, topY, fullH);
  }

  void _renderLightVignette(Canvas canvas, double topY, double fullH) {
    final centerX = _w / 2;
    final centerY = topY + fullH / 2;
    // During release pulse, soften vignette edges (battlefield feels lighter)
    final releaseSoften = _releasePulse > 0.01 ? _releasePulse * 0.3 : 0.0;
    final edgeA1 = (0x18 * (1.0 - releaseSoften)).round();
    final edgeA2 = (0x35 * (1.0 - releaseSoften)).round();
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(centerX, centerY),
        _w * 0.6,
        [
          const Color(0x00000000),
          const Color(0x00000000),
          Color.fromARGB(edgeA1, 0, 0, 0),
          Color.fromARGB(edgeA2, 0, 0, 0),
        ],
        [0.0, 0.5, 0.8, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, topY, _w, fullH), vignette);
  }

  void _renderFogWisps(Canvas canvas) {
    final fogBaseColor = _getBiomeFogColor();
    for (final wisp in _fogWisps) {
      final alpha =
          (math.sin(_time * 0.8 + wisp.phase) * 0.5 + 0.5) * wisp.opacity;
      final a = (alpha * 255).round().clamp(2, 30);

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
      );
    }
  }

  void _renderDustMotes(Canvas canvas) {
    // Smoothed boss + event pulse drive intensity; release calms motes
    final releaseDamp = _releasePulse > 0.01 ? 1.0 - _releasePulse * 0.3 : 1.0;
    final intensityMult = (1.0 + _smoothBoss * 0.5 + _eventPulse * 0.8) * releaseDamp;
    final fogColor = _getBiomeFogColor();
    final r = (fogColor.r * 255.0).round().clamp(0, 255);
    final g = (fogColor.g * 255.0).round().clamp(0, 255);
    final b = (fogColor.b * 255.0).round().clamp(0, 255);

    for (final mote in _dustMotes) {
      final flicker = (math.sin(_time * 1.5 + mote.phase) * 0.5 + 0.5);
      final alpha = (mote.baseAlpha * flicker * intensityMult * 255)
          .round().clamp(0, 40);
      if (alpha < 5) continue;
      canvas.drawCircle(
        Offset(mote.x, mote.y),
        mote.size,
        Paint()
          ..color = Color.fromARGB(alpha, r, g, b)
      );
    }
  }

  void _renderStateOverlay(Canvas canvas, double topY, double fullH) {
    // When both danger and boss are active, dampen each to prevent muddy overlap
    final overlapDamp = (_smoothDanger > 0.05 && _smoothBoss > 0.05) ? 0.7 : 1.0;

    // Low HP: subtle dark-red tint (smoothed transition)
    if (_smoothDanger > 0.01) {
      final dangerAlpha = (_smoothDanger * 16 * overlapDamp).round().clamp(0, 20);
      canvas.drawRect(
        Rect.fromLTWH(0, topY, _w, fullH),
        Paint()..color = Color.fromARGB(dangerAlpha, 60, 5, 5),
      );
    }

    // Boss wave: faint dark-purple pressure (smoothed transition)
    if (_smoothBoss > 0.01) {
      final bossPulse = (0.45 + 0.15 * math.sin(_time * 1.2)).clamp(0.0, 1.0);
      final bossAlpha = (bossPulse * _smoothBoss * 12 * overlapDamp).round().clamp(0, 15);
      if (bossAlpha > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, topY, _w, fullH),
          Paint()..color = Color.fromARGB(bossAlpha, 30, 0, 50),
        );
      }
    }

    // Event pulse: brief ambient surge that fades out
    if (_eventPulse > 0.01) {
      final pulseAlpha = (_eventPulse * 12).round().clamp(0, 15);
      canvas.drawRect(
        Rect.fromLTWH(0, topY, _w, fullH),
        Paint()..color = Color.fromARGB(pulseAlpha, 255, 240, 200),
      );
    }

    // Release pulse: cool-tone relief wash (boss death exhale)
    if (_releasePulse > 0.01) {
      // Ease-out curve for smooth fade
      final eased = _releasePulse * _releasePulse; // quadratic ease-out
      final releaseAlpha = (eased * 10).round().clamp(0, 12);
      if (releaseAlpha > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, topY, _w, fullH),
          Paint()..color = Color.fromARGB(releaseAlpha, 200, 220, 255),
        );
      }
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

class _DustMote {
  double x;
  double y;
  final double speedX;
  final double speedY;
  final double phase;
  final double size;
  final double baseAlpha;

  _DustMote({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.phase,
    required this.size,
    required this.baseAlpha,
  });
}
