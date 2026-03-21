import 'package:flutter/material.dart';
import '../game/data/tower_data.dart';
import '../game/components/towers/tower.dart';

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
  final int enemiesAlive;
  final int enemiesKilled;
  final List<String> activeSynergies;
  final Tower? selectedPlacedTower;
  final VoidCallback onStartWave;
  final VoidCallback onPause;
  final ValueChanged<TowerType?> onTowerSelected;
  final VoidCallback? onSellTower;
  final VoidCallback? onUpgradeTower;
  final VoidCallback? onToggleSpeed;
  final double gameSpeed;

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
    this.enemiesAlive = 0,
    this.enemiesKilled = 0,
    required this.activeSynergies,
    this.selectedPlacedTower,
    required this.onStartWave,
    required this.onPause,
    required this.onTowerSelected,
    this.onSellTower,
    this.onUpgradeTower,
    this.onToggleSpeed,
    this.gameSpeed = 1.0,
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
        // Tutorial hint on first wave prep
        if (widget.currentWave == 0 && !widget.isWaveActive)
          _buildTutorialHint(),
        // Bottom bar: tower selection + start wave
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildTutorialHint() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _darkBg.withAlpha(230),
        border: Border.all(color: _gold.withAlpha(100)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: _gold, size: 16),
          const SizedBox(width: 8),
          Text(
            'Aşağıdan kule seç → Yeşil alana yerleştir → Dalga başlat!',
            style: TextStyle(color: _cream.withAlpha(200), fontSize: 11),
          ),
        ],
      ),
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
            // Enemy count (during wave)
            if (widget.isWaveActive && widget.enemiesAlive > 0) ...[
              const SizedBox(width: 8),
              Icon(Icons.pest_control, color: Colors.red.withAlpha(180), size: 16),
              const SizedBox(width: 3),
              Text(
                '${widget.enemiesAlive}',
                style: TextStyle(color: Colors.red.withAlpha(200), fontSize: 13),
              ),
            ],
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
            // Speed button
            GestureDetector(
              onTap: widget.onToggleSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.gameSpeed > 1 ? _gold.withAlpha(80) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _cream.withAlpha(80)),
                ),
                child: Text(
                  '${widget.gameSpeed.toStringAsFixed(0)}x',
                  style: TextStyle(
                    color: widget.gameSpeed > 1 ? _gold : _cream,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
    final placedTower = widget.selectedPlacedTower;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _darkBg.withAlpha(220),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tower info panel or tower grid
            if (placedTower != null)
              Expanded(child: _buildTowerInfoPanel(placedTower))
            else
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

  Widget _buildTowerInfoPanel(Tower tower) {
    final stats = tower.stats;
    final tierName = stats.tierNames[tower.tier - 1];

    return SizedBox(
      height: 80,
      child: Row(
        children: [
          // Tower info
          Icon(_towerIcon(tower.type), color: _cream, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$tierName (Lv.${tower.tier})',
                  style: const TextStyle(color: _cream, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  tower.type == TowerType.support
                      ? 'Buff: +${(15 * tower.tier)}% hasar komşu kulelere'
                      : 'Hasar: ${tower.currentDamage}  Menzil: ${tower.currentRange.toStringAsFixed(1)}',
                  style: TextStyle(color: _cream.withAlpha(180), fontSize: 10),
                ),
                Text(
                  'Kills: ${tower.kills}  Toplam: ${tower.totalDamageDealt}',
                  style: TextStyle(color: _cream.withAlpha(120), fontSize: 9),
                ),
              ],
            ),
          ),
          // Upgrade button
          if (tower.canUpgrade)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ElevatedButton(
                onPressed: widget.gold >= tower.upgradeCost ? widget.onUpgradeTower : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: _cream,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward, size: 16),
                    Text('${tower.upgradeCost}g', style: const TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
          // Sell button
          ElevatedButton(
            onPressed: widget.onSellTower,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: _cream,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sell, size: 16),
                Text('+${tower.sellValue}g', style: const TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ],
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

          return Tooltip(
            message: '${stats.name}\nHasar: ${stats.damage} | Menzil: ${stats.range} | Hiz: ${stats.fireRate}s\n${_towerAbility(tower)}',
            child: GestureDetector(
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
            ),
          );
        },
      ),
    );
  }

  String _towerAbility(TowerType type) {
    switch (type) {
      case TowerType.arrow: return 'Hızlı ateş';
      case TowerType.ice: return 'Yavaşlatma efekti';
      case TowerType.fire: return 'Yanma hasarı';
      case TowerType.lightning: return 'Islak düşmanlara 2x hasar';
      case TowerType.poison: return 'Zaman içinde zehir hasarı';
      case TowerType.cannon: return 'Alan hasarı (AoE patlama)';
      case TowerType.spikeWall: return 'Yol üzerine yerleşir, temas hasarı';
      case TowerType.support: return 'Komşu kuleleri güçlendirir';
      case TowerType.water: return 'Islak efekti (yıldırım ile combo)';
      case TowerType.wizard: return 'Zincir hasar (çoklu hedef)';
      case TowerType.dark: return 'Lanet: zırh azaltma';
      case TowerType.holy: return 'Karanlık düşmanlara +%50 hasar';
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
}
