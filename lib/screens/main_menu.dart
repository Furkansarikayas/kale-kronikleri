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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuButton(
                        label: 'OYNA',
                        icon: Icons.play_arrow,
                        onPressed: onPlay,
                      ),
                      const SizedBox(width: 16),
                      _MenuButton(
                        label: 'META AGACI',
                        icon: Icons.account_tree,
                        onPressed: onMeta,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.diamond, color: _gold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Tas Ruhu: $stoneSpirit',
                        style: const TextStyle(color: _cream, fontSize: 12),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.loop, color: _gold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Toplam Kosu: $totalRuns',
                        style: const TextStyle(color: _cream, fontSize: 12),
                      ),
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
      width: 180,
      height: 44,
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
