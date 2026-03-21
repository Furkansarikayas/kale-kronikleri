import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'components/map/game_map.dart';
import 'components/castle.dart';
import 'components/towers/tower.dart';
import 'components/towers/tower_factory.dart';
import 'components/towers/projectile.dart';
import 'components/enemies/enemy.dart';
import 'components/enemies/enemy_factory.dart';
import 'components/enemies/status_effect.dart';
import 'components/floating_text.dart';
import 'data/enemy_data.dart';
import 'data/game_config.dart';
import 'data/tower_data.dart';
import 'data/wave_data.dart';
import 'systems/economy_system.dart';
import 'systems/wave_system.dart';
import 'systems/synergy_system.dart';
import 'systems/mutation_system.dart';
import '../meta/artifact_system.dart';

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

  // Wave break
  double _breakTimer = 0;
  double get breakTimeRemaining => _breakTimer;

  // Artifact state
  bool _totemUsed = false;
  double _healerTickTimer = 0;

  // Synergy effect timers
  double _kiyametTimer = 0;
  bool _buzulCagiActive = false;

  // Castle AoE meta
  double _castleAoeTimer = 0;

  // Son Nefes invincibility
  double _invincibilityTimer = 0;
  bool _sonNefesUsed = false;

  // Track total damage dealt for stats
  int _totalDamageDealt = 0;
  int get totalDamageDealt => _totalDamageDealt;
  int _goldStolen = 0;
  int get goldStolen => _goldStolen;

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
  }) : super(
    camera: CameraComponent.withFixedResolution(
      width: _gameWidth,
      height: _gameHeight,
    ),
  );

  @override
  Color backgroundColor() => const Color(0xFF1A150E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Fixed resolution: world is exactly _gameWidth x _gameHeight
    // Viewfinder anchor topLeft so (0,0) = top-left corner
    camera.viewfinder.anchor = Anchor.topLeft;
    cellSize = fixedCellSize;

    // Multiple spawn paths based on difficulty
    final spawnCount = difficulty == DifficultyTier.apprentice ? 1
        : difficulty == DifficultyTier.knight ? 1
        : 2; // lord+ get 2 spawn points
    gameMap = GameMap(cellSize: cellSize);
    gameMap.generate(seed: mapSeed, spawnCount: spawnCount);
    world.add(gameMap);

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
    if (kesif >= 4) _metaBonusGoldRoom = 0.15; // Hazine Avcısı: 15% bonus gold chance

    // Kale tree
    if (kale >= 1) _metaDamageReduction = 0.30; // Taş Duvarlar: 30% damage reduction
    if (kale >= 2) _metaWaveGoldBonus = 8; // Hazine Odaları: +8 gold/wave
    if (kale >= 3) _metaHealPerWave = 0.15; // Onarım Loncası: 15% heal between waves
    if (kale >= 5) _metaBossGoldMultiplier = 2.0; // Vergi Toplayıcı: 2x boss gold

    // Efsane tree
    if (efsane >= 2) _metaSpeedOptions = true; // Zaman Büküm: 3x speed option
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
  bool _metaSpeedOptions = false;
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
      final synergyMult = _artifactSynergyMultiplier; // Kader Aynası artifact
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
        }
      }
    }

    // Track synergy effects
    _buzulCagiActive = active.any((s) => s.id == 9);

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

      // Find nearest enemy in range (skip burrowed enemies)
      Enemy? target;
      double bestDist = double.infinity;
      for (final enemy in _enemies) {
        if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
        if (!tower.isInRange(enemy.position)) continue;
        final d = (tower.position + tower.size / 2).distanceTo(enemy.position);
        if (d < bestDist) {
          bestDist = d;
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
        break;
      case TowerType.fire:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.burn(dps: 4, duration: 3.0));
        break;
      case TowerType.poison:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.poison(dps: 3, duration: 5.0));
        break;
      case TowerType.water:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.wet(duration: 3.0));
        break;
      case TowerType.dark:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.curse(armorReduce: 8, duration: 4.0));
        break;
      case TowerType.lightning:
        final actualDmg = enemy.isWet ? damage * 2 : damage;
        enemy.takeDamage(actualDmg);
        break;
      case TowerType.holy:
        // Holy: bonus damage to undead and dark enemies
        final holyBonus = (enemy.type == EnemyType.undead || enemy.type == EnemyType.darkKnight || enemy.type == EnemyType.shadowLord)
            ? (damage * 0.5).round()
            : 0;
        enemy.takeDamage(damage + holyBonus);
        break;
      default:
        enemy.takeDamage(damage);
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
        // Show gold earned text
        world.add(FloatingText(
          text: '+${goldEarned}g',
          pos: enemy.position + Vector2(0, -15),
          color: const Color(0xFFFFD700),
          fontSize: 9,
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
        final dmg = _metaDamageReduction > 0
            ? (enemy.castleDamage * (1.0 - _metaDamageReduction)).ceil()
            : enemy.castleDamage;
        castle.takeDamage(dmg);
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

    if (waveSystem.isComplete) {
      _phase = GamePhase.gameOver;
      onGameOver?.call(true);
      return;
    }

    _breakTimer = GameConfig.wavePrepTime * _mutationWavePrepMult;
    _phase = GamePhase.waveBreak;
    onStateChanged?.call();
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
    if (next > difficulty.totalWaves) return [];
    return WaveData.getWave(next, difficulty);
  }

  void _showDamageText(Vector2 pos, int damage) {
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
    ));
  }

  /// Track discovered synergies
  VoidCallback? onSynergyDiscovered;

  void setTowerSlots(int slots) => _towerSlots = slots;
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
