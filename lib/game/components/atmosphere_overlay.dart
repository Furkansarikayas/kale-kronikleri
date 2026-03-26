import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders atmospheric post-processing on top of the game world.
/// Adds warm color grading, enhanced vignette, and subtle depth.
class AtmosphereOverlay extends Component {
  AtmosphereOverlay() {
    priority = 100; // Render on top of everything except HUD
  }

  @override
  void render(Canvas canvas) {
    const w = 880.0;
    const h = 400.0;

    // 1. Warm color grading overlay (subtle golden tint for "premium" feel)
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0x06FFDD88), // very subtle warm tint
    );

    // 2. Enhanced vignette — darker corners for cinematic feel
    // Top
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, 45),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(0, 45),
          [const Color(0x50000000), const Color(0x00000000)],
        ),
    );
    // Bottom
    canvas.drawRect(
      const Rect.fromLTWH(0, h - 35, w, 35),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, h - 35),
          const Offset(0, h),
          [const Color(0x00000000), const Color(0x40000000)],
        ),
    );
    // Left
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 35, h),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(35, 0),
          [const Color(0x40000000), const Color(0x00000000)],
        ),
    );
    // Right
    canvas.drawRect(
      const Rect.fromLTWH(w - 35, 0, 35, h),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(w - 35, 0),
          const Offset(w, 0),
          [const Color(0x00000000), const Color(0x40000000)],
        ),
    );

    // 3. Subtle radial vignette (darken all corners more)
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(w * 0.5, h * 0.5),
          w * 0.55,
          [const Color(0x00000000), const Color(0x20000000)],
        ),
    );
  }
}
