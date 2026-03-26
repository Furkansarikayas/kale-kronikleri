import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'components/map/game_map.dart';
import 'components/map/grid_cell.dart';
import 'components/background/parallax_background.dart';
import 'components/atmosphere_overlay.dart';
import 'components/castle.dart';
import 'components/towers/tower.dart';
import 'components/towers/tower_factory.dart';
import 'components/towers/projectile.dart';
import 'components/enemies/enemy.dart';
import 'components/enemies/enemy_factory.dart';
import 'components/enemies/status_effect.dart';
import 'components/floating_text.dart';
import 'components/effects/hit_effect.dart';
import 'components/effects/screen_shake.dart';
import 'data/enemy_data.dart';
import 'data/game_config.dart';
import 'data/tower_data.dart';
import 'data/wave_data.dart';
import 'systems/economy_system.dart';
import 'systems/wave_system.dart';
import 'systems/synergy_system.dart';
import 'systems/mutation_system.dart';
import '../meta/artifact_system.dart';
import 'rendering/sprite_cache.dart';
import 'components/rendering/castle_sprites.dart';

enum GamePhase { prep, waveActive, waveBreak, paused, gameOver }

class KaleGame extends FlameGame {
  static const double fixedCellSize = 40.0;
  static final double _gameWidth = GameConfig.gridColumns * fixedCellSize;
  static final double _gameHeight = GameConfig.gridRows * fixedCellSize;

  late GameMap gameMap;
  late Castle castle;
  late EconomySystem economy;
  late WaveSystem waveSystem;
  late SynergySystem synergySystem;
  late double cellSize;

  final int mapSeed;
  final DifficultyTier difficulty;
  final List<ArtifactDef> artifacts;
  final Map<String, int> metaLevels;
  final List<MutationType> mutations;
  final bool initialScreenShakeEnabled;

  bool _isReady = false;
  bool get isReady => _isReady;

  GamePhase _phase = GamePhase.prep;
  GamePhase get phase => _phase;

  // Tower management
  final List<Tower> _towers = [];
  final Map<({int col, int row}), TowerType> _towerPositions = {};
  TowerType? selectedTowerType;
  Tower? _selectedPlacedTower;
  Tower? get selectedPlacedTower => _selectedPlacedTower;
  int _towerSlots = GameConfig.baseTowerSlots;
  int get towerSlots => _towerSlots;
  int get towersPlaced => _towers.length;
  List<Tower> get towers => List.unmodifiable(_towers);

  // Enemy management
  final List<Enemy> _enemies = [];
  int _enemiesKilled = 0;
  int get enemiesKilled => _enemiesKilled;
  int get enemiesAlive => _enemies.where((e) => !e.isDead && !e.reachedCastle).length;

  // Wave spawning
  List<WaveEntry> _pendingSpawns = [];
  double _spawnTimer = 0;
  int _spawnIndex = 0;
  double _currentSpawnDelay = 0.8;
  int _waveEnemyTotal = 0;
  int get waveEnemyTotal => _waveEnemyTotal;

  // Wave break
  double _breakTimer = 0;
  double get breakTimeRemaining => _breakTimer;

  // Artifact state
  bool _totemUsed = false;
  double _healerTickTimer = 0;
  double _chaosStoneTimer = 0; // Artifact #7: random synergy trigger

  // Synergy effect timers
  double _kiyametTimer = 0;
  bool _buzulCagiActive = false;
  bool _ultimateSynergyActive = false;
  double _ultimateSynergyTimer = 0;

  // Castle AoE meta
  double _castleAoeTimer = 0;

  // Son Nefes invincibility
  double _invincibilityTimer = 0;
  bool _sonNefesUsed = false;

  // Screen shake
  late ScreenShake screenShake;

  // Kill streak
  int _killStreak = 0;
  double _killStreakTimer = 0;
  static const double _killStreakWindow = 1.5; // seconds to chain kills

  // Meta: Çift Sur (Kale 4) - secondary HP shield
  int _secondaryShield = 0;
  int _maxSecondaryShield = 0;

  // Track total damage dealt for stats
  int _totalDamageDealt = 0;
  int get totalDamageDealt => _totalDamageDealt;
  int _goldStolen = 0;
  int get goldStolen => _goldStolen;

  // Auto-wave toggle
  bool _autoWave = false;
  bool get autoWave => _autoWave;
  void toggleAutoWave() {
    _autoWave = !_autoWave;
    onStateChanged?.call();
  }

  // Speed control
  double _gameSpeed = 1.0;
  double get gameSpeed => _gameSpeed;
  void toggleSpeed() {
    final maxSpeed = _metaSpeedOptions ? 3.0 : 2.0;
    if (_gameSpeed >= maxSpeed) {
      _gameSpeed = 1.0;
    } else {
      _gameSpeed += 1.0;
    }
    onStateChanged?.call();
  }

  // Callbacks for Flutter overlays
  VoidCallback? onStateChanged;
  void Function(bool isVictory)? onGameOver;

  bool hasArtifact(int id) => artifacts.any((a) => a.id == id);

  KaleGame({
    required this.mapSeed,
    this.difficulty = DifficultyTier.apprentice,
    this.artifacts = const [],
    this.metaLevels = const {},
    this.mutations = const [],
    this.initialScreenShakeEnabled = true,
  }) : super(
    camera: CameraComponent.withFixedResolution(
      width: _gameWidth,
      height: _gameHeight,
    ),
  );

  @override
  Color backgroundColor() => const Color(0xFF080C14);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize sprite caches before creating any game components
    await SpriteCache.instance.initialize(biome: difficulty.biome);
    await CastleSpriteGenerator.instance.initialize();

    // Fixed resolution: world is exactly _gameWidth x _gameHeight
    camera.viewfinder.anchor = Anchor.topLeft;
    cellSize = fixedCellSize;

    // Screen shake effect
    screenShake = ScreenShake()..enabled = initialScreenShakeEnabled;
    add(screenShake);

    // Multiple spawn paths based on difficulty
    final spawnCount = difficulty == DifficultyTier.apprentice ? 1
        : difficulty == DifficultyTier.knight ? 1
        : 2; // lord+ get 2 spawn points
    gameMap = GameMap(cellSize: cellSize);
    gameMap.generate(seed: mapSeed, spawnCount: spawnCount);
    world.add(ParallaxBackground(biome: difficulty.biome));
    world.add(gameMap);
    world.add(AtmosphereOverlay());

    castle = Castle(cellSize: cellSize);
    world.add(castle);

    // Tap handler in the world (receives world coordinates automatically)
    world.add(_GridTapHandler(this));

