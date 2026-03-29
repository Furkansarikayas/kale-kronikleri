import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/data/tower_data.dart';
import '../game/data/synergy_data.dart';
import '../game/data/t4_branch_data.dart';
import '../game/components/towers/tower.dart';
import '../game/systems/spell_system.dart';
import 'widgets/glass_panel.dart';

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
  final int secondaryShield;
  final int maxSecondaryShield;
  final bool showSynergyHints;
  final bool autoWave;
  final VoidCallback? onToggleAutoWave;
  final VoidCallback? onCycleTargeting;
  final int waveEnemyTotal;

  // Spell system
  final List<SpellType> availableSpells;
  final Map<SpellType, double> spellCooldowns;
  final Map<SpellType, double> spellMaxCooldowns;
  final ValueChanged<SpellType>? onCastSpell;

  // T4 branch selection
  final Tower? pendingT4Tower;
  final ValueChanged<T4BranchPath>? onT4BranchSelected;
  final VoidCallback? onT4Cancel;

  // Tutorial
  final String? tutorialMessage;
  final VoidCallback? onDismissTutorial;

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
    this.secondaryShield = 0,
    this.maxSecondaryShield = 0,
    this.showSynergyHints = false,
    this.autoWave = false,
    this.onToggleAutoWave,
    this.onCycleTargeting,
    this.waveEnemyTotal = 0,
    this.availableSpells = const [],
    this.spellCooldowns = const {},
    this.spellMaxCooldowns = const {},
    this.onCastSpell,
    this.pendingT4Tower,
    this.onT4BranchSelected,
    this.onT4Cancel,
    this.tutorialMessage,
    this.onDismissTutorial,
  });

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> with TickerProviderStateMixin {
  static const _bgDark = Color(0xFF0D0D15);
  static const _gold = Color(0xFFD4A843);
  static const _goldDark = Color(0xFFBA7517);
  static const _cream = Color(0xFFF0E6D0);
  static const _creamDim = Color(0xAAB8AE98);

  late AnimationController _pulseController;
  late AnimationController _goldFlashController;
  int _prevGold = 0;

  @override
  void initState() {
    super.initState();
    _prevGold = widget.gold;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _goldFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant GameHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gold != _prevGold) {
      _goldFlashController.forward(from: 0);
      _prevGold = widget.gold;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _goldFlashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            if (widget.tutorialMessage != null)
              _buildTutorialHint(widget.tutorialMessage!),
            if (widget.showSynergyHints && widget.selectedTower != null)
              _buildSynergyHints(widget.selectedTower!),
            if (widget.availableSpells.isNotEmpty)
              _buildSpellBar(),
            _buildBottomBar(),
          ],
        ),
        if (widget.pendingT4Tower != null)
          _buildT4BranchOverlay(widget.pendingT4Tower!),
      ],
    );
  }

  Widget _buildTutorialHint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 10,
        borderColor: _gold.withAlpha(120),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _gold.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_outline, color: _gold, size: 14),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: TextStyle(color: _cream.withAlpha(210), fontSize: 10, letterSpacing: 0.3),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onDismissTutorial,
              child: Icon(Icons.close, color: _cream.withAlpha(120), size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xAA0D0D15),
            border: const Border(
              bottom: BorderSide(color: Color(0x55D4A843), width: 1),
            ),
            boxShadow: [
              BoxShadow(color: const Color(0x33D4A843).withValues(alpha: 0.1), blurRadius: 12, spreadRadius: 1),
              BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  _buildHpBar(),
                  const SizedBox(width: 12),
                  _buildGoldDisplay(),
                  const SizedBox(width: 10),
                  _buildWaveCounter(),
                  const SizedBox(width: 8),
                  _buildSlotsBadge(),
                  if (widget.isWaveActive && widget.waveEnemyTotal > 0) ...[
                    const SizedBox(width: 8),
                    _buildEnemyCounter(),
                  ],
                  const Spacer(),
                  if (widget.activeSynergies.isNotEmpty) ...[
                    _buildSynergyBadge(),
                    const SizedBox(width: 6),
                  ],
                  _buildAutoWaveButton(),
                  const SizedBox(width: 4),
                  _buildSpeedButton(),
                  const SizedBox(width: 6),
                  _buildPauseButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoldDisplay() {
    return AnimatedBuilder(
      animation: _goldFlashController,
      builder: (context, child) {
        final flash = _goldFlashController.value;
        final glowAlpha = (80 + 120 * (1 - flash)).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgDark.withAlpha(200), _bgDark.withAlpha(150)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: flash > 0 ? _gold.withAlpha(glowAlpha) : _gold.withAlpha(120),
              width: flash > 0 ? 1.5 : 1,
            ),
            boxShadow: flash > 0
                ? [BoxShadow(color: _gold.withAlpha((60 * (1 - flash)).round()), blurRadius: 10)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: _gold.withAlpha(80), blurRadius: 6, spreadRadius: 1),
                  ],
                ),
                child: const Icon(Icons.monetization_on, color: _gold, size: 18),
              ),
              const SizedBox(width: 5),
              Text(
                '${widget.gold}',
                style: TextStyle(
                  color: flash > 0 ? const Color(0xFFFFEEAA) : _gold,
                  fontSize: flash > 0 ? 16 : 15,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Color(0x88D4A843), blurRadius: 4)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4488CC).withAlpha(100), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.waves, color: Color(0xFF6699CC), size: 15),
          const SizedBox(width: 5),
          Text(
            '${widget.currentWave}/${widget.totalWaves}',
            style: const TextStyle(color: _cream, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1E1A), Color(0xFF0D150D)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF66AA66).withAlpha(100), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_view, color: Color(0xFF88CC88), size: 15),
          const SizedBox(width: 5),
          Text(
            '${widget.towersPlaced}/${widget.towerSlots}',
            style: const TextStyle(color: _cream, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEnemyCounter() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.6 + 0.4 * _pulseController.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromRGBO(180, 40, 40, 0.3 * opacity), Color.fromRGBO(120, 20, 20, 0.2 * opacity)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withAlpha((140 * opacity).round()), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pest_control, color: Colors.red.withAlpha((220 * opacity).round()), size: 15),
              const SizedBox(width: 5),
              Text(
                '${widget.enemiesAlive}/${widget.waveEnemyTotal}',
                style: TextStyle(color: Colors.red.withAlpha(230), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSynergyBadge() {
    return Tooltip(
      message: widget.activeSynergies.join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_gold.withAlpha(50), _gold.withAlpha(30)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold.withAlpha(100)),
          boxShadow: [
            BoxShadow(color: _gold.withAlpha(20), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: _gold, size: 14),
            const SizedBox(width: 4),
            Text(
              '${widget.activeSynergies.length}',
              style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoWaveButton() {
    final active = widget.autoWave;
    return GestureDetector(
      onTap: widget.onToggleAutoWave,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: [Color(0x55D4A843), Color(0x33BA7517)])
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _gold : _creamDim.withAlpha(60),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fast_forward,
              color: active ? _gold : _creamDim.withAlpha(140),
              size: 14,
            ),
            const SizedBox(width: 3),
            Text(
              'Oto',
              style: TextStyle(
                color: active ? _gold : _creamDim.withAlpha(140),
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButton() {
    final fast = widget.gameSpeed > 1;
    return GestureDetector(
      onTap: widget.onToggleSpeed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: fast
              ? const LinearGradient(colors: [Color(0x55D4A843), Color(0x33BA7517)])
              : null,
          color: fast ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: fast ? _gold : _creamDim.withAlpha(60),
            width: fast ? 1.5 : 1,
          ),
        ),
        child: Text(
          '${widget.gameSpeed.toStringAsFixed(0)}x',
          style: TextStyle(
            color: fast ? _gold : _cream,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPauseButton() {
    return GestureDetector(
      onTap: widget.onPause,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _bgDark.withAlpha(180),
          shape: BoxShape.circle,
          border: Border.all(color: _creamDim.withAlpha(80)),
        ),
        child: const Icon(Icons.pause, color: _cream, size: 20),
      ),
    );
  }

  Widget _buildHpBar() {
    final ratio = widget.maxCastleHp > 0 ? widget.castleHp / widget.maxCastleHp : 0.0;
    final hasShield = widget.maxSecondaryShield > 0;
    final isLowHp = ratio > 0 && ratio < 0.3;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = isLowHp ? (40 + (60 * _pulseController.value)).round() : 0;
        return Container(
          width: 110,
          padding: const EdgeInsets.all(2),
          decoration: isLowHp
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withAlpha(glowAlpha),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(glowAlpha ~/ 2),
                      blurRadius: 8 + 4 * _pulseController.value,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: Color(0xFFEE4444), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    hasShield
                        ? '${widget.castleHp}/${widget.maxCastleHp} +${widget.secondaryShield}'
                        : '${widget.castleHp}/${widget.maxCastleHp}',
                    style: const TextStyle(color: _cream, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              CustomPaint(
                size: const Size(106, 8),
                painter: _HpBarPainter(ratio: ratio, isFull: ratio >= 1.0),
              ),
              if (hasShield) ...[
                const SizedBox(height: 2),
                CustomPaint(
                  size: const Size(106, 4),
                  painter: _ShieldBarPainter(
                    ratio: widget.maxSecondaryShield > 0
                        ? widget.secondaryShield / widget.maxSecondaryShield
                        : 0.0,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final placedTower = widget.selectedPlacedTower;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (placedTower != null)
              Flexible(child: _buildTowerInfoPanel(placedTower))
            else
              Flexible(child: _buildTowerGrid()),
            const SizedBox(width: 6),
            if (!widget.isWaveActive)
              _buildStartWaveButton()
            else
              _buildWaveActiveIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartWaveButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowIntensity = 0.3 + 0.7 * _pulseController.value;
        return GestureDetector(
          onTap: widget.onStartWave,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_gold, _goldDark],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8C878), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _gold.withAlpha((60 * glowIntensity).round()),
                  blurRadius: 12 * glowIntensity,
                  spreadRadius: 2 * glowIntensity,
                ),
                BoxShadow(
                  color: _goldDark.withAlpha((40 * glowIntensity).round()),
                  blurRadius: 20 * glowIntensity,
                  spreadRadius: 4 * glowIntensity,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: _bgDark, size: 20),
                SizedBox(width: 6),
                Text(
                  'Dalga',
                  style: TextStyle(
                    color: _bgDark,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    shadows: [Shadow(color: Color(0x44FFFFFF), blurRadius: 2)],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveActiveIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 0.6 + 0.4 * _pulseController.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withAlpha((60 * pulse).round()),
                Colors.red.withAlpha((30 * pulse).round()),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withAlpha((150 * pulse).round()), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withAlpha((30 * pulse).round()),
                blurRadius: 10 * pulse,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gavel, color: Colors.red.withAlpha((220 * pulse).round()), size: 18),
              const SizedBox(width: 5),
              Text(
                'DALGA',
                style: TextStyle(
                  color: Colors.red.withAlpha(230),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTowerInfoPanel(Tower tower) {
    final stats = tower.stats;
    final tierName = tower.tier == 4 && tower.t4Branch != T4BranchPath.none
        ? tower.t4Name
        : stats.tierNames[tower.tier - 1];
    final canTarget = tower.type != TowerType.spikeWall && tower.type != TowerType.support;
    final tColor = _towerTypeColor(tower.type);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA0D0D15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tColor.withAlpha(100)),
        boxShadow: [
          BoxShadow(color: tColor.withAlpha(20), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tColor.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: tColor.withAlpha(120)),
            ),
            child: Image.asset(
              'assets/images/towers/${tower.type.name}_t${tower.tier}.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(_towerIcon(tower.type), color: tColor, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$tierName (Lv.${tower.tier})',
                  style: TextStyle(
                    color: _cream,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: tColor.withAlpha(80), blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tower.type == TowerType.support
                      ? 'Buff: +${(15 * tower.tier)}% hasar komşu kulelere'
                      : 'Hasar: ${tower.currentDamage}  Menzil: ${tower.currentRange.toStringAsFixed(1)}',
                  style: TextStyle(color: _cream.withAlpha(180), fontSize: 10),
                ),
                Text(
                  'Kills: ${tower.kills}  Toplam: ${tower.totalDamageDealt}',
                  style: TextStyle(color: _creamDim.withAlpha(160), fontSize: 9),
                ),
              ],
            ),
          ),
          if (canTarget)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: widget.onCycleTargeting,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: _bgDark,
                    border: Border.all(color: _creamDim.withAlpha(80)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_targetingIcon(tower.targetingMode), color: _cream, size: 16),
                      const SizedBox(height: 1),
                      Text(
                        _targetingLabel(tower.targetingMode),
                        style: TextStyle(color: _creamDim.withAlpha(200), fontSize: 7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (tower.canUpgrade)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: widget.gold >= tower.upgradeCost ? widget.onUpgradeTower : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: widget.gold >= tower.upgradeCost
                        ? const LinearGradient(colors: [Color(0xFF2D7D2D), Color(0xFF1B5E1B)])
                        : null,
                    color: widget.gold >= tower.upgradeCost ? null : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.gold >= tower.upgradeCost
                          ? Colors.green.withAlpha(160)
                          : Colors.grey.withAlpha(60),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward,
                        size: 16,
                        color: widget.gold >= tower.upgradeCost ? _cream : Colors.grey,
                      ),
                      Text(
                        '${tower.upgradeCost}g',
                        style: TextStyle(
                          fontSize: 9,
                          color: widget.gold >= tower.upgradeCost ? _gold : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: widget.onSellTower,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B2020), Color(0xFF6B1515)]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(120)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sell, size: 16, color: _cream),
                  Text(
                    '+${tower.sellValue}g',
                    style: const TextStyle(fontSize: 9, color: _gold, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildSynergyHints(TowerType selected) {
    final relevant = SynergyData.all.where((s) =>
      s.requiredTowers.contains(selected)
    ).toList();
    if (relevant.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        borderRadius: 8,
        borderColor: _gold.withAlpha(100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: _gold, size: 12),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                relevant.map((s) {
                  final others = s.requiredTowers
                      .where((t) => t != selected || s.requiredTowers.where((r) => r == t).length > 1)
                      .toSet()
                      .map((t) => TowerData.getStats(t).name.split(' ').first)
                      .join('+');
                  return '${s.name} (${others.isNotEmpty ? "+$others" : "\u00d73"})';
                }).join('  |  '),
                style: TextStyle(color: _cream.withAlpha(200), fontSize: 9),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpellBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: widget.availableSpells.map((spell) {
          final cd = widget.spellCooldowns[spell] ?? 0;
          final maxCd = widget.spellMaxCooldowns[spell] ?? 1;
          final ready = cd <= 0;
          final def = SpellSystem.getDef(spell);
          String spellAsset;
          Color color;
          switch (spell) {
            case SpellType.fireRain: spellAsset = 'assets/images/effects/fire_rain.png'; color = const Color(0xFFFF5511); break;
            case SpellType.iceStorm: spellAsset = 'assets/images/effects/ice_storm.png'; color = const Color(0xFF22CCEE); break;
            case SpellType.castleRepair: spellAsset = 'assets/images/effects/castle_repair.png'; color = const Color(0xFF00CC44); break;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Tooltip(
              message: '${def.name}\n${def.description}',
              child: GestureDetector(
                onTap: ready && widget.isWaveActive ? () => widget.onCastSpell?.call(spell) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ready ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color.withAlpha(80), color.withAlpha(40)],
                        ) : null,
                        color: ready ? null : const Color(0x33333333),
                        border: Border.all(
                          color: ready ? color : _creamDim.withAlpha(50),
                          width: ready ? 2 : 1,
                        ),
                        boxShadow: ready ? [
                          BoxShadow(color: color.withAlpha(50), blurRadius: 8, spreadRadius: 1),
                        ] : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipOval(
                            child: ColorFiltered(
                              colorFilter: ready
                                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                  : const ColorFilter.matrix(<double>[
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0, 0, 0, 0.4, 0,
                                    ]),
                              child: Image.asset(
                                spellAsset,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome, color: ready ? color : _creamDim.withAlpha(80), size: 18),
                              ),
                            ),
                          ),
                          if (!ready)
                            SizedBox(
                              width: 40, height: 40,
                              child: CircularProgressIndicator(
                                value: 1 - (cd / maxCd).clamp(0, 1),
                                strokeWidth: 2.5,
                                color: color.withAlpha(150),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          if (!ready)
                            Text(
                              '${cd.ceil()}',
                              style: TextStyle(color: _cream.withAlpha(200), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      def.name.split(' ').first,
                      style: TextStyle(color: ready ? color.withAlpha(200) : _creamDim.withAlpha(100), fontSize: 7),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildT4BranchOverlay(Tower tower) {
    final branch = T4BranchData.getBranch(tower.type);
    final tColor = _towerTypeColor(tower.type);

    return Container(
      color: const Color(0xAA000000),
      child: Center(
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          borderRadius: 12,
          borderColor: _gold,
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'T4 Uzmanlaşma Seç',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: _gold.withAlpha(80), blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  TowerData.getStats(tower.type).name,
                  style: TextStyle(color: _cream.withAlpha(180), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildT4Card(branch.nameA, branch.descA, tColor, T4BranchPath.pathA)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildT4Card(branch.nameB, branch.descB, tColor, T4BranchPath.pathB)),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: widget.onT4Cancel,
                  child: Text('İptal', style: TextStyle(color: _creamDim.withAlpha(160), fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildT4Card(String name, String desc, Color color, T4BranchPath path) {
    // Show stat multipliers for this path
    String statHint = '';
    if (widget.pendingT4Tower != null) {
      final branch = T4BranchData.getBranch(widget.pendingT4Tower!.type);
      final dmg = path == T4BranchPath.pathA ? branch.dmgMultA : branch.dmgMultB;
      final range = path == T4BranchPath.pathA ? branch.rangeMultA : branch.rangeMultB;
      final rate = path == T4BranchPath.pathA ? branch.fireRateMultA : branch.fireRateMultB;
      final parts = <String>[];
      if (dmg != 1.0) parts.add('Hasar x${dmg.toStringAsFixed(1)}');
      if (range != 1.0) parts.add('Menzil x${range.toStringAsFixed(1)}');
      if (rate != 1.0) parts.add('Hız x${rate.toStringAsFixed(1)}');
      statHint = parts.join('  ');
    }

    return GestureDetector(
      onTap: () => widget.onT4BranchSelected?.call(path),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [color.withAlpha(50), const Color(0xFF1A1510)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(140), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withAlpha(20), blurRadius: 8),
          ],
        ),
        child: Column(
          children: [
            Icon(path == T4BranchPath.pathA ? Icons.local_fire_department : Icons.shield, color: color, size: 20),
            const SizedBox(height: 4),
            Text(name, style: TextStyle(color: _cream, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(desc, textAlign: TextAlign.center,
              style: TextStyle(color: _cream.withAlpha(180), fontSize: 10)),
            if (statHint.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(statHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color.withAlpha(200), fontSize: 8, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTowerGrid() {
    final towers = widget.availableTowers;
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: towers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final tower = towers[index];
          final stats = TowerData.getStats(tower);
          final isSelected = widget.selectedTower == tower;
          final canAfford = widget.gold >= stats.cost;
          final hasSlot = widget.towersPlaced < widget.towerSlots;
          final tColor = _towerTypeColor(tower);

          return Tooltip(
            message: '${stats.name}\nHasar: ${stats.damage} | Menzil: ${stats.range} | Hiz: ${stats.fireRate}s\n${_towerAbility(tower)}',
            child: GestureDetector(
              onTap: () {
                if (canAfford && hasSlot) {
                  widget.onTowerSelected(isSelected ? null : tower);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isSelected
                        ? [tColor.withAlpha(60), const Color(0xFF1A1510)]
                        : canAfford
                            ? [const Color(0xFF1E1E28), const Color(0xFF14141C)]
                            : [const Color(0xFF1A1215), const Color(0xFF0E0A0C)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _gold : (canAfford ? tColor.withAlpha(80) : Colors.grey[700]!.withAlpha(40)),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(color: _gold.withAlpha(60), blurRadius: 10, spreadRadius: 2),
                          BoxShadow(color: tColor.withAlpha(30), blurRadius: 6),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Tower sprite filling the card
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                        child: Image.asset(
                          'assets/images/towers/${tower.name}_t1.png',
                          fit: BoxFit.contain,
                          opacity: AlwaysStoppedAnimation(canAfford ? 1.0 : 0.35),
                          errorBuilder: (_, __, ___) => Icon(
                            _towerIcon(tower),
                            color: canAfford ? tColor : Colors.grey[600],
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    // Color accent bar at top
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: canAfford ? tColor : Colors.grey[700],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(9),
                            topRight: Radius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    // Gold cost badge at bottom
                    Positioned(
                      bottom: 2, left: 0, right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: canAfford
                                ? const Color(0xDD1A1510)
                                : const Color(0xCC0E0A0C),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: canAfford ? _gold.withAlpha(160) : Colors.grey[700]!.withAlpha(80),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${stats.cost}g',
                            style: TextStyle(
                              color: canAfford ? _gold : Colors.grey[600],
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 1),
              Text(
                stats.name.split(' ').first,
                style: TextStyle(
                  color: isSelected ? _gold : (canAfford ? _cream.withAlpha(160) : Colors.grey[700]),
                  fontSize: 7,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Color _towerTypeColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFFCCCCCC);
      case TowerType.ice: return const Color(0xFF22CCEE);
      case TowerType.fire: return const Color(0xFFFF5511);
      case TowerType.lightning: return const Color(0xFFFFDD00);
      case TowerType.poison: return const Color(0xFF33FF33);
      case TowerType.cannon: return const Color(0xFF8899AA);
      case TowerType.spikeWall: return const Color(0xFF8B6535);
      case TowerType.support: return const Color(0xFFDDCC00);
      case TowerType.water: return const Color(0xFF4488FF);
      case TowerType.wizard: return const Color(0xFFAA33DD);
      case TowerType.dark: return const Color(0xFF8B00FF);
      case TowerType.holy: return const Color(0xFFFFDD66);
    }
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

  IconData _targetingIcon(TargetingMode mode) {
    switch (mode) {
      case TargetingMode.nearest: return Icons.near_me;
      case TargetingMode.first: return Icons.first_page;
      case TargetingMode.strongest: return Icons.fitness_center;
    }
  }

  String _targetingLabel(TargetingMode mode) {
    switch (mode) {
      case TargetingMode.nearest: return 'Yakın';
      case TargetingMode.first: return 'İlk';
      case TargetingMode.strongest: return 'Güçlü';
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

// Custom HP bar painter with gradient fill, rounded ends, inner shadow, and glow
class _HpBarPainter extends CustomPainter {
  final double ratio;
  final bool isFull;

  _HpBarPainter({required this.ratio, required this.isFull});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final radius = h / 2;

    // Background with embossed border
    final bgRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(radius));
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF1A1A22));

    // Border (embossed feel)
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = const Color(0xFF333340)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    if (ratio > 0) {
      final fillW = w * ratio.clamp(0.0, 1.0);
      final fillRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, fillW, h), Radius.circular(radius));

      // Determine bar color based on ratio
      Color startColor, endColor;
      if (ratio > 0.5) {
        startColor = Color.lerp(const Color(0xFFCCCC00), const Color(0xFF22AA22), (ratio - 0.5) * 2)!;
        endColor = Color.lerp(const Color(0xFFAAAA00), const Color(0xFF118811), (ratio - 0.5) * 2)!;
      } else {
        startColor = Color.lerp(const Color(0xFFCC2222), const Color(0xFFCCCC00), ratio * 2)!;
        endColor = Color.lerp(const Color(0xFFAA1111), const Color(0xFFAAAA00), ratio * 2)!;
      }

      // Gradient fill
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [startColor, endColor],
        ).createShader(Rect.fromLTWH(0, 0, fillW, h));
      canvas.drawRRect(fillRect, fillPaint);

      // Inner highlight (top edge shine)
      final highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withAlpha(60), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, fillW, h / 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, fillW - 2, h / 2), Radius.circular(radius)),
        highlightPaint,
      );

      // Glow when full
      if (isFull) {
        canvas.drawRRect(
          bgRect,
          Paint()
            ..color = const Color(0xFF22AA22).withAlpha(40)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
        );
      }
    }

    // Inner shadow on top
    canvas.drawRRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withAlpha(50), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_HpBarPainter old) => old.ratio != ratio || old.isFull != isFull;
}

// Shield bar painter
class _ShieldBarPainter extends CustomPainter {
  final double ratio;

  _ShieldBarPainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final radius = h / 2;

    final bgRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(radius));
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF0A0A14));

    if (ratio > 0) {
      final fillW = w * ratio.clamp(0.0, 1.0);
      final fillRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, fillW, h), Radius.circular(radius));
      final fillPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3366CC), Color(0xFF4488FF)],
        ).createShader(Rect.fromLTWH(0, 0, fillW, h));
      canvas.drawRRect(fillRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_ShieldBarPainter old) => old.ratio != ratio;
}
