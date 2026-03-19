import 'package:flame/game.dart';
import 'package:flame/events.dart';
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

enum GamePhase { prep, waveActive, waveBreak, paused, gameOver }

class KaleGame extends FlameGame with TapCallbacks {
  late GameMap gameMap;
  late Castle castle;
  late EconomySystem economy;
  late WaveSystem waveSystem;
  late SynergySystem synergySystem;
  late double cellSize;

  final int mapSeed;
  final DifficultyTier difficulty;

  bool _isReady = false;
  bool get isReady => _isReady;

  GamePhase _phase = GamePhase.prep;
  GamePhase get phase => _phase;

  // Tower management
  final List<Tower> _towers = [];
  final Map<({int col, int row}), TowerType> _towerPositions = {};
  TowerType? selectedTowerType;
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

  // Callbacks for Flutter overlays
  VoidCallback? onStateChanged;
  void Function(bool isVictory)? onGameOver;

  KaleGame({
    required this.mapSeed,
    this.difficulty = DifficultyTier.apprentice,
  });

  @override
  Color backgroundColor() => const Color(0xFF1A150E);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Flame canvas: size.x=short side, size.y=long side in landscape
    // Map grid: rows along x (short=10 rows), columns along y (long=16 cols)
    final cellByRow = size.x / GameConfig.gridRows;
    final cellByCol = size.y / GameConfig.gridColumns;
    cellSize = (cellByRow < cellByCol ? cellByRow : cellByCol).clamp(1.0, double.infinity);

    gameMap = GameMap(cellSize: cellSize);
    gameMap.generate(seed: mapSeed);
    add(gameMap);

    castle = Castle(cellSize: cellSize);
    add(castle);

    economy = EconomySystem();
    economy.difficultyMultiplier = difficulty.spiritMultiplier;
    waveSystem = WaveSystem(difficulty: difficulty);
    synergySystem = SynergySystem();

    _phase = GamePhase.prep;
    _isReady = true;
    onStateChanged?.call(); // notify Flutter to show HUD
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
    _towers.add(tower);
    _towerPositions[(col: col, row: row)] = type;
    add(tower);

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
    _enemies.add(enemy);
    add(enemy);
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
        // Only notify once per second change to avoid excessive rebuilds
        onStateChanged?.call();
      }
      return;
    }

    if (_phase != GamePhase.waveActive) return;

    // Spawn enemies
    _updateSpawning(dt);

    // Tower targeting & firing
    _updateTowerCombat(dt);

    // Process enemies (remove dead/reached)
    _processEnemies();

    // Check wave complete
    if (_pendingSpawns.isEmpty && _enemies.isEmpty) {
      _onWaveComplete();
    }

    // Check game over
    if (castle.isDestroyed) {
      _phase = GamePhase.gameOver;
      onGameOver?.call(false);
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
          add(proj);
          // Instant hit for simplicity (projectile visual only)
          _applyTowerDamage(tower, target);
        }
      }
    }

    // Clean up projectiles that have hit
    final projectiles = children.whereType<Projectile>().toList();
    for (final p in projectiles) {
      if (p.hasHit) p.removeFromParent();
    }
  }

  void _applyTowerDamage(Tower tower, Enemy enemy) {
    final damage = tower.currentDamage;

    switch (tower.type) {
      case TowerType.ice:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.slow(factor: 0.4, duration: 2.0));
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
        // Double damage to wet enemies
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
    for (final enemy in _enemies) {
      if (enemy.isDead) {
        economy.earnGold(enemy.goldReward);
        _enemiesKilled++;
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
    if (toRemove.isNotEmpty) onStateChanged?.call();
  }

  void _onWaveComplete() {
    economy.onWaveComplete(waveSystem.currentWave);

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

  // --- Tap Handling ---

  @override
  void onTapDown(TapDownEvent event) {
    if (!_isReady) return;
    if (_phase == GamePhase.paused || _phase == GamePhase.gameOver) return;

    final pos = event.localPosition;
    // Screen x = row, screen y = col (swapped for landscape)
    final col = (pos.y / cellSize).floor();
    final row = (pos.x / cellSize).floor();

    if (selectedTowerType != null) {
      placeTower(col, row, selectedTowerType!);
      selectedTowerType = null;
    }
  }

  // --- Helpers ---

  List<String> get activeSynergyNames =>
      synergySystem.activeSynergies.map((s) => s.name).toList();

  List<TowerType> get availableTowers =>
      TowerData.availableAt(waveSystem.currentWave);

  void setTowerSlots(int slots) => _towerSlots = slots;
}
