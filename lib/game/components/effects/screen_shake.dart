import 'dart:math';
import 'package:flame/components.dart';

class ScreenShake extends Component {
  double _duration = 0;
  double _intensity = 0;
  double _timer = 0;
  final Random _rng = Random();

  /// Whether the screen shake effect is enabled (can be toggled in settings).
  bool enabled = true;

  Vector2 get offset {
    if (!enabled || _timer <= 0) return Vector2.zero();
    final progress = _timer / _duration;
    final currentIntensity = _intensity * progress;
    return Vector2(
      (_rng.nextDouble() * 2 - 1) * currentIntensity,
      (_rng.nextDouble() * 2 - 1) * currentIntensity,
    );
  }

  void shake({double duration = 0.3, double intensity = 4.0}) {
    if (!enabled) return;
    final remaining = _duration > 0 ? _intensity * (_timer / _duration).clamp(0, 1) : 0.0;
    if (intensity > remaining) {
      _duration = duration;
      _intensity = intensity;
      _timer = duration;
    }
  }

  @override
  void update(double dt) {
    if (_timer > 0) {
      _timer -= dt;
      if (_timer < 0) _timer = 0;
    }
  }
}
