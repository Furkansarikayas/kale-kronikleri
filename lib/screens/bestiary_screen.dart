import 'package:flutter/material.dart';
import '../game/data/enemy_data.dart';
import '../game/data/tower_data.dart';

class BestiaryScreen extends StatelessWidget {
  final VoidCallback onBack;

  const BestiaryScreen({super.key, required this.onBack});

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
        title: const Text('Düşman Ansiklopedisi', style: TextStyle(color: _gold, fontSize: 16)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: EnemyType.values.length,
        itemBuilder: (context, index) {
          final type = EnemyType.values[index];
          final stats = EnemyData.getStats(type);
          final weaknesses = EnemyData.getWeaknesses(type);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _cream.withAlpha(8),
              border: Border.all(color: stats.isBoss ? _gold : _cream.withAlpha(30)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Enemy color dot
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _enemyColor(type),
                    shape: BoxShape.circle,
                    border: stats.isBoss ? Border.all(color: const Color(0xFFFFD700), width: 2) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            stats.name,
                            style: TextStyle(
                              color: stats.isBoss ? _gold : _cream,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (stats.isBoss) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: _gold.withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('BOSS', style: TextStyle(color: _gold, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _statChip(Icons.favorite, '${stats.hp}', Colors.red),
                          const SizedBox(width: 8),
                          _statChip(Icons.shield, '${stats.armor}', Colors.blue),
                          const SizedBox(width: 8),
                          _statChip(Icons.speed, '${stats.speed}x', Colors.green),
                          const SizedBox(width: 8),
                          _statChip(Icons.monetization_on, '${stats.goldReward}', _gold),
                        ],
                      ),
                      if (weaknesses.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Zayıflık: ', style: TextStyle(color: _cream.withAlpha(100), fontSize: 9)),
                            ...weaknesses.map((t) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_towerIcon(t), color: const Color(0xFFFF6666), size: 11),
                                  const SizedBox(width: 2),
                                  Text(
                                    TowerData.getStats(t).name.split(' ').first,
                                    style: TextStyle(color: _cream.withAlpha(150), fontSize: 9),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ],
                      if (_specialAbility(type) != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _specialAbility(type)!,
                          style: TextStyle(color: _gold.withAlpha(150), fontSize: 9, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withAlpha(180)),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(color: _cream.withAlpha(180), fontSize: 10)),
      ],
    );
  }

  String? _specialAbility(EnemyType type) {
    switch (type) {
      case EnemyType.cavalry: return 'Çok hızlı hareket eder';
      case EnemyType.undead: return 'Öldüğünde 3 küçük undead\'e bölünür';
      case EnemyType.healer: return 'Yakındaki düşmanlara +5 HP İyileştirme';
      case EnemyType.burrower: return 'Yerin altına girerek kuleleri atlar';
      case EnemyType.troll: return 'Saniyede 3 HP yenilenir';
      case EnemyType.darkKnight: return 'Yakındaki düşmanlara +5 bonus zırh';
      case EnemyType.shadowLord: return 'Boss - Yüksek HP, güçlü saldırı';
      case EnemyType.dragonEmperor: return 'Son Boss - En güçlü düşman';
      default: return null;
    }
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

  Color _enemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.soldier: return const Color(0xFFCC3333);
      case EnemyType.cavalry: return const Color(0xFFFF6600);
      case EnemyType.goblin: return const Color(0xFF33CC33);
      case EnemyType.armoredGiant: return const Color(0xFF999999);
      case EnemyType.undead: return const Color(0xFF666688);
      case EnemyType.shieldBearer: return const Color(0xFF4488CC);
      case EnemyType.healer: return const Color(0xFFFFFFFF);
      case EnemyType.burrower: return const Color(0xFF886633);
      case EnemyType.troll: return const Color(0xFF338833);
      case EnemyType.darkKnight: return const Color(0xFF330033);
      case EnemyType.shadowLord: return const Color(0xFF220022);
      case EnemyType.dragonEmperor: return const Color(0xFFFF0000);
    }
  }
}
