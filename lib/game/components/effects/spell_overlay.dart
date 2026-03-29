import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen spell effect overlay that fades in and out when a spell is cast.
class SpellOverlay extends PositionComponent {
  final String assetPath;
  final Color tintColor;
  final double duration;

  double _timer = 0;
  ui.Image? _image;

  SpellOverlay({
    required this.assetPath,
    required this.tintColor,
    this.duration = 1.5,
    required Vector2 worldSize,
  }) {
    size = worldSize;
    priority = 100;
  }

  @override
  Future<void> onLoad() async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _image = frame.image;
    } catch (_) {
      // If asset fails to load, just show color overlay
    }
  }

  @override
  void update(double dt) {
    _timer += dt;
    if (_timer >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Fade curve: quick fade in, hold, fade out
    final progress = (_timer / duration).clamp(0.0, 1.0);
    final alpha = progress < 0.2
        ? (progress / 0.2) // fade in
        : progress > 0.6
            ? (1.0 - progress) / 0.4 // fade out
            : 1.0; // hold

    final opacity = (alpha * 0.6).clamp(0.0, 1.0);

    if (_image != null) {
      final src = Rect.fromLTWH(0, 0, _image!.width.toDouble(), _image!.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.x, size.y);
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity);
      canvas.drawImageRect(_image!, src, dst, paint);
    }

    // Tinted overlay on top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = tintColor.withAlpha((opacity * 40).round()),
    );
  }
}
