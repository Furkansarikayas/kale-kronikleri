import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/systems/audio_system.dart';
import 'widgets/glass_panel.dart';

class PauseOverlay extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onMainMenu;
  final VoidCallback? onBestiary;
  final VoidCallback? onSynergyGuide;

  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onMainMenu,
    this.onBestiary,
    this.onSynergyGuide,
  });

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay> {

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black38,
        child: Center(
          child: GlassPanel(
            padding: const EdgeInsets.all(24),
            borderColor: _gold,
            borderRadius: 12,
            blur: 12,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
              width: 280,
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DURAKLADI',
                style: TextStyle(
                  color: _gold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              // SFX Volume
              Row(
                children: [
                  Text('SES', style: TextStyle(color: _cream.withAlpha(150), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  Icon(
                    AudioSystem.instance.soundEnabled ? Icons.volume_up : Icons.volume_off,
                    color: _cream, size: 18,
                  ),
                  Expanded(
                    child: Slider(
                      value: AudioSystem.instance.volume,
                      onChanged: (v) {
                        setState(() {
                          AudioSystem.instance.setVolume(v);
                          if (v == 0) {
                            AudioSystem.instance.setSoundEnabled(false);
                          } else if (!AudioSystem.instance.soundEnabled) {
                            AudioSystem.instance.setSoundEnabled(true);
                          }
                        });
                      },
                      activeColor: _gold,
                      inactiveColor: _cream.withAlpha(40),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        AudioSystem.instance.setSoundEnabled(!AudioSystem.instance.soundEnabled);
                      });
                    },
                    child: Text(
                      AudioSystem.instance.soundEnabled ? 'AÇIK' : 'KAPALI',
                      style: TextStyle(color: _cream.withAlpha(180), fontSize: 10),
                    ),
                  ),
                ],
              ),
              // Music Volume
              Row(
                children: [
                  Text('MÜZİK', style: TextStyle(color: _cream.withAlpha(150), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  Icon(
                    AudioSystem.instance.musicEnabled ? Icons.music_note : Icons.music_off,
                    color: _cream, size: 18,
                  ),
                  Expanded(
                    child: Slider(
                      value: AudioSystem.instance.musicVolume,
                      onChanged: (v) {
                        setState(() {
                          AudioSystem.instance.setMusicVolume(v);
                          if (v == 0) {
                            AudioSystem.instance.setMusicEnabled(false);
                          } else if (!AudioSystem.instance.musicEnabled) {
                            AudioSystem.instance.setMusicEnabled(true);
                          }
                        });
                      },
                      activeColor: _gold,
                      inactiveColor: _cream.withAlpha(40),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        AudioSystem.instance.setMusicEnabled(!AudioSystem.instance.musicEnabled);
                      });
                    },
                    child: Text(
                      AudioSystem.instance.musicEnabled ? 'AÇIK' : 'KAPALI',
                      style: TextStyle(color: _cream.withAlpha(180), fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.onResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _darkBg,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('DEVAM ET', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (widget.onBestiary != null || widget.onSynergyGuide != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.onBestiary != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onBestiary,
                          icon: const Icon(Icons.menu_book, size: 16),
                          label: const Text('DÜŞMANLAR', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _gold,
                            side: BorderSide(color: _gold.withAlpha(120)),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                    if (widget.onBestiary != null && widget.onSynergyGuide != null) const SizedBox(width: 8),
                    if (widget.onSynergyGuide != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onSynergyGuide,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('SİNERJİLER', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _gold,
                            side: BorderSide(color: _gold.withAlpha(120)),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.onMainMenu,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cream,
                  side: const BorderSide(color: _cream),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('ANA MENÜ'),
              ),
            ],
          ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
