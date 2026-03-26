import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'widgets/glass_panel.dart';

class PauseOverlay extends StatelessWidget {
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _darkBg,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('DEVAM ET', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (onBestiary != null || onSynergyGuide != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onBestiary != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onBestiary,
                          icon: const Icon(Icons.menu_book, size: 16),
                          label: const Text('DUSMANLAR', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _gold,
                            side: BorderSide(color: _gold.withAlpha(120)),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ),
                    if (onBestiary != null && onSynergyGuide != null) const SizedBox(width: 8),
                    if (onSynergyGuide != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onSynergyGuide,
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('SINERJILER', style: TextStyle(fontSize: 11)),
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
                onPressed: onMainMenu,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cream,
                  side: const BorderSide(color: _cream),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('ANA MENU'),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}
