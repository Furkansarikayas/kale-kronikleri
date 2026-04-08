import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../systems/audio_system.dart';
import 'floating_text.dart';
import 'effects/hit_effect.dart';

/// Comprehensive debug overlay showing FPS, frame time, entity counts,
/// pool stats, and audio stats. Toggle with [enabled] flag.
class DebugOverlay extends PositionComponent {
  bool enabled = false;

  // Entity counts — set externally each frame
  int enemyCount = 0;
  int projectileCount = 0;
  int towerCount = 0;

  // Boss batch debug stats — set externally each frame
  int bossHits = 0;
  int bossDamage = 0;
  int bossEffects = 0;
  bool bossBatchActive = false;

  // FPS tracking
  double _fpsAccum = 0;
  int _fpsFrames = 0;
  double _displayFps = 0;
  double _displayFrameTime = 0;
  double _peakFrameTime = 0;
  double _currentDt = 0;

  // Cached text painter (rebuild every 0.5s)
  TextPainter? _painter;
  double _rebuildTimer = 0;

  // Peak tracking (reset every 5s)
  double _peakResetTimer = 0;

  DebugOverlay() : super(priority: 9999);

  @override
  void update(double dt) {
    if (!enabled) return;
    _currentDt = dt;
    _fpsAccum += dt;
    _fpsFrames++;
    _rebuildTimer += dt;
    _peakResetTimer += dt;

    // Track peak frame time
    final dtMs = dt * 1000;
    if (dtMs > _peakFrameTime) _peakFrameTime = dtMs;

    if (_fpsAccum >= 0.5) {
      _displayFps = _fpsFrames / _fpsAccum;
      _displayFrameTime = _fpsAccum / _fpsFrames * 1000;
      _fpsFrames = 0;
      _fpsAccum = 0;
    }

    // Reset peak every 5 seconds
    if (_peakResetTimer >= 5.0) {
      _peakResetTimer = 0;
      _peakFrameTime = 0;
    }

    if (_rebuildTimer >= 0.5) {
      _rebuildTimer = 0;
      _rebuildPainter();
    }
  }

  void _rebuildPainter() {
    final fps = _displayFps.toStringAsFixed(0);
    final ft = _displayFrameTime.toStringAsFixed(1);
    final peak = _peakFrameTime.toStringAsFixed(1);
    final audio = AudioSystem.instance;

    final bossLine = bossBatchActive
        ? 'BOSS BATCH: hits:$bossHits  dmg:$bossDamage  fx:$bossEffects'
        : 'BOSS BATCH: inactive';

    final text = 'FPS: $fps  (${ft}ms  peak:${peak}ms)\n'
        'Enemies: $enemyCount  Towers: $towerCount\n'
        'Projectiles: $projectileCount\n'
        'Texts: ${FloatingText.totalActive}  (created: ${FloatingText.totalCreated})\n'
        'Effects: ${HitEffect.totalActive}  (created: ${HitEffect.totalCreated})\n'
        'Audio: ${audio.activePlayerCount}/${audio.poolSize}  '
        'played:${audio.totalPlayed}  skip:${audio.totalSkipped}\n'
        '$bossLine';

    _painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.4,
          shadows: [Shadow(color: Color(0xCC000000), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    _painter!.layout();
  }

  @override
  void render(Canvas canvas) {
    if (!enabled || _painter == null) return;
    // Draw semi-transparent background
    final bgRect = Rect.fromLTWH(2, 2, _painter!.width + 8, _painter!.height + 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
      Paint()..color = const Color(0x88000000),
    );
    _painter!.paint(canvas, const Offset(6, 5));
  }
}
