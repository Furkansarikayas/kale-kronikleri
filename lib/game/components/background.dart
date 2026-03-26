import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GameBackground extends Component with HasGameReference {
  double _time = 0;
  // Pre-computed ambient particles (static positions)
  late final List<_AmbientParticle> _particles;

  GameBackground() {
    priority = -10; // Render behind everything
  }

  @override
  Future<void> onLoad() async {
    final rng = math.Random(42);
    _particles = List.generate(25, (i) => _AmbientParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 0.5 + rng.nextDouble() * 1.5,
      speed: 0.3 + rng.nextDouble() * 0.7,
      phase: rng.nextDouble() * math.pi * 2,
    ));
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    // The game world is 880x400 (22*40 x 10*40)
    final w = 880.0;
    final h = 400.0;

    // 1. Atmospheric gradient background (dark twilight sky to ground)
    // Top: deep midnight blue, middle: dark indigo, bottom: very dark earthy green
    final skyGrad = ui.Gradient.linear(
      Offset(0, -20), Offset(0, h + 20),
      [
        const Color(0xFF0A0E1A), // deep midnight blue
        const Color(0xFF111828), // dark navy
        const Color(0xFF0F1A12), // dark forest at horizon
        const Color(0xFF0C1208), // very dark ground
      ],
      [0.0, 0.3, 0.7, 1.0],
    );
    canvas.drawRect(Rect.fromLTWH(-10, -20, w + 20, h + 40), Paint()..shader = skyGrad);

    // 2. Subtle fog layer at bottom
    final fogGrad = ui.Gradient.linear(
      Offset(0, h * 0.6), Offset(0, h),
      [Colors.transparent, const Color(0x08AABBCC)],
    );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.6, w, h * 0.4), Paint()..shader = fogGrad);

    // 3. Ambient floating particles (fireflies/dust motes)
    for (final p in _particles) {
      final px = p.x * w;
      final py = p.y * h + math.sin(_time * p.speed + p.phase) * 8;
      final alpha = (math.sin(_time * p.speed * 0.7 + p.phase) * 0.5 + 0.5);
      final a = (alpha * 40).round().clamp(0, 255);

      // Soft glow
      canvas.drawCircle(
        Offset(px, py), p.size * 3,
        Paint()..color = Color.fromARGB((a * 0.3).round(), 180, 200, 120),
      );
      // Bright core
      canvas.drawCircle(
        Offset(px, py), p.size,
        Paint()..color = Color.fromARGB(a, 220, 240, 160),
      );
    }

    // 4. Subtle vignette (darken corners/edges)
    // Top edge
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, 30),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, 0), Offset(0, 30),
        [const Color(0x40000000), Colors.transparent],
      ),
    );
    // Bottom edge
    canvas.drawRect(
      Rect.fromLTWH(0, h - 20, w, 20),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, h - 20), Offset(0, h),
        [Colors.transparent, const Color(0x30000000)],
      ),
    );
    // Left edge
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 25, h),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, 0), Offset(25, 0),
        [const Color(0x35000000), Colors.transparent],
      ),
    );
    // Right edge
    canvas.drawRect(
      Rect.fromLTWH(w - 25, 0, 25, h),
      Paint()..shader = ui.Gradient.linear(
        Offset(w - 25, 0), Offset(w, 0),
        [Colors.transparent, const Color(0x35000000)],
      ),
    );
  }
}

class _AmbientParticle {
  final double x, y, size, speed, phase;
  const _AmbientParticle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.phase,
  });
}
