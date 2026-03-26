import 'package:flutter/material.dart';
import '../game/data/synergy_data.dart';
import '../game/data/tower_data.dart';

class SynergyGuide extends StatelessWidget {
  final VoidCallback onBack;
  final List<String> discoveredSynergies;

  const SynergyGuide({
    super.key,
    required this.onBack,
    this.discoveredSynergies = const [],
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: _cream),
        ),
        title: const Text('Sinerji Rehberi', style: TextStyle(color: _gold, fontSize: 16)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: SynergyData.all.length,
        itemBuilder: (context, index) {
          final synergy = SynergyData.all[index];
          final isDiscovered = discoveredSynergies.contains(synergy.name);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDiscovered ? _gold.withAlpha(15) : _cream.withAlpha(5),
              border: Border.all(
                color: isDiscovered ? _gold.withAlpha(100) : _cream.withAlpha(20),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      synergy.isTriple ? Icons.auto_awesome : Icons.flash_on,
                      color: isDiscovered ? _gold : _cream.withAlpha(80),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        synergy.name,
                        style: TextStyle(
                          color: isDiscovered ? _gold : _cream,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (synergy.isTriple)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purple.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'UCLU',
                          style: TextStyle(color: Colors.purple.shade200, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isDiscovered)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle, color: _gold, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  synergy.description,
                  style: TextStyle(color: _cream.withAlpha(150), fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Gerekli: ', style: TextStyle(color: _cream.withAlpha(100), fontSize: 10)),
                    ...synergy.requiredTowers.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_towerIcon(t), color: _towerColor(t), size: 13),
                          const SizedBox(width: 2),
                          Text(
                            TowerData.getStats(t).name.split(' ').first,
                            style: TextStyle(color: _cream.withAlpha(180), fontSize: 10),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  synergy.isTriple
                      ? 'Uc kuleyi yan yana yerlestir (8 yonlu komsuluk)'
                      : 'Iki kuleyi yan yana yerlestir (8 yonlu komsuluk)',
                  style: TextStyle(color: _cream.withAlpha(60), fontSize: 9, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _towerIcon(TowerType type) {
    switch (type) {
      case TowerType.arrow: return Icons.north_east;
      case TowerType.ice: return Icons.ac_unit;
      case TowerType.fire: return Icons.local_fire_department;
      case TowerType.lightning: return Icons.bolt;
      case TowerType.poison: return Icons.science;
      case TowerType.cannon: return Icons.adjust;
      case TowerType.spikeWall: return Icons.fence;
      case TowerType.support: return Icons.shield;
      case TowerType.water: return Icons.water_drop;
      case TowerType.wizard: return Icons.auto_fix_high;
      case TowerType.dark: return Icons.nightlight;
      case TowerType.holy: return Icons.wb_sunny;
    }
  }

  Color _towerColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFFCCCCCC);
      case TowerType.ice: return const Color(0xFF87CEEB);
      case TowerType.fire: return const Color(0xFFFF6600);
      case TowerType.lightning: return const Color(0xFFFFD700);
      case TowerType.poison: return const Color(0xFF00CC00);
      case TowerType.cannon: return const Color(0xFF888888);
      case TowerType.spikeWall: return const Color(0xFF8B4513);
      case TowerType.support: return const Color(0xFFFFFF88);
      case TowerType.water: return const Color(0xFF4488FF);
      case TowerType.wizard: return const Color(0xFF9966FF);
      case TowerType.dark: return const Color(0xFF8B00FF);
      case TowerType.holy: return const Color(0xFFFFFFCC);
    }
  }
}