    economy = EconomySystem();
    economy.difficultyMultiplier = difficulty.spiritMultiplier;
    waveSystem = WaveSystem(difficulty: difficulty);
    synergySystem = SynergySystem();

    // Apply mutation effects to wave prep time
    _mutationWavePrepMult = MutationSystem.wavePrepMultiplier(mutations);
    _mutationGoldMult = MutationSystem.goldRewardMultiplier(mutations);
    _mutationTowerCostMult = MutationSystem.towerCostMultiplier(mutations);

    // Apply meta tree bonuses
    _applyMetaBonuses();

    _phase = GamePhase.prep;
    _isReady = true;
    onStateChanged?.call(); // notify Flutter to show HUD
  }

  void _applyMetaBonuses() {
    final savas = metaLevels['savas'] ?? 0;
    final kesif = metaLevels['kesif'] ?? 0;
    final kale = metaLevels['kale'] ?? 0;
    final efsane = metaLevels['efsane'] ?? 0;

    // Savaş tree
    if (savas >= 1) _towerSlots += 1; // Kule Hafızası: +1 slot
    if (savas >= 2) castle.heal((castle.maxHp * 0.25).round()); // Demir İrade: +25% HP
    if (savas >= 3) _metaUpgradeCostReduction = 0.20; // Usta Komutan: 20% cheaper upgrades
    if (savas >= 4) _metaEarlyWaveDamageBonus = 0.30; // Savaş Çığlığı: +30% damage first 3 waves
    if (savas >= 5) castle.heal(castle.maxHp); // Kale Muhafızı: double wall HP (full heal ≈ 2x effective)
    if (savas >= 7) _metaPhysicalDamageBonus = 0.15; // Çelik Yumruk: +15% physical damage

    // Keşif tree
    if (kesif >= 1) _metaAllTowersUnlocked = true; // Şifre Çözücü: all towers from wave 1
    if (kesif >= 2) _metaSynergyHints = true; // Sinerji Arşivi: show synergy hints
    if (kesif >= 3) _metaEnemyWeakness = true; // Düşman Kütüphanesi: show enemy weaknesses
    if (kesif >= 4) _metaBonusGoldRoom = 0.15; // Hazine Avcısı: 15% bonus gold chance
    if (kesif >= 5) _metaImprovedArtifacts = true; // Bilge Göz: better artifact rolls
    if (kesif >= 6) _metaPreviewWaves = 2; // Harita Okuyucu: preview next 2 waves
    if (kesif >= 7) _metaAncientArtifactChance = 0.10; // Arkeolog: 10% ancient artifact find

    // Kale tree
    if (kale >= 1) _metaDamageReduction = 0.30; // Taş Duvarlar: 30% damage reduction
    if (kale >= 2) _metaWaveGoldBonus = 8; // Hazine Odaları: +8 gold/wave
    if (kale >= 3) _metaHealPerWave = 0.15; // Onarım Loncası: 15% heal between waves
    if (kale >= 4) { // Çift Sur: secondary damage shield
      _maxSecondaryShield = 20 + (castle.maxHp * 0.2).round();
      _secondaryShield = _maxSecondaryShield;
    }
    if (kale >= 5) _metaBossGoldMultiplier = 2.0; // Vergi Toplayıcı: 2x boss gold
    if (kale >= 6) _metaCastleSpiritBonus = true; // Kale Ruhu: towers gain power when castle damaged

    // Efsane tree
    if (efsane >= 1) _metaDragonSpirit = true; // Ejderha Ruhu: periodic dragon fire
    if (efsane >= 2) _metaSpeedOptions = true; // Zaman Büküm: 3x speed option
    if (efsane >= 3) _metaCurseSynergyBonus = 0.25; // Karanlık Antlaşma: +25% curse synergy
    if (efsane >= 4) _metaHolySynergyBonus = 0.25; // Işık Şampiyonu: +25% holy synergy
    if (efsane >= 5) _metaExtraArtifactChoice = true; // Kader Yazıcı: +1 artifact choice
    if (efsane >= 6) _metaUltimateSynergy = true; // Tanrıların Gazabı: ultimate synergy
    if (efsane >= 7) _metaInfiniteMode = true; // Ebedi Kale: infinite mode
  }

  bool get _metaSonNefes => (metaLevels['savas'] ?? 0) >= 6;

  int _metaWaveGoldBonus = 0;
  double _metaHealPerWave = 0;
  double _metaUpgradeCostReduction = 0;
  double _metaEarlyWaveDamageBonus = 0;
  double _metaPhysicalDamageBonus = 0;
  bool _metaAllTowersUnlocked = false;
  double _metaBonusGoldRoom = 0;
  double _metaDamageReduction = 0;
  double _metaBossGoldMultiplier = 1.0;
  bool _metaCastleSpiritBonus = false; // Kale Ruhu: +10% tower damage when castle < 50% HP
  bool _metaSynergyHints = false;
  bool _metaEnemyWeakness = false;
  bool _metaImprovedArtifacts = false;
  int _metaPreviewWaves = 1;
  double _metaAncientArtifactChance = 0;
  bool _metaDragonSpirit = false;
  bool _metaSpeedOptions = false;
  double _metaCurseSynergyBonus = 0;
  double _metaHolySynergyBonus = 0;
  bool _metaExtraArtifactChoice = false;
  bool _metaUltimateSynergy = false;
  bool _metaInfiniteMode = false;
  double _dragonSpiritTimer = 0;
  double _mutationWavePrepMult = 1.0;
  double _mutationGoldMult = 1.0;
  double _mutationTowerCostMult = 1.0;

  // --- Artifact Helpers ---

  double get _artifactFireRateMultiplier {
    // id 1: Ateş Kalbi - Fire towers 25% faster
    return hasArtifact(1) ? 0.75 : 1.0;
  }

  double get _artifactSlowDurationMultiplier {
    // id 2: Buz Kristali - Slow duration 2x
    return hasArtifact(2) ? 2.0 : 1.0;
  }

  double get _artifactArrowRangeBonus {
    // id 3: Rüzgar Tılsımı - Arrow range +40%
    return hasArtifact(3) ? 0.4 : 0.0;
  }

  int get _artifactWaveGoldBonus {
    // id 4: Altın Taç - +15 gold per wave
    return hasArtifact(4) ? 15 : 0;
  }

  double get _artifactBossDamageMultiplier {
    // id 6: Ejderha Pulu - Boss damage +35%
    return hasArtifact(6) ? 1.35 : 1.0;
  }

  double get _artifactLightningDamageMultiplier {
    // id 9: Tanrı Çekici - Lightning damage 3x
    return hasArtifact(9) ? 3.0 : 1.0;
  }

  double get _artifactSynergyMultiplier {
    // id 10: Kader Aynası - All synergies 50% stronger
    return hasArtifact(10) ? 1.5 : 1.0;
  }

  // --- Tower Placement ---

  bool canPlaceTowerAt(int col, int row) {
    if (_towers.length >= _towerSlots) return false;
    if (_towerPositions.containsKey((col: col, row: row))) return false;
    if (selectedTowerType == null) return false;

    final isSpikeWall = selectedTowerType == TowerType.spikeWall;
    return gameMap.canPlaceTower(col, row, isSpikeWall: isSpikeWall);
  }

  bool placeTower(int col, int row, TowerType type) {
    final stats = TowerData.getStats(type);
    if (_towers.length >= _towerSlots) return false;
    if (_towerPositions.containsKey((col: col, row: row))) return false;

    final isSpikeWall = type == TowerType.spikeWall;
    if (!gameMap.canPlaceTower(col, row, isSpikeWall: isSpikeWall)) return false;
    final adjustedCost = (stats.cost * _mutationTowerCostMult).round();
    if (!economy.trySpend(adjustedCost)) return false; // deduct AFTER validation

    final tower = TowerFactory.create(
      type: type, col: col, row: row, cellSize: cellSize,
    );
    // Apply artifact bonuses
    if (type == TowerType.arrow && _artifactArrowRangeBonus > 0) {
      tower.artifactRangeMultiplier = 1.0 + _artifactArrowRangeBonus;
    }
    if (type == TowerType.fire && _artifactFireRateMultiplier < 1.0) {
      tower.artifactFireRateMultiplier = _artifactFireRateMultiplier;
    }
    if (type == TowerType.lightning && _artifactLightningDamageMultiplier > 1.0) {
      tower.artifactDamageMultiplier = _artifactLightningDamageMultiplier;
    }
    _towers.add(tower);
    _towerPositions[(col: col, row: row)] = type;
    world.add(tower);

    _recalculateSynergies();
    onStateChanged?.call();
    return true;
  }

  int sellTower(Tower tower) {
    final refund = tower.sellValue;
    economy.earnGold(refund);
    _towers.remove(tower);
    _towerPositions.remove((col: tower.col, row: tower.row));
    tower.removeFromParent();

    _recalculateSynergies();
    onStateChanged?.call();
    return refund;
  }

  bool upgradeTower(Tower tower) {
    if (!tower.canUpgrade) return false;
    final cost = (_metaUpgradeCostReduction > 0)
        ? (tower.upgradeCost * (1.0 - _metaUpgradeCostReduction)).round()
        : tower.upgradeCost;
    if (!economy.trySpend(cost)) return false;
    tower.upgrade();
    onStateChanged?.call();
    return true;
  }

  void _recalculateSynergies() {
    // Clear all tower synergy bonuses first
    for (final tower in _towers) {
      tower.clearSynergyBonus();
      tower.supportDamageMultiplier = 1.0;
      tower.supportRangeMultiplier = 1.0;
    }

    // Apply support tower buff aura to adjacent towers
    _applyingSupportBuffs();

    final active = synergySystem.recalculate(_towerPositions);

    // Apply synergy bonuses to involved towers
    for (final synergy in active) {
      var synergyMult = _artifactSynergyMultiplier; // Kader Aynası artifact
      // Efsane: Karanlık Antlaşma - curse synergies stronger
      if (_metaCurseSynergyBonus > 0 && synergy.definition.requiredTowers.contains(TowerType.dark)) {
        synergyMult *= (1.0 + _metaCurseSynergyBonus);
      }
      // Efsane: Işık Şampiyonu - holy synergies stronger
      if (_metaHolySynergyBonus > 0 && synergy.definition.requiredTowers.contains(TowerType.holy)) {
        synergyMult *= (1.0 + _metaHolySynergyBonus);
      }
      final anchor = synergy.anchorPosition;

      // Find towers at and adjacent to the anchor that are part of this synergy
      for (final tower in _towers) {
        final dc = (tower.col - anchor.col).abs();
        final dr = (tower.row - anchor.row).abs();
        if (dc > 1 || dr > 1) continue; // not adjacent

        // Check if this tower type is part of the synergy
        if (!synergy.definition.requiredTowers.contains(tower.type)) continue;

        // Apply bonuses based on synergy type
        switch (synergy.id) {
          case 1: // Dondur-Patlat: 2x damage
            tower.applySynergyBonus(damageMultiplier: 1.0 + 1.0 * synergyMult);
            break;
          case 2: // Buhar Hasarı: +1 range, faster fire
            tower.applySynergyBonus(rangeBonus: 1.0 * synergyMult, fireRateMultiplier: 0.8);
            break;
          case 3: // Şok Dalgası: 2x damage
            tower.applySynergyBonus(damageMultiplier: 1.0 + 1.0 * synergyMult);
            break;
          case 4: // Asit Tuzağı: +1.5 range
            tower.applySynergyBonus(rangeBonus: 1.5 * synergyMult);
            break;
          case 5: // Yanık Asit: 1.5x damage
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.5 * synergyMult);
            break;
          case 6: // Denge Patlaması: 2x damage
            tower.applySynergyBonus(damageMultiplier: 1.0 + 1.0 * synergyMult);
            break;
          case 7: // Buz Hapsi: slower fire but more range
            tower.applySynergyBonus(rangeBonus: 1.0 * synergyMult, fireRateMultiplier: 0.7);
            break;
          case 8: // Cehennem Hattı: 1.8x damage
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.8 * synergyMult);
            break;
          case 9: // Buzul Çağı: +2 range
            tower.applySynergyBonus(rangeBonus: 2.0 * synergyMult);
            break;
          case 10: // Kıyamet: 2.5x damage
            tower.applySynergyBonus(damageMultiplier: 1.0 + 1.5 * synergyMult);
            break;
          case 11: // Tanrıların Gazabı: 3x damage (ultimate, requires meta unlock)
            if (_metaUltimateSynergy) {
              tower.applySynergyBonus(damageMultiplier: 1.0 + 2.0 * synergyMult, rangeBonus: 1.5);
            }
            break;
        }
      }
    }

    // Track synergy effects
    _buzulCagiActive = active.any((s) => s.id == 9);
    _ultimateSynergyActive = _metaUltimateSynergy && active.any((s) => s.id == 11);

    // Track synergy discovery
    if (active.isNotEmpty) {
      onSynergyDiscovered?.call();
    }
  }

  void _applyingSupportBuffs() {
    for (final support in _towers) {
      if (support.type != TowerType.support) continue;
      // Support tower buffs adjacent (8-directional) towers
      // +15% damage per support tier, +5% range per tier
      final dmgBonus = 1.0 + 0.15 * support.tier;
      final rangeBonus = 1.0 + 0.05 * support.tier;

      for (final other in _towers) {
        if (other == support) continue;
        final dc = (other.col - support.col).abs();
        final dr = (other.row - support.row).abs();
        if (dc <= 1 && dr <= 1) {
          // Stack multiplicatively with existing support buffs
          other.supportDamageMultiplier *= dmgBonus;
          other.supportRangeMultiplier *= rangeBonus;
        }
      }
    }
  }

  // --- Wave Control ---

  void startNextWave() {
    if (_phase != GamePhase.prep && _phase != GamePhase.waveBreak) return;
    if (waveSystem.isComplete) return;

    waveSystem.startNextWave();
    _pendingSpawns = List.from(waveSystem.currentComposition);
    _spawnIndex = 0;
    _spawnTimer = 0;
    _currentSpawnDelay = _pendingSpawns.isNotEmpty ? _pendingSpawns[0].spawnDelay : 0.8;
    _waveEnemyTotal = _pendingSpawns.fold(0, (sum, e) => sum + e.count);
    _phase = GamePhase.waveActive;
    onStateChanged?.call();
  }

  void _spawnEnemy(EnemyType type) {
    if (gameMap.enemyPaths.isEmpty) return; // safety
    // Pick a random path from available paths
    final paths = gameMap.enemyPaths;
    final path = paths[math.Random().nextInt(paths.length)];
    final enemy = EnemyFactory.create(
      type: type,
      path: path,
      cellSize: cellSize,
      difficulty: difficulty,
    );
    // Mutation: fast enemies
    if (mutations.contains(MutationType.fastEnemies)) {
      enemy.applyEffect(StatusEffect.slow(factor: -0.3, duration: 999999.0)); // negative = speed boost
    }
    // Mutation: armored all
    final bonusArmor = MutationSystem.bonusArmor(mutations);
    if (bonusArmor > 0) {
      enemy.addBonusArmor(bonusArmor);
    }
    // Artifact: Gölge Pelerin (id 5) - First wave enemies 50% slow
    if (hasArtifact(5) && waveSystem.currentWave == 1) {
      enemy.applyEffect(StatusEffect.slow(factor: 0.5, duration: 999.0));
    }
    _enemies.add(enemy);
    world.add(enemy);
  }

  // --- Game Loop ---

  @override
  void update(double dt) {
    super.update(dt);

    if (!_isReady) return;
    if (_phase == GamePhase.paused || _phase == GamePhase.gameOver) return;

    dt *= _gameSpeed;

    if (_phase == GamePhase.waveBreak) {
      final oldSec = _breakTimer.ceil();
      _breakTimer -= dt;
      if (_breakTimer <= 0) {
        startNextWave();
      } else if (_breakTimer.ceil() != oldSec) {
        onStateChanged?.call();
      }
      return;
    }

    if (_phase != GamePhase.waveActive) return;

    // Spawn enemies
    _updateSpawning(dt);

    // Tower targeting & firing
    _updateTowerCombat(dt);

    // Healer enemy mechanic
    _updateHealerEnemies(dt);

    // Troll regeneration: heals 3 HP/sec
    for (final enemy in _enemies) {
      if (enemy.isDead || enemy.reachedCastle) continue;
      if (enemy.type == EnemyType.troll && enemy.hp < enemy.maxHp) {
        enemy.heal((3 * dt).ceil());
      }
    }

    // DarkKnight aura: nearby allies get +5 armor (applied as bonus armor if not already)
    _updateDarkKnightAura();

    // Cavalry dash: cavalry periodically bursts forward
    _updateCavalryDash(dt);

    // Artifact: Ebedi Alev - all enemies take constant burn
    if (hasArtifact(11)) {
      for (final enemy in _enemies) {
        if (enemy.isDead || enemy.reachedCastle) continue;
        if (!enemy.activeEffects.any((e) => e.type == StatusType.burn)) {
          enemy.applyEffect(StatusEffect.burn(dps: 2, duration: 2.0));
        }
      }
    }

    // Synergy effects
    _updateSynergyEffects(dt);

    // Artifact #7: Kaos Taşı - random synergy effect every 20s
    _updateChaosStone(dt);

    // Meta: Kale Ruhu - towers gain 10% damage when castle below 50% HP
    _updateKaleRuhu();

    // Efsane: Ejderha Ruhu - periodic dragon fire
    _updateDragonSpirit(dt);

    // Castle AoE meta (Antik Büyü)
    _updateCastleAoe(dt);

    // Process enemies (remove dead/reached)
    _processEnemies();

    // Check wave complete
    if (_pendingSpawns.isEmpty && _enemies.isEmpty) {
      _onWaveComplete();
    }

    // Son Nefes invincibility countdown
    if (_invincibilityTimer > 0) {
      _invincibilityTimer -= dt;
    }

    // Kill streak timer
    if (_killStreakTimer > 0) {
      _killStreakTimer -= dt;
      if (_killStreakTimer <= 0) {
        _killStreak = 0;
      }
    }

    // Screen shake
    camera.viewfinder.position = screenShake.offset;

    // Check game over - Artifact: Ölümsüz Totem (id 8) revive once
    if (castle.isDestroyed) {
      if (_invincibilityTimer > 0) {
        castle.heal(1); // keep alive during invincibility
      } else if (_metaSonNefes && !_sonNefesUsed) {
        // Son Nefes: 5 seconds invincibility when HP reaches 0
        _sonNefesUsed = true;
        _invincibilityTimer = 5.0;
        castle.heal(1);
      } else if (hasArtifact(8) && !_totemUsed) {
        _totemUsed = true;
        castle.heal(castle.maxHp ~/ 2);
      } else {
        _phase = GamePhase.gameOver;
        onGameOver?.call(false);
      }
    }
  }

  void _updateSpawning(double dt) {
    if (_pendingSpawns.isEmpty) return;

    _spawnTimer += dt;
    while (_spawnTimer >= _currentSpawnDelay && _pendingSpawns.isNotEmpty) {
      final entry = _pendingSpawns.first;
      if (_spawnIndex < entry.count) {
        _spawnEnemy(entry.type);
        _spawnIndex++;
        _spawnTimer -= _currentSpawnDelay;
      }
      if (_spawnIndex >= entry.count) {
        _pendingSpawns.removeAt(0);
        _spawnIndex = 0;
        if (_pendingSpawns.isNotEmpty) {
          _currentSpawnDelay = _pendingSpawns.first.spawnDelay;
        }
      }
    }
  }

  void _updateTowerCombat(double dt) {
    for (final tower in _towers) {
      // Spike walls deal contact damage to enemies on same cell
      if (tower.type == TowerType.spikeWall) {
        _updateSpikeWallDamage(tower, dt);
        continue;
      }

      if (!tower.canFire()) continue;

      // Find target based on tower's targeting mode
      Enemy? target;
      double bestScore = double.infinity;
      for (final enemy in _enemies) {
        if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
        if (!tower.isInRange(enemy.position)) continue;
        double score;
        switch (tower.targetingMode) {
          case TargetingMode.nearest:
            score = (tower.position + tower.size / 2).distanceTo(enemy.position);
            break;
          case TargetingMode.first:
            // Lowest remaining path = closest to castle
            score = enemy.remainingPath.length.toDouble();
            break;
          case TargetingMode.strongest:
            // Negative HP so highest HP gets lowest score
            score = -enemy.hp.toDouble();
            break;
        }
        if (score < bestScore) {
          bestScore = score;
          target = enemy;
        }
      }

      if (target != null) {
        final proj = tower.tryFire(target.position);
        if (proj != null) {
          world.add(proj);
          // Instant hit for simplicity (projectile visual only)
          _applyTowerDamage(tower, target);

          // Cannon AoE splash: 50% damage to enemies within 1.5 cells
          if (tower.type == TowerType.cannon) {
            _applyCannonSplash(tower, target);
          }

          // Wizard chain: hit 2 additional targets at 50% damage
          if (tower.type == TowerType.wizard) {
            _applyWizardChain(tower, target);
          }
        }
      }
    }

    // Clean up projectiles that have hit
    final projectiles = world.children.whereType<Projectile>().toList();
    for (final p in projectiles) {
      if (p.hasHit) p.removeFromParent();
    }
  }

  // Spike wall contact damage tracking
  final Map<Tower, double> _spikeWallTimers = {};

  void _updateSpikeWallDamage(Tower spikeWall, double dt) {
    final timer = (_spikeWallTimers[spikeWall] ?? 0) + dt;
    if (timer < 0.5) {
      _spikeWallTimers[spikeWall] = timer;
      return;
    }
    _spikeWallTimers[spikeWall] = 0;

    final center = spikeWall.position + spikeWall.size / 2;
    for (final enemy in _enemies) {
      if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
      final dist = center.distanceTo(enemy.position);
      if (dist <= cellSize * 0.8) {
        enemy.takeDamage(spikeWall.currentDamage);
      }
    }
  }

  void _applyCannonSplash(Tower cannon, Enemy primaryTarget) {
    final splashRadius = cellSize * 1.5;
    final splashDamage = (cannon.currentDamage * 0.5).round();
    // Show explosion effect at impact point
    world.add(HitEffect.explosion(pos: primaryTarget.position, radius: splashRadius));
    for (final enemy in _enemies) {
      if (enemy == primaryTarget || enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
      final dist = primaryTarget.position.distanceTo(enemy.position);
      if (dist <= splashRadius) {
        enemy.takeDamage(splashDamage);
      }
    }
  }

  // DarkKnight aura: gives adjacent enemies armor
  final Set<Enemy> _darkKnightBuffed = {};

  void _updateDarkKnightAura() {
    for (final dk in _enemies) {
      if (dk.isDead || dk.reachedCastle) continue;
      if (dk.type != EnemyType.darkKnight) continue;

      for (final other in _enemies) {
        if (other == dk || other.isDead || other.reachedCastle) continue;
        if (_darkKnightBuffed.contains(other)) continue;
        final dist = dk.position.distanceTo(other.position);
        if (dist <= cellSize * 2.0) {
          other.addBonusArmor(5);
          _darkKnightBuffed.add(other);
        }
      }
    }
  }

  // Cavalry dash: short burst of speed periodically
  final Map<Enemy, double> _cavalryDashTimers = {};

  void _updateCavalryDash(double dt) {
    for (final enemy in _enemies) {
      if (enemy.isDead || enemy.reachedCastle) continue;
      if (enemy.type != EnemyType.cavalry) continue;

      final timer = (_cavalryDashTimers[enemy] ?? 0) + dt;
      if (timer >= 4.0) {
        // Dash: apply speed boost for 1 second
        if (!enemy.activeEffects.any((e) => e.type == StatusType.slow && e.slowFactor < 0)) {
          enemy.applyEffect(StatusEffect.slow(factor: -0.8, duration: 1.0)); // negative = speed boost
        }
        _cavalryDashTimers[enemy] = 0;
      } else {
        _cavalryDashTimers[enemy] = timer;
      }
    }
  }

  void _updateSynergyEffects(double dt) {
    // Buzul Çağı (id 9): 30% global slow when active
    if (_buzulCagiActive) {
      for (final enemy in _enemies) {
        if (enemy.isDead || enemy.reachedCastle) continue;
        if (!enemy.activeEffects.any((e) => e.type == StatusType.slow)) {
          enemy.applyEffect(StatusEffect.slow(factor: 0.3, duration: 2.0));
        }
      }
    }

    // Kıyamet (id 10): massive AoE every 15 seconds
    final kiyametActive = synergySystem.activeSynergies.any((s) => s.id == 10);
    if (kiyametActive) {
      _kiyametTimer += dt;
      if (_kiyametTimer >= 15.0) {
        _kiyametTimer = 0;
        // Deal damage to ALL enemies on the map
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
          final dmg = 25 + waveSystem.currentWave * 3;
          enemy.takeDamage(dmg, bypassArmor: true);
          _showDamageText(enemy.position, dmg);
          world.add(HitEffect.explosion(pos: enemy.position, radius: 20));
        }
      }
    }

    // Tanrıların Gazabı (id 11): continuous AoE every 8 seconds + burn all
    if (_ultimateSynergyActive) {
      _ultimateSynergyTimer += dt;
      if (_ultimateSynergyTimer >= 8.0) {
        _ultimateSynergyTimer = 0;
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
          final dmg = 40 + waveSystem.currentWave * 5;
          enemy.takeDamage(dmg, bypassArmor: true);
          enemy.applyEffect(StatusEffect.burn(duration: 3.0, dps: 8 + waveSystem.currentWave));
          enemy.applyEffect(StatusEffect.curse(duration: 4.0, armorReduce: 10));
          _showDamageText(enemy.position, dmg);
          world.add(HitEffect.explosion(pos: enemy.position, radius: 25));
        }
      }
    }
  }

  void _updateCastleAoe(double dt) {
    final kale = metaLevels['kale'] ?? 0;
    if (kale < 7) return; // Antik Büyü: level 7 needed

    _castleAoeTimer += dt;
    if (_castleAoeTimer < 1.0) return;
    _castleAoeTimer = 0;

    final castleCenter = castle.position + castle.size / 2;
    final range = cellSize * 3.0;
    for (final enemy in _enemies) {
      if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
      final dist = castleCenter.distanceTo(enemy.position);
      if (dist <= range) {
        enemy.takeDamage(5 + waveSystem.currentWave, bypassArmor: true);
      }
    }
  }

  void _updateChaosStone(double dt) {
    if (!hasArtifact(7)) return;
    _chaosStoneTimer += dt;
    if (_chaosStoneTimer < 20.0) return;
    _chaosStoneTimer = 0;

    if (_enemies.isEmpty) return;

    // Pick a random synergy effect to apply
    final rng = math.Random();
    final effect = rng.nextInt(4);
    switch (effect) {
      case 0: // Freeze all enemies briefly
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle) continue;
          enemy.applyEffect(StatusEffect.slow(factor: 0.1, duration: 2.0));
        }
        break;
      case 1: // Burn all enemies
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle) continue;
          enemy.applyEffect(StatusEffect.burn(dps: 5, duration: 3.0));
        }
        break;
      case 2: // AoE damage burst
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
          final dmg = 15 + waveSystem.currentWave * 2;
          enemy.takeDamage(dmg, bypassArmor: true);
          world.add(HitEffect.explosion(pos: enemy.position, radius: 12));
        }
        break;
      case 3: // Curse all enemies (armor reduction)
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle) continue;
          enemy.applyEffect(StatusEffect.curse(armorReduce: 10, duration: 4.0));
        }
        break;
    }
  }

  void _updateKaleRuhu() {
    if (!_metaCastleSpiritBonus) return;
    final hpRatio = castle.maxHp > 0 ? castle.hp / castle.maxHp : 1.0;
    final bonus = hpRatio < 0.5 ? 1.10 : 1.0; // +10% when below 50%
    for (final tower in _towers) {
      tower.kaleRuhuMultiplier = bonus;
    }
  }

  void _updateDragonSpirit(double dt) {
    if (!_metaDragonSpirit) return;
    _dragonSpiritTimer += dt;
    if (_dragonSpiritTimer < 12.0) return; // Fire every 12 seconds
    _dragonSpiritTimer = 0;

    if (_enemies.isEmpty) return;

    // Dragon breath: line of fire from castle, damages all enemies in a wide area
    final castleCenter = castle.position + castle.size / 2;
    for (final enemy in _enemies) {
      if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
      final dist = castleCenter.distanceTo(enemy.position);
      if (dist <= cellSize * 8) { // 8 cell range
        final dmg = 10 + waveSystem.currentWave * 2;
        enemy.takeDamage(dmg, bypassArmor: true);
        enemy.applyEffect(StatusEffect.burn(dps: 5, duration: 3.0));
        world.add(HitEffect.fire(pos: enemy.position));
      }
    }
  }

  void _applyWizardChain(Tower wizard, Enemy primaryTarget) {
    // Chain to up to 2 additional enemies within 2 cells of primary target
    final chainRange = cellSize * 2.0;
    final chainDamage = (wizard.currentDamage * 0.5).round();
    int chains = 0;
    final maxChains = 2 + (wizard.tier > 2 ? 1 : 0); // tier 3+ gets extra chain

    for (final enemy in _enemies) {
      if (chains >= maxChains) break;
      if (enemy == primaryTarget || enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
      final dist = primaryTarget.position.distanceTo(enemy.position);
      if (dist <= chainRange) {
        enemy.takeDamage(chainDamage);
        chains++;
      }
    }
  }

  void _applyTowerDamage(Tower tower, Enemy enemy) {
    int damage = tower.currentDamage;

    // Meta: Savaş Çığlığı - +30% damage first 3 waves
    if (_metaEarlyWaveDamageBonus > 0 && waveSystem.currentWave <= 3) {
      damage = (damage * (1.0 + _metaEarlyWaveDamageBonus)).round();
    }
    // Meta: Çelik Yumruk - +15% physical (arrow, cannon, spikeWall)
    if (_metaPhysicalDamageBonus > 0 &&
        (tower.type == TowerType.arrow || tower.type == TowerType.cannon || tower.type == TowerType.spikeWall)) {
      damage = (damage * (1.0 + _metaPhysicalDamageBonus)).round();
    }

    // Artifact: Boss damage +35%
    if (enemy.baseStats.isBoss) {
      damage = (damage * _artifactBossDamageMultiplier).round();
    }

    _totalDamageDealt += damage;
    tower.totalDamageDealt += damage;
    _showDamageText(enemy.position, damage);

    // Track kill (pre-check: if this damage will kill the enemy)
    final willKill = enemy.hp > 0 && enemy.hp <= damage;

    switch (tower.type) {
      case TowerType.ice:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.slow(factor: 0.4, duration: 2.0 * _artifactSlowDurationMultiplier));
        world.add(HitEffect.ice(pos: enemy.position));
        break;
      case TowerType.fire:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.burn(dps: 4, duration: 3.0));
        world.add(HitEffect.fire(pos: enemy.position));
        break;
      case TowerType.poison:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.poison(dps: 3, duration: 5.0));
        world.add(HitEffect.poison(pos: enemy.position));
        break;
      case TowerType.water:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.wet(duration: 3.0));
        world.add(HitEffect(pos: enemy.position, color: const Color(0xFF4169E1), count: 4, speed: 35));
        break;
      case TowerType.dark:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.curse(armorReduce: 8, duration: 4.0));
        world.add(HitEffect(pos: enemy.position, color: const Color(0xFF8B00FF), count: 5, speed: 40));
        break;
      case TowerType.lightning:
        final actualDmg = enemy.isWet ? damage * 2 : damage;
        enemy.takeDamage(actualDmg);
        world.add(HitEffect.lightning(pos: enemy.position));
        break;
      case TowerType.holy:
        final holyBonus = (enemy.type == EnemyType.undead || enemy.type == EnemyType.darkKnight || enemy.type == EnemyType.shadowLord)
            ? (damage * 0.5).round()
            : 0;
        enemy.takeDamage(damage + holyBonus);
        world.add(HitEffect(pos: enemy.position, color: const Color(0xFFFFFACD), count: 6, speed: 50));
        break;
      default:
        enemy.takeDamage(damage);
        world.add(HitEffect(pos: enemy.position, color: const Color(0xFFCCCCCC), count: 3, speed: 30, maxLife: 0.3));
        break;
    }

    if (willKill || enemy.isDead) {
      tower.kills++;
    }
  }

  void _processEnemies() {
    final toRemove = <Enemy>[];
    final toSpawn = <Enemy>[];
    for (final enemy in _enemies) {
      if (enemy.isDead) {
        double goldMult = _mutationGoldMult;
        if (enemy.baseStats.isBoss && _metaBossGoldMultiplier > 1.0) {
          goldMult *= _metaBossGoldMultiplier;
        }
        final goldEarned = (enemy.goldReward * goldMult).round();
        economy.earnGold(goldEarned);
        _enemiesKilled++;
        // Kill streak tracking
        _killStreak++;
        _killStreakTimer = _killStreakWindow;
        if (_killStreak >= 3) {
          // Bonus gold for kill streaks
          final streakBonus = _killStreak;
          economy.earnGold(streakBonus);
        }
        // Death particle effect
        world.add(HitEffect.death(pos: enemy.position));
        // Boss death: big screen shake
        if (enemy.baseStats.isBoss) {
          screenShake.shake(duration: 0.5, intensity: 8.0);
        }
        // Show gold earned text (with streak indicator)
        final streakText = _killStreak >= 3 ? ' x$_killStreak!' : '';
        world.add(FloatingText(
          text: '+${goldEarned}g$streakText',
          pos: enemy.position + Vector2(0, -15),
          color: _killStreak >= 5 ? const Color(0xFFFF4444) : _killStreak >= 3 ? const Color(0xFFFF8800) : const Color(0xFFFFD700),
          fontSize: _killStreak >= 5 ? 13 : _killStreak >= 3 ? 11 : 9,
        ));
        // Undead split mechanic
        if (enemy.baseStats.splitCount > 0) {
          final remainingPath = enemy.remainingPath;
          if (remainingPath.length > 1) {
            for (int i = 0; i < enemy.baseStats.splitCount; i++) {
              final split = Enemy(
                type: enemy.type,
                baseStats: EnemyStats(
                  type: enemy.type, name: enemy.baseStats.name,
                  hp: enemy.baseStats.splitHp, armor: 0,
                  speed: enemy.baseStats.speed * 1.2,
                  goldReward: 2, castleDamage: 1,
                  difficulty: enemy.baseStats.difficulty,
                ),
                path: remainingPath,
                cellSize: cellSize,
              );
              toSpawn.add(split);
            }
          }
        }
        toRemove.add(enemy);
      } else if (enemy.reachedCastle) {
        var dmg = _metaDamageReduction > 0
            ? (enemy.castleDamage * (1.0 - _metaDamageReduction)).ceil()
            : enemy.castleDamage;
        // Çift Sur: secondary shield absorbs damage first
        if (_secondaryShield > 0) {
          final absorbed = dmg.clamp(0, _secondaryShield);
          _secondaryShield -= absorbed;
          dmg -= absorbed;
        }
        if (dmg > 0) {
          castle.takeDamage(dmg);
          screenShake.shake(
            duration: 0.2,
            intensity: (dmg * 1.5).clamp(2.0, 8.0).toDouble(),
          );
        }
        // Goblin steals gold when reaching castle
        if (enemy.type == EnemyType.goblin) {
          final stolen = (10 + waveSystem.currentWave * 2).clamp(0, economy.gold);
          if (stolen > 0) {
            economy.trySpend(stolen);
            _goldStolen += stolen;
          }
        }
        toRemove.add(enemy);
      }
    }
    for (final enemy in toRemove) {
      _enemies.remove(enemy);
      enemy.removeFromParent();
    }
    for (final enemy in toSpawn) {
      _enemies.add(enemy);
      world.add(enemy);
    }
    if (toRemove.isNotEmpty) onStateChanged?.call();
  }

  void _updateHealerEnemies(double dt) {
    _healerTickTimer += dt;
    if (_healerTickTimer < 1.0) return;
    _healerTickTimer = 0;

    for (final enemy in _enemies) {
      if (enemy.isDead || enemy.reachedCastle) continue;
      if (enemy.type != EnemyType.healer) continue;

      // Heal nearby enemies within 2 cells
      for (final other in _enemies) {
        if (other == enemy || other.isDead || other.reachedCastle) continue;
        final dist = enemy.position.distanceTo(other.position);
        if (dist <= cellSize * 2.0 && other.hp < other.maxHp) {
          other.heal(5);
          world.add(FloatingText(
            text: '+5',
            pos: other.position + Vector2(0, -10),
            color: const Color(0xFF00FF00),
            fontSize: 8,
          ));
        }
      }
    }
  }

  void _onWaveComplete() {
    final goldBefore = economy.gold;
    economy.onWaveComplete(waveSystem.currentWave);
    // Artifact: Altın Taç - +15 gold per wave
    if (_artifactWaveGoldBonus > 0) {
      economy.earnGold(_artifactWaveGoldBonus);
    }
    // Meta: Hazine Odaları - +8 gold per wave
    if (_metaWaveGoldBonus > 0) {
      economy.earnGold(_metaWaveGoldBonus);
    }
    // Meta: Onarım Loncası - heal between waves
    if (_metaHealPerWave > 0) {
      castle.heal((castle.maxHp * _metaHealPerWave).round());
    }
    // Meta: Hazine Avcısı - bonus gold room chance
    if (_metaBonusGoldRoom > 0) {
      final rng = math.Random();
      if (rng.nextDouble() < _metaBonusGoldRoom) {
        final bonus = 20 + waveSystem.currentWave * 3;
        economy.earnGold(bonus);
      }
    }
    // Artifact: Cennet Kalkanı (id 12) - Full heal every 5 waves
    if (hasArtifact(12) && waveSystem.currentWave % 5 == 0) {
      castle.heal(castle.maxHp);
    }
    // Meta: Arkeolog - ancient artifact bonus gold chance
    if (_metaAncientArtifactChance > 0) {
      final rng = math.Random();
      if (rng.nextDouble() < _metaAncientArtifactChance) {
        final bonus = 50 + waveSystem.currentWave * 5;
        economy.earnGold(bonus);
      }
    }
    // Çift Sur: regenerate shield between waves
    if (_maxSecondaryShield > 0 && _secondaryShield < _maxSecondaryShield) {
      _secondaryShield = (_secondaryShield + (_maxSecondaryShield * 0.3).round())
          .clamp(0, _maxSecondaryShield);
    }

    // Show wave complete rewards floating text
    final goldEarned = economy.gold - goldBefore;
    final spiritEarned = economy.stoneSpirit;
    final castleCenter = castle.position + castle.size / 2;
    if (goldEarned > 0) {
      world.add(FloatingText(
        text: 'Dalga ${waveSystem.currentWave} tamamlandı! +${goldEarned}g',
        pos: castleCenter + Vector2(0, -30),
        color: const Color(0xFFFFD700),
        fontSize: 12,
      ));
    }

    if (waveSystem.isComplete) {
      if (_metaInfiniteMode) {
        // Infinite mode: continue with scaled enemies
        waveSystem.extendWaves(5);
      } else {
        _phase = GamePhase.gameOver;
        onGameOver?.call(true);
        return;
      }
    }

    if (_autoWave) {
      // Skip wave break, start immediately
      _breakTimer = 0;
      startNextWave();
    } else {
      _breakTimer = GameConfig.wavePrepTime * _mutationWavePrepMult;
      _phase = GamePhase.waveBreak;
      onStateChanged?.call();
    }
  }

  // --- Pause ---

  void togglePause() {
    if (_phase == GamePhase.paused) {
      _phase = _previousPhase;
    } else if (_phase != GamePhase.gameOver) {
      _previousPhase = _phase;
      _phase = GamePhase.paused;
    }
    onStateChanged?.call();
  }

  GamePhase _previousPhase = GamePhase.prep;

  // --- Tap handling via world component ---

  void handleGridTap(Vector2 worldPos) {
    if (!_isReady) return;
    if (_phase == GamePhase.paused || _phase == GamePhase.gameOver) return;

    final col = (worldPos.x / cellSize).floor();
    final row = (worldPos.y / cellSize).floor();

    if (col < 0 || col >= GameConfig.gridColumns) return;
    if (row < 0 || row >= GameConfig.gridRows) return;

    // If we have a tower type selected, try to place it
    if (selectedTowerType != null) {
      if (placeTower(col, row, selectedTowerType!)) {
        selectedTowerType = null;
        updatePlacementHighlight();
      }
      return;
    }

    // Otherwise, check if there's a placed tower at this position
    final existingType = _towerPositions[(col: col, row: row)];
    if (existingType != null) {
      final tower = _towers.firstWhere((t) => t.col == col && t.row == row);
      _selectPlacedTower((_selectedPlacedTower == tower) ? null : tower);
      return;
    }

    // Tap empty space: deselect
    _selectPlacedTower(null);
  }

  void _selectPlacedTower(Tower? tower) {
    // Clear previous range display
    _selectedPlacedTower?.showRange = false;
    _selectedPlacedTower = tower;
    // Show new range display
    _selectedPlacedTower?.showRange = true;
    onStateChanged?.call();
  }

  void sellSelectedTower() {
    if (_selectedPlacedTower == null) return;
    _selectedPlacedTower!.showRange = false;
    sellTower(_selectedPlacedTower!);
    _selectedPlacedTower = null;
  }

  void upgradeSelectedTower() {
    if (_selectedPlacedTower == null) return;
    upgradeTower(_selectedPlacedTower!);
  }

  void cycleSelectedTowerTargeting() {
    if (_selectedPlacedTower == null) return;
    if (_selectedPlacedTower!.type == TowerType.spikeWall || _selectedPlacedTower!.type == TowerType.support) return;
    final modes = TargetingMode.values;
    final current = modes.indexOf(_selectedPlacedTower!.targetingMode);
    _selectedPlacedTower!.targetingMode = modes[(current + 1) % modes.length];
    onStateChanged?.call();
  }

  void deselectPlacedTower() {
    _selectedPlacedTower?.showRange = false;
    _selectedPlacedTower = null;
    onStateChanged?.call();
  }

  // --- Helpers ---

  List<String> get activeSynergyNames =>
      synergySystem.activeSynergies.map((s) => s.name).toList();

  List<TowerType> get availableTowers =>
      TowerData.availableAt(waveSystem.currentWave, allUnlocked: _metaAllTowersUnlocked);

  int adjustedTowerCost(TowerType type) =>
      (TowerData.getStats(type).cost * _mutationTowerCostMult).round();

  /// Preview of next wave composition
  List<WaveEntry> get nextWavePreview {
    final next = waveSystem.currentWave + 1;
    if (next > waveSystem.totalWaves) return [];
    return WaveData.getWave(next, difficulty);
  }

  /// Meta: improved artifact quality flag
  bool get hasImprovedArtifacts => _metaImprovedArtifacts;
  /// Meta: extra artifact choice flag
  bool get hasExtraArtifactChoice => _metaExtraArtifactChoice;
  /// Meta: enemy weakness display flag
  bool get showEnemyWeakness => _metaEnemyWeakness;
  /// Meta: synergy hints flag
  bool get showSynergyHints => _metaSynergyHints;
  /// Secondary shield remaining
  int get secondaryShield => _secondaryShield;
  int get maxSecondaryShield => _maxSecondaryShield;

  void _showDamageText(Vector2 pos, int damage) {
    final isCritical = damage >= 30;
    final color = damage >= 30
        ? const Color(0xFFFF4444)
        : damage >= 15
            ? const Color(0xFFFFAA00)
            : const Color(0xFFFFFFFF);
    world.add(FloatingText(
      text: '-$damage',
      pos: pos + Vector2(0, -10),
      color: color,
      fontSize: damage >= 30 ? 14 : 10,
      isCritical: isCritical,
    ));
  }

  /// Track discovered synergies
  VoidCallback? onSynergyDiscovered;

  void setTowerSlots(int slots) => _towerSlots = slots;

  void updatePlacementHighlight() {
    final cells = gameMap.children.whereType<GridCell>();
    if (selectedTowerType == null || _towers.length >= _towerSlots) {
      for (final cell in cells) {
        cell.highlighted = false;
      }
      return;
    }
    final isSpikeWall = selectedTowerType == TowerType.spikeWall;
    for (final cell in cells) {
      final canPlace = gameMap.canPlaceTower(cell.col, cell.row, isSpikeWall: isSpikeWall)
          && !_towerPositions.containsKey((col: cell.col, row: cell.row));
      cell.highlighted = canPlace;
    }
  }
}

/// Transparent component in the world that catches taps and forwards to game.
/// Being in the world means tap coordinates are automatically in world space.
class _GridTapHandler extends PositionComponent with TapCallbacks {
  final KaleGame game;

  _GridTapHandler(this.game) : super(
    size: Vector2(KaleGame._gameWidth, KaleGame._gameHeight),
    priority: -1, // render behind everything
  );

  @override
  void onTapDown(TapDownEvent event) {
    game.handleGridTap(event.localPosition);
  }
}
