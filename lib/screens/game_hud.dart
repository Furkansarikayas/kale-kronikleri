import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/data/tower_data.dart';
import '../game/data/synergy_data.dart';
import '../game/data/t4_branch_data.dart';
import '../game/components/towers/tower.dart';
import '../game/systems/spell_system.dart';
import '../game/systems/mutation_system.dart';
import '../game/systems/wave_buff_system.dart';
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

  // Merge system
  final int mergeCandidateCount;

  // Active mutations
  final List<MutationType> activeMutations;

  // Gold UI reject feedback
  final int goldRejectCounter;

  // Run objectives
  final bool objWaves;
  final bool objKills;
  final bool objBoss;

  // Active run buffs
  final List<WaveBuff> activeBuffs;

  // Wave 2 tower choice
  final bool pendingTowerChoice;
  final ValueChanged<TowerType>? onTowerChoice;

  // Build identity label
  final String buildLabel;

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
    this.mergeCandidateCount = 0,
    this.activeMutations = const [],
    this.goldRejectCounter = 0,
    this.objWaves = false,
    this.objKills = false,
    this.objBoss = false,
    this.activeBuffs = const [],
    this.pendingTowerChoice = false,
    this.onTowerChoice,
    this.buildLabel = '',
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
  late AnimationController _goldRejectController;
  late AnimationController _buffPulseController;
  int _prevGold = 0;
  int _goldDelta = 0;
  int _prevRejectCounter = 0;
  int _prevBuffCount = 0;
  TowerCategory? _selectedCategory;
  TowerType? _previewTower;

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
    _goldRejectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _buffPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _prevRejectCounter = widget.goldRejectCounter;
    _prevBuffCount = widget.activeBuffs.length;
  }

  @override
  void didUpdateWidget(covariant GameHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gold != _prevGold) {
      _goldDelta = widget.gold - _prevGold;
      _goldFlashController.forward(from: 0);
      _prevGold = widget.gold;
    }
    if (widget.goldRejectCounter != _prevRejectCounter) {
      _goldRejectController.forward(from: 0);
      _prevRejectCounter = widget.goldRejectCounter;
    }
    if (widget.activeBuffs.length != _prevBuffCount) {
      if (widget.activeBuffs.length > _prevBuffCount) {
        _buffPulseController.forward(from: 0);
      }
      _prevBuffCount = widget.activeBuffs.length;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _goldFlashController.dispose();
    _goldRejectController.dispose();
    _buffPulseController.dispose();
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
        if (widget.pendingTowerChoice)
          _buildTowerChoiceOverlay(),
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                children: [
                  _buildHpBar(),
                  const SizedBox(width: 6),
                  _buildGoldDisplay(),
                  const SizedBox(width: 6),
                  _buildWaveCounter(),
                  const SizedBox(width: 5),
                  _buildSlotsBadge(),
                  if (widget.isWaveActive && widget.waveEnemyTotal > 0) ...[
                    const SizedBox(width: 5),
                    _buildEnemyCounter(),
                  ],
                  const SizedBox(width: 5),
                  _buildObjectives(),
                  if (widget.buildLabel.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    _buildBuildLabel(),
                  ],
                  const Spacer(),
                  if (widget.activeBuffs.isNotEmpty) ...[
                    _buildActiveBuffs(),
                    const SizedBox(width: 4),
                  ],
                  if (widget.activeMutations.isNotEmpty) ...[
                    _buildMutationBadge(),
                    const SizedBox(width: 4),
                  ],
                  if (widget.activeSynergies.isNotEmpty) ...[
                    _buildSynergyBadge(),
                    const SizedBox(width: 4),
                  ],
                  _buildAutoWaveButton(),
                  const SizedBox(width: 3),
                  _buildSpeedButton(),
                  const SizedBox(width: 4),
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
      animation: Listenable.merge([_goldFlashController, _goldRejectController]),
      builder: (context, child) {
        final flash = _goldFlashController.value;
        final reject = _goldRejectController.value;
        final isGain = _goldDelta > 0;
        final isLargeGain = _goldDelta >= 15;

        // Reject shake: horizontal oscillation that decays
        final shakeOffset = reject < 1.0
            ? (reject < 0.5 ? reject * 2 : (1.0 - reject) * 2)
                * 3.0
                * (reject < 0.25 ? 1 : reject < 0.5 ? -1 : reject < 0.75 ? 1 : -1)
            : 0.0;

        // Border color: gain = warm gold, spend = dim, reject = red
        Color borderColor;
        double borderWidth = 1.0;
        if (reject < 1.0) {
          final rejectAlpha = ((1.0 - reject) * 200).round().clamp(0, 255);
          borderColor = Color.fromARGB(rejectAlpha, 255, 60, 40);
          borderWidth = 1.5;
        } else if (flash > 0) {
          final glowAlpha = (80 + 120 * (1 - flash)).round();
          borderColor = isGain
              ? Color.fromARGB(glowAlpha, 212, 200, 67)
              : Color.fromARGB(glowAlpha, 180, 140, 80);
          borderWidth = 1.5;
        } else {
          borderColor = _gold.withAlpha(120);
        }

        // Box shadow: gain = warm glow, spend = subtle, reject = red glow
        List<BoxShadow>? boxShadows;
        if (reject < 1.0) {
          boxShadows = [BoxShadow(color: Color.fromARGB(((1.0 - reject) * 80).round(), 255, 40, 30), blurRadius: 10)];
        } else if (flash > 0 && isGain) {
          final glowStrength = isLargeGain ? 80 : 60;
          boxShadows = [BoxShadow(color: _gold.withAlpha((glowStrength * (1 - flash)).round()), blurRadius: isLargeGain ? 14 : 10)];
        }

        // Text color and size: gain = bright warm pop, spend = sharper dim, reject = red tint
        Color textColor;
        double fontSize;
        if (reject < 1.0) {
          textColor = Color.lerp(const Color(0xFFFF6644), _gold, reject)!;
          fontSize = 12.0;
        } else if (flash > 0) {
          textColor = isGain ? const Color(0xFFFFEEAA) : const Color(0xFFCCBB88);
          fontSize = isGain ? (isLargeGain ? 13.5 : 13.0) : 11.5;
        } else {
          textColor = _gold;
          fontSize = 12.0;
        }

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_bgDark.withAlpha(200), _bgDark.withAlpha(150)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: boxShadows,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: _gold.withAlpha(80), blurRadius: 4, spreadRadius: 1),
                        ],
                      ),
                      child: const Icon(Icons.monetization_on, color: _gold, size: 14),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.gold}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(color: Color(0x88D4A843), blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
              // Gold delta indicator: "+50" or "-90"
              if (flash < 1.0 && _goldDelta != 0)
                Positioned(
                  top: -12 - flash * 8,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: (1.0 - flash).clamp(0.0, 1.0),
                    child: Text(
                      _goldDelta > 0 ? '+$_goldDelta' : '$_goldDelta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _goldDelta > 0
                            ? const Color(0xFF44DD44)
                            : const Color(0xFFDD4444),
                        fontSize: isLargeGain ? 11 : 10,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4488CC).withAlpha(100), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.waves, color: Color(0xFF6699CC), size: 12),
          const SizedBox(width: 3),
          Text(
            'Dalga ${widget.currentWave}',
            style: const TextStyle(color: _cream, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1E1A), Color(0xFF0D150D)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF66AA66).withAlpha(100), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_view, color: Color(0xFF88CC88), size: 12),
          const SizedBox(width: 3),
          Text(
            '${widget.towersPlaced}/${widget.towerSlots}',
            style: const TextStyle(color: _cream, fontSize: 11, fontWeight: FontWeight.bold),
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromRGBO(180, 40, 40, 0.3 * opacity), Color.fromRGBO(120, 20, 20, 0.2 * opacity)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withAlpha((140 * opacity).round()), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pest_control, color: Colors.red.withAlpha((220 * opacity).round()), size: 12),
              const SizedBox(width: 3),
              Text(
                '${widget.enemiesAlive}/${widget.waveEnemyTotal}',
                style: TextStyle(color: Colors.red.withAlpha(230), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildObjectives() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _objDot(Icons.waves, widget.objWaves, '10 Dalga'),
        const SizedBox(width: 2),
        _objDot(Icons.groups, widget.objKills, '50 Kill'),
        const SizedBox(width: 2),
        _objDot(Icons.whatshot, widget.objBoss, '1 Boss'),
      ],
    );
  }

  Widget _buildBuildLabel() {
    final color = _buildLabelColor(widget.buildLabel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withAlpha(40), color.withAlpha(20)]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        widget.buildLabel,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _buildLabelColor(String label) {
    switch (label) {
      case 'Ateş Yapısı': return const Color(0xFFFF5511);
      case 'Kontrol Yapısı': return const Color(0xFF22CCEE);
      case 'Yıkım Yapısı': return const Color(0xFFFFDD00);
      case 'Zehir Yapısı': return const Color(0xFF33FF33);
      case 'Destek Yapısı': return const Color(0xFFFFDD66);
      default: return _gold;
    }
  }

  Widget _objDot(IconData icon, bool done, String label) {
    return Tooltip(
      message: '$label${done ? ' ✓' : ''}',
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? _gold.withAlpha(50) : _bgDark.withAlpha(120),
          border: Border.all(
            color: done ? _gold : _cream.withAlpha(40),
            width: 1,
          ),
        ),
        child: Icon(
          done ? Icons.check : icon,
          size: 10,
          color: done ? _gold : _cream.withAlpha(60),
        ),
      ),
    );
  }

  Widget _buildActiveBuffs() {
    // Count stacks per buff id
    final counts = <String, int>{};
    final buffMap = <String, WaveBuff>{};
    for (final buff in widget.activeBuffs) {
      counts[buff.id] = (counts[buff.id] ?? 0) + 1;
      buffMap[buff.id] = buff;
    }
    return AnimatedBuilder(
      animation: _buffPulseController,
      builder: (context, child) {
        final pulse = _buffPulseController.value;
        final glowAlpha = pulse < 1.0 ? ((1.0 - pulse) * 120).round() : 0;
        final scale = pulse < 0.3 ? 1.0 + pulse * 0.3 : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: glowAlpha > 0
                ? BoxDecoration(
                    boxShadow: [BoxShadow(color: Color.fromARGB(glowAlpha, 255, 215, 0), blurRadius: 12)],
                  )
                : null,
            child: child,
          ),
        );
      },
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in counts.entries)
          Tooltip(
            message: '${buffMap[entry.key]!.name}${entry.value > 1 ? ' x${entry.value}' : ''}\n${buffMap[entry.key]!.description}',
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _gold.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _gold.withAlpha(80)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      buffMap[entry.key]!.icon,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  if (entry.value > 1)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'x${entry.value}',
                          style: TextStyle(color: _bgDark, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
    );
  }

  Widget _buildSynergyBadge() {
    return Tooltip(
      message: widget.activeSynergies.join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_gold.withAlpha(50), _gold.withAlpha(30)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _gold.withAlpha(100)),
          boxShadow: [
            BoxShadow(color: _gold.withAlpha(20), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: _gold, size: 11),
            const SizedBox(width: 3),
            Text(
              '${widget.activeSynergies.length}',
              style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMutationBadge() {
    final names = widget.activeMutations.map((m) => '${m.displayName}: ${m.description}').join('\n');
    return Tooltip(
      message: names,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFF6644).withAlpha(50), const Color(0xFFFF6644).withAlpha(30)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF6644).withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science, color: Color(0xFFFF6644), size: 11),
            const SizedBox(width: 3),
            Text(
              '${widget.activeMutations.length}',
              style: const TextStyle(color: Color(0xFFFF6644), fontSize: 10, fontWeight: FontWeight.bold),
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: [Color(0x55D4A843), Color(0x33BA7517)])
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
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
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              'Oto',
              style: TextStyle(
                color: active ? _gold : _creamDim.withAlpha(140),
                fontSize: 9,
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          gradient: fast
              ? const LinearGradient(colors: [Color(0x55D4A843), Color(0x33BA7517)])
              : null,
          color: fast ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: fast ? _gold : _creamDim.withAlpha(60),
            width: fast ? 1.5 : 1,
          ),
        ),
        child: Text(
          '${widget.gameSpeed.toStringAsFixed(0)}x',
          style: TextStyle(
            color: fast ? _gold : _cream,
            fontSize: 10,
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
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _bgDark.withAlpha(180),
          shape: BoxShape.circle,
          border: Border.all(color: _creamDim.withAlpha(80)),
        ),
        child: const Icon(Icons.pause, color: _cream, size: 16),
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
          width: 90,
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
                  const Icon(Icons.favorite, color: Color(0xFFEE4444), size: 11),
                  const SizedBox(width: 3),
                  Text(
                    hasShield
                        ? '${widget.castleHp}/${widget.maxCastleHp} +${widget.secondaryShield}'
                        : '${widget.castleHp}/${widget.maxCastleHp}',
                    style: const TextStyle(color: _cream, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              CustomPaint(
                size: const Size(86, 8),
                painter: _HpBarPainter(ratio: ratio, isFull: ratio >= 1.0),
              ),
              if (hasShield) ...[
                const SizedBox(height: 1),
                CustomPaint(
                  size: const Size(86, 3),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (placedTower != null)
              Flexible(child: _buildTowerInfoPanel(placedTower))
            else
              Flexible(child: _buildTowerGrid()),
            const SizedBox(width: 6),
            if (!widget.isWaveActive)
              _buildStartWaveColumn()
            else
              _buildWaveActiveIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartWaveColumn() {
    final nextUnlock = TowerData.nextUnlock(widget.currentWave);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nextUnlock != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '${nextUnlock.name}: ${nextUnlock.wavesUntil} dalga',
              style: TextStyle(color: _gold.withAlpha(160), fontSize: 8),
            ),
          ),
        _buildStartWaveButton(),
      ],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Icon(Icons.shield, color: _bgDark, size: 16),
                SizedBox(width: 4),
                Text(
                  'Dalga',
                  style: TextStyle(
                    color: _bgDark,
                    fontSize: 12,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tColor.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: tColor.withAlpha(120)),
            ),
            child: Image.asset(
              'assets/images/towers/${tower.type.name}_t${tower.tier}.webp',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(_towerIcon(tower.type), color: tColor, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tierName,
                        style: TextStyle(
                          color: _cream,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: tColor.withAlpha(80), blurRadius: 4)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    for (int i = 0; i < 4; i++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < tower.tier ? tColor : _creamDim.withAlpha(40),
                          boxShadow: i < tower.tier
                              ? [BoxShadow(color: tColor.withAlpha(60), blurRadius: 2)]
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tower.type == TowerType.support
                      ? 'Buff: +${(15 * tower.tier)}% hasar komşu kulelere'
                      : 'Hasar: ${tower.currentDamage}  Menzil: ${tower.currentRange.toStringAsFixed(1)}  ${_towerAbility(tower.type)}',
                  style: TextStyle(color: _cream.withAlpha(180), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tower.needsT4Choice
                      ? 'Kills: ${tower.kills} | Yükselt: T4 branş seçimi!'
                      : 'Kills: ${tower.kills}  Toplam: ${tower.totalDamageDealt}',
                  style: TextStyle(
                    color: tower.needsT4Choice ? _gold.withAlpha(220) : _creamDim.withAlpha(160),
                    fontSize: 9,
                    fontWeight: tower.needsT4Choice ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (canTarget)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: _targetingTooltip(tower.targetingMode),
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
            ),
          if (widget.mergeCandidateCount > 0 && tower.canUpgrade)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6B3FA0), Color(0xFF4A2D73)]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withAlpha(160)),
                  boxShadow: [
                    BoxShadow(color: Colors.purple.withAlpha(40), blurRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.merge_type, size: 16, color: _cream),
                    Text(
                      '${widget.mergeCandidateCount}',
                      style: const TextStyle(fontSize: 9, color: _gold, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (tower.canUpgrade)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: widget.gold >= tower.upgradeCost ? widget.onUpgradeTower : null,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final canAfford = widget.gold >= tower.upgradeCost;
                    final pulse = canAfford ? _pulseController.value : 0.0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: canAfford
                            ? const LinearGradient(colors: [Color(0xFF2D7D2D), Color(0xFF1B5E1B)])
                            : null,
                        color: canAfford ? null : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: canAfford
                              ? Colors.green.withAlpha(160 + (40 * pulse).round())
                              : Colors.grey.withAlpha(60),
                          width: canAfford ? 1.5 : 1.0,
                        ),
                        boxShadow: canAfford
                            ? [BoxShadow(
                                color: Colors.green.withAlpha((35 + 25 * pulse).round()),
                                blurRadius: 6 + 4 * pulse,
                                spreadRadius: 1,
                              )]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_upward,
                            size: 16,
                            color: canAfford ? _cream : Colors.grey,
                          ),
                          Text(
                            '${tower.upgradeCost}g',
                            style: TextStyle(
                              fontSize: 9,
                              color: canAfford ? _gold : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 1),
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
            case SpellType.fireRain: spellAsset = 'assets/images/effects/fire_rain.webp'; color = const Color(0xFFFF5511); break;
            case SpellType.iceStorm: spellAsset = 'assets/images/effects/ice_storm.webp'; color = const Color(0xFF22CCEE); break;
            case SpellType.castleRepair: spellAsset = 'assets/images/effects/castle_repair.webp'; color = const Color(0xFF00CC44); break;
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
                      width: 32, height: 32,
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
                                width: 26,
                                height: 26,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome, color: ready ? color : _creamDim.withAlpha(80), size: 18),
                              ),
                            ),
                          ),
                          if (!ready)
                            SizedBox(
                              width: 32, height: 32,
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

  Widget _buildTowerChoiceOverlay() {
    final fireStats = TowerData.getStats(TowerType.fire);
    final spikeStats = TowerData.getStats(TowerType.spikeWall);
    return Container(
      color: const Color(0xBB000000),
      child: Center(
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          borderRadius: 12,
          borderColor: _gold,
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yeni Kule Seç',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: _gold.withAlpha(80), blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seçmediğin kule Dalga 4\'te açılır',
                  style: TextStyle(color: _cream.withAlpha(140), fontSize: 10),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildTowerChoiceCard(
                      TowerType.fire, fireStats.name, fireStats.roleHint,
                      const Color(0xFFFF5511), Icons.local_fire_department,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTowerChoiceCard(
                      TowerType.spikeWall, spikeStats.name, spikeStats.roleHint,
                      const Color(0xFF888888), Icons.fence,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTowerChoiceCard(TowerType type, String name, String role, Color color, IconData icon) {
    return GestureDetector(
      onTap: () => widget.onTowerChoice?.call(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(40), const Color(0xFF1A1510)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(name, style: TextStyle(color: _cream, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(role, style: TextStyle(color: _cream.withAlpha(160), fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
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

  Color _categoryColor(TowerCategory cat) {
    switch (cat) {
      case TowerCategory.damage: return const Color(0xFFFF5544);
      case TowerCategory.control: return const Color(0xFF22CCEE);
      case TowerCategory.defense: return const Color(0xFF88AA55);
      case TowerCategory.magic: return const Color(0xFFAA44DD);
    }
  }

  IconData _categoryIcon(TowerCategory cat) {
    switch (cat) {
      case TowerCategory.damage: return Icons.local_fire_department;
      case TowerCategory.control: return Icons.ac_unit;
      case TowerCategory.defense: return Icons.shield;
      case TowerCategory.magic: return Icons.auto_awesome;
    }
  }

  Widget _buildTowerGrid() {
    final allAvailable = widget.availableTowers;
    final categories = TowerData.availableCategories(widget.currentWave);

    // Auto-select first category if none selected or current one has no towers
    if (_selectedCategory == null || !categories.contains(_selectedCategory)) {
      _selectedCategory = categories.isNotEmpty ? categories.first : null;
    }

    final filteredTowers = _selectedCategory != null
        ? allAvailable.where((t) => TowerData.getCategory(t) == _selectedCategory).toList()
        : allAvailable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview panel when a tower is long-pressed
        if (_previewTower != null)
          _buildTowerPreview(_previewTower!),
        // Category tabs
        SizedBox(
          height: 22,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final cat in categories) ...[
                _buildCategoryTab(cat),
                const SizedBox(width: 3),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        // Tower cards in selected category
        SizedBox(
          height: 68,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < filteredTowers.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                _buildTowerCard(filteredTowers[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(TowerCategory cat) {
    final isActive = _selectedCategory == cat;
    final color = _categoryColor(cat);
    final count = widget.availableTowers.where((t) => TowerData.getCategory(t) == cat).length;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = cat;
        _previewTower = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(40) : const Color(0xFF14141C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? color.withAlpha(180) : Colors.grey[700]!.withAlpha(60),
            width: isActive ? 1.5 : 0.5,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withAlpha(30), blurRadius: 6)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_categoryIcon(cat), size: 10,
              color: isActive ? color : Colors.grey[500]),
            const SizedBox(width: 3),
            Text(
              cat.label,
              style: TextStyle(
                color: isActive ? color : Colors.grey[500],
                fontSize: 9,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                color: isActive ? color.withAlpha(160) : Colors.grey[600],
                fontSize: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTowerPreview(TowerType tower) {
    final stats = TowerData.getStats(tower);
    final tColor = _towerTypeColor(tower);
    final canAfford = widget.gold >= stats.cost;
    final hasSlot = widget.towersPlaced < widget.towerSlots;
    // Find synergies for this tower
    final synergies = SynergyData.all.where((s) =>
      s.requiredTowers.contains(tower)).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC0D0D15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tColor.withAlpha(120)),
              boxShadow: [BoxShadow(color: tColor.withAlpha(20), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(stats.name,
                      style: TextStyle(color: tColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${stats.cost}g',
                      style: TextStyle(
                        color: canAfford ? _gold : Colors.red[300],
                        fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _previewTower = null),
                      child: Icon(Icons.close, color: _cream.withAlpha(120), size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Stats row
                Row(
                  children: [
                    _buildStatChip(Icons.flash_on, '${stats.damage}', 'Hasar', const Color(0xFFFF8844)),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.radar, '${stats.range}', 'Menzil', const Color(0xFF44AAFF)),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.speed, '${stats.fireRate}s', 'Hız', const Color(0xFF44DD88)),
                    const Spacer(),
                    // Place button
                    GestureDetector(
                      onTap: (canAfford && hasSlot) ? () {
                        widget.onTowerSelected(tower);
                        setState(() => _previewTower = null);
                      } : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: (canAfford && hasSlot)
                              ? const LinearGradient(colors: [Color(0xFF2D7D2D), Color(0xFF1B5E1B)])
                              : null,
                          color: (canAfford && hasSlot) ? null : Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (canAfford && hasSlot) ? Colors.green.withAlpha(160) : Colors.grey.withAlpha(60),
                          ),
                        ),
                        child: Text('Yerlestir',
                          style: TextStyle(
                            color: (canAfford && hasSlot) ? _cream : Colors.grey[600],
                            fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Ability description
                Text(_towerAbility(tower),
                  style: TextStyle(color: _cream.withAlpha(200), fontSize: 9)),
                // Synergy hints
                if (synergies.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: _gold.withAlpha(180), size: 9),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          synergies.map((s) {
                            final others = s.requiredTowers
                                .where((t) => t != tower)
                                .toSet()
                                .map((t) => TowerData.getStats(t).name.split(' ').first)
                                .join('+');
                            return '${s.name}${others.isNotEmpty ? " ($others)" : ""}';
                          }).join('  '),
                          style: TextStyle(color: _gold.withAlpha(160), fontSize: 8),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: color.withAlpha(180)),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(color: _cream, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(color: _creamDim.withAlpha(140), fontSize: 7)),
      ],
    );
  }

  Widget _buildTowerCard(TowerType tower) {
    final stats = TowerData.getStats(tower);
    final isSelected = widget.selectedTower == tower;
    final isPreviewed = _previewTower == tower;
    final canAfford = widget.gold >= stats.cost;
    final hasSlot = widget.towersPlaced < widget.towerSlots;
    final tColor = _towerTypeColor(tower);

    return GestureDetector(
      onTap: () {
        if (canAfford && hasSlot) {
          if (_previewTower == tower) {
            // Second tap on previewed tower = select for placement
            widget.onTowerSelected(isSelected ? null : tower);
            setState(() => _previewTower = null);
          } else {
            // First tap = show preview
            setState(() => _previewTower = tower);
          }
        }
      },
      onLongPress: () {
        // Long press = direct select for placement (power users)
        if (canAfford && hasSlot) {
          widget.onTowerSelected(isSelected ? null : tower);
          setState(() => _previewTower = null);
        }
      },
      child: AnimatedScale(
        scale: isSelected ? 1.08 : (isPreviewed ? 1.04 : 1.0),
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 62,
          height: 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isSelected
                  ? [tColor.withAlpha(60), const Color(0xFF1A1510)]
                  : isPreviewed
                      ? [tColor.withAlpha(30), const Color(0xFF16161E)]
                      : canAfford
                          ? [const Color(0xFF1E1E28), const Color(0xFF14141C)]
                          : [const Color(0xFF1A1215), const Color(0xFF0E0A0C)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _gold
                  : isPreviewed ? tColor.withAlpha(140)
                  : (canAfford ? tColor.withAlpha(60) : Colors.grey[700]!.withAlpha(40)),
              width: isSelected ? 2.0 : (isPreviewed ? 1.5 : 1.0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(color: _gold.withAlpha(60), blurRadius: 10, spreadRadius: 2),
                    BoxShadow(color: tColor.withAlpha(30), blurRadius: 6),
                  ]
                : isPreviewed
                    ? [BoxShadow(color: tColor.withAlpha(40), blurRadius: 8)]
                    : null,
          ),
          child: Stack(
            children: [
              // Tower sprite
              Positioned(
                top: 2, left: 4, right: 4, bottom: 24,
                child: Image.asset(
                  'assets/images/towers/${tower.name}_t1.webp',
                  fit: BoxFit.contain,
                  opacity: AlwaysStoppedAnimation(canAfford ? 1.0 : 0.35),
                  errorBuilder: (_, __, ___) => Icon(
                    _towerIcon(tower),
                    color: canAfford ? tColor : Colors.grey[600],
                    size: 24,
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
              // Role hint + cost at bottom
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xEE0D0D15),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(9),
                      bottomRight: Radius.circular(9),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stats.name.split(' ').first,
                        style: TextStyle(
                          color: isSelected ? _gold : (canAfford ? _cream.withAlpha(200) : Colors.grey[600]),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${stats.cost}g',
                            style: TextStyle(
                              color: canAfford ? _gold.withAlpha(200) : Colors.grey[600],
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // "Selected" indicator
              if (isSelected)
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _gold.withAlpha(120), blurRadius: 4)],
                    ),
                  ),
                ),
            ],
          ),
        ),
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

  String _targetingTooltip(TargetingMode mode) {
    switch (mode) {
      case TargetingMode.nearest: return 'Kuleye en yakın düşmanı hedefle';
      case TargetingMode.first: return 'Kaleye en yakın düşmanı hedefle';
      case TargetingMode.strongest: return 'En yüksek HP düşmanı hedefle';
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
