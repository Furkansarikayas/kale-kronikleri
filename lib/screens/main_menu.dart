import 'package:flutter/material.dart';

class MainMenu extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onMeta;
  final VoidCallback? onSettings;
  final int stoneSpirit;
  final int totalRuns;
  final int bestWave;
  final int totalKills;

  const MainMenu({
    super.key,
    required this.onPlay,
    required this.onMeta,
    this.onSettings,
    required this.stoneSpirit,
    required this.totalRuns,
    this.bestWave = 0,
    this.totalKills = 0,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'KALE KRONiKLERi',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Castle Chronicles',
                    style: TextStyle(
                      color: _cream.withAlpha(150),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _MenuButton(
                        label: 'OYNA',
                        icon: Icons.play_arrow,
                        onPressed: onPlay,
                      ),
                      _MenuButton(
                        label: 'META AGACI',
                        icon: Icons.account_tree,
                        onPressed: onMeta,
                      ),
                      if (onSettings != null)
                        _MenuButton(
                          label: 'AYARLAR',
                          icon: Icons.settings,
                          onPressed: onSettings!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stats grid
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _StatChip(icon: Icons.diamond, label: 'Tas Ruhu', value: '$stoneSpirit'),
                      _StatChip(icon: Icons.loop, label: 'Kosu', value: '$totalRuns'),
                      if (bestWave > 0) _StatChip(icon: Icons.waves, label: 'En Iyi Dalga', value: '$bestWave'),
                      if (totalKills > 0) _StatChip(icon: Icons.dangerous, label: 'Toplam Oldurulen', value: '$totalKills'),
                    ],
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFBA7517), size: 13),
        const SizedBox(width: 3),
        Text(
          '$label: $value',
          style: const TextStyle(color: Color(0xFFF5EDD8), fontSize: 11),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14, letterSpacing: 2)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBA7517),
          foregroundColor: const Color(0xFF1A150E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
