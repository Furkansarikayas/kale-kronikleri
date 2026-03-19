import 'package:flutter/material.dart';
import '../game/data/tower_data.dart';

class GameHud extends StatefulWidget {
  final int castleHp;
  final int maxCastleHp;
  final int gold;
  final int currentWave;
  final int totalWaves;
  final List<TowerType> availableTowers;
  final TowerType? selectedTower;
  final bool isWaveActive;
  final int towerSlots;
  final int towersPlaced;
  final List<String> activeSynergies;
  final VoidCallback onStartWave;
  final VoidCallback onPause;
  final ValueChanged<TowerType?> onTowerSelected;

  const GameHud({
    super.key,
    required this.castleHp,
    required this.maxCastleHp,
    required this.gold,
    required this.currentWave,
    required this.totalWaves,
    required this.availableTowers,
    required this.selectedTower,
    required this.isWaveActive,
    required this.towerSlots,
    required this.towersPlaced,
    required this.activeSynergies,
    required this.onStartWave,
    required this.onPause,
    required this.onTowerSelected,
  });

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> {
  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar: HP, gold, wave, pause
        _buildTopBar(),
        const Spacer(),
        // Bottom bar: tower selection + start wave
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: _darkBg.withAlpha(200),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // HP bar
            _buildHpBar(),
            const SizedBox(width: 16),
            // Gold
            Icon(Icons.monetization_on, color: _gold, size: 20),
            const SizedBox(width: 4),
            Text(
              '${widget.gold}',
              style: const TextStyle(color: _cream, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            // Wave counter
            Icon(Icons.waves, color: _cream.withAlpha(180), size: 18),
            const SizedBox(width: 4),
            Text(
              '${widget.currentWave}/${widget.totalWaves}',
              style: const TextStyle(color: _cream, fontSize: 14),
            ),
            const SizedBox(width: 8),
            // Tower slots
            Icon(Icons.grid_view, color: _cream.withAlpha(180), size: 18),
            const SizedBox(width: 4),
            Text(
              '${widget.towersPlaced}/${widget.towerSlots}',
              style: const TextStyle(color: _cream, fontSize: 14),
            ),
            const Spacer(),
            // Active synergies indicator
            if (widget.activeSynergies.isNotEmpty)
              Tooltip(
                message: widget.activeSynergies.join('\n'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _gold.withAlpha(60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: _gold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.activeSynergies.length}',
                        style: const TextStyle(color: _gold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // Pause button
            IconButton(
              onPressed: widget.onPause,
              icon: const Icon(Icons.pause, color: _cream),
              iconSize: 24,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHpBar() {
    final ratio = widget.maxCastleHp > 0 ? widget.castleHp / widget.maxCastleHp : 0.0;
    final barColor = ratio > 0.5
        ? Color.lerp(Colors.yellow, Colors.green, (ratio - 0.5) * 2)!
        : Color.lerp(Colors.red, Colors.yellow, ratio * 2)!;

    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.castleHp}/${widget.maxCastleHp}',
            style: const TextStyle(color: _cream, fontSize: 10),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _darkBg.withAlpha(220),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tower grid (2 rows x 6 cols)
            Expanded(child: _buildTowerGrid()),
            const SizedBox(width: 8),
            // Start wave / wave active indicator
            if (!widget.isWaveActive)
              ElevatedButton.icon(
                onPressed: widget.onStartWave,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Dalga'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _darkBg,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 18),
                    SizedBox(width: 4),
                    Text('DALGA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTowerGrid() {
    final towers = widget.availableTowers;
    return SizedBox(
      height: 80,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.85,
        ),
        itemCount: towers.length,
        itemBuilder: (context, index) {
          final tower = towers[index];
          final stats = TowerData.getStats(tower);
          final isSelected = widget.selectedTower == tower;
          final canAfford = widget.gold >= stats.cost;
          final hasSlot = widget.towersPlaced < widget.towerSlots;

          return GestureDetector(
            onTap: () {
              if (canAfford && hasSlot) {
                widget.onTowerSelected(isSelected ? null : tower);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? _gold.withAlpha(100) : _darkBg,
                border: Border.all(
                  color: isSelected ? _gold : (canAfford ? _cream.withAlpha(80) : Colors.red.withAlpha(80)),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _towerIcon(tower),
                    color: canAfford ? _cream : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stats.cost}',
                    style: TextStyle(
                      color: canAfford ? _gold : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
}
