import 'package:flutter/material.dart';

class MainMenu extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onMeta;
  final int stoneSpirit;
  final int totalRuns;

  const MainMenu({
    super.key,
    required this.onPlay,
    required this.onMeta,
    required this.stoneSpirit,
    required this.totalRuns,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'KALE KRONiKLERi',
              style: TextStyle(
                color: _gold,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Castle Chronicles',
              style: TextStyle(
                color: _cream.withAlpha(150),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 48),
            _MenuButton(
              label: 'OYNA',
              icon: Icons.play_arrow,
              onPressed: onPlay,
            ),
            const SizedBox(height: 16),
            _MenuButton(
              label: 'META AGACI',
              icon: Icons.account_tree,
              onPressed: onMeta,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond, color: _gold, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Tas Ruhu: $stoneSpirit',
                  style: const TextStyle(color: _cream, fontSize: 13),
                ),
                const SizedBox(width: 24),
                const Icon(Icons.loop, color: _gold, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Toplam Kosu: $totalRuns',
                  style: const TextStyle(color: _cream, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
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
      width: 220,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 16, letterSpacing: 2)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBA7517),
          foregroundColor: const Color(0xFF1A150E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
