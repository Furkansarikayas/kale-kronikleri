import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'components/map/game_map.dart';
import 'components/castle.dart';
import 'components/towers/tower.dart';
import 'components/towers/tower_factory.dart';
import 'components/towers/projectile.dart';
import 'components/enemies/enemy.dart';
import 'components/enemies/enemy_factory.dart';
import 'components/enemies/status_effect.dart';
import 'data/enemy_data.dart';
import 'data/game_config.dart';
import 'data/tower_data.dart';
import 'data/wave_data.dart';
import 'systems/economy_system.dart';
import 'systems/wave_system.dart';
import 'systems/synergy_system.dart';
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

  // Callbacks for Flutter overlays
  VoidCallback? onStateChanged;
  void Function(bool isVictory)? onGameOver;

  bool hasArtifact(int id) => artifacts.any((a) => a.id == id);

  KaleGame({
    required this.mapSeed,
    this.difficulty = DifficultyTier.apprentice,
    this.artifacts = const [],
    this.metaLevels = const {},
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

    gameMap = GameMap(cellSize: cellSize);
    gameMap.generate(seed: mapSeed);
    world.add(gameMap);

    castle = Castle(cellSize: cellSize);
    world.add(castle);

    // Tap handler in the world (receives world coordinates automatically)
    world.add(_GridTapHandler(this));

    economy = EconomySystem();
    economy.difficultyMultiplier = difficulty.spiritMultiplier;
    waveSystem = WaveSystem(difficulty: difficulty);
    synergySystem = SynergySystem();

    // Apply meta tree bonuses
    _applyMetaBonuses();

    _phase = GamePhase.prep;
    _isReady = true;
    onStateChanged?.call(); // notify Flutter to show HUD
  }

  void _applyMetaBonuses() {
    final savas = metaLevels['savas'] ?? 0;
    final kale = metaLevels['kale'] ?? 0;

    // Savaş tree
    if (savas >= 1) _towerSlots += 1; // Kule Hafızası: +1 slot
    if (savas >= 2) castle.heal((castle.maxHp * 0.25).round()); // Demir İrade: +25% HP (heal bonus)

    // Kale tree
    if (kale >= 2) _metaWaveGoldBonus = 8; // Hazine Odaları: +8 gold/wave
    if (kale >= 3) _metaHealPerWave = 0.15; // Onarım Loncası: 15% heal between waves
  }

  int _metaWaveGoldBonus = 0;
  double _metaHealPerWave = 0;

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
    if (!economy.trySpend(stats.cost)) return false; // deduct AFTER validation

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
    if (!economy.trySpend(tower.upgradeCost)) return false;
    tower.upgrade();
    onStateChanged?.call();
    return true;
  }

  void _recalculateSynergies() {
    synergySystem.recalculate(_towerPositions);
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
    if (gameMap.enemyPath.isEmpty) return; // safety
    final enemy = EnemyFactory.create(
      type: type,
      path: gameMap.enemyPath,
      cellSize: cellSize,
      difficulty: difficulty,
    );
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

    // Artifact: Ebedi Alev - all enemies take constant burn
    if (hasArtifact(11)) {
      for (final enemy in _enemies) {
        if (enemy.isDead || enemy.reachedCastle) continue;
        if (!enemy.activeEffects.any((e) => e.type == StatusType.burn)) {
          enemy.applyEffect(StatusEffect.burn(dps: 2, duration: 2.0));
        }
      }
    }

    // Process enemies (remove dead/reached)
    _processEnemies();

    // Check wave complete
    if (_pendingSpawns.isEmpty && _enemies.isEmpty) {
      _onWaveComplete();
    }

    // Check game over - Artifact: Ölümsüz Totem (id 8) revive once
    if (castle.isDestroyed) {
      if (hasArtifact(8) && !_totemUsed) {
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

      // Find nearest enemy in range
      Enemy? target;
      double bestDist = double.infinity;
      for (final enemy in _enemies) {
        if (enemy.isDead || enemy.reachedCastle) continue;
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
      if (enemy.isDead || enemy.reachedCastle) continue;
      final dist = center.distanceTo(enemy.position);
      if (dist <= cellSize * 0.8) {
        enemy.takeDamage(spikeWall.currentDamage);
      }
    }
  }

  void _applyTowerDamage(Tower tower, Enemy enemy) {
    int damage = tower.currentDamage;

    // Artifact: Boss damage +35%
    if (enemy.baseStats.isBoss) {
      damage = (damage * _artifactBossDamageMultiplier).round();
    }

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
      default:
        enemy.takeDamage(damage);
        break;
    }
  }

  void _processEnemies() {
    final toRemove = <Enemy>[];
    final toSpawn = <Enemy>[];
    for (final enemy in _enemies) {
      if (enemy.isDead) {
        economy.earnGold(enemy.goldReward);
        _enemiesKilled++;
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
        castle.takeDamage(enemy.castleDamage);
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
    // Artifact: Cennet Kalkanı (id 12) - Full heal every 5 waves
    if (hasArtifact(12) && waveSystem.currentWave % 5 == 0) {
      castle.heal(castle.maxHp);
    }

    if (waveSystem.isComplete) {
      _phase = GamePhase.gameOver;
      onGameOver?.call(true);
      return;
    }

    _breakTimer = GameConfig.wavePrepTime;
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
      TowerData.availableAt(waveSystem.currentWave);

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
