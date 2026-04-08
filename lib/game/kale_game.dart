import 'dart:async';
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
import 'components/effects/spell_overlay.dart';
import 'components/effects/danger_vignette.dart';
import 'components/effects/sell_effect.dart';
import 'components/effects/wave_banner.dart';
import 'components/effects/wave_clear_effect.dart';
import 'components/effects/wave_incoming_warning.dart';
import 'data/enemy_data.dart';
import 'data/game_config.dart';
import 'data/tower_data.dart';
import 'data/wave_data.dart';
import 'systems/economy_system.dart';
import 'systems/wave_system.dart';
import 'systems/synergy_system.dart';
import 'systems/mutation_system.dart';
import 'systems/elite_system.dart';
import 'systems/combo_system.dart';
import 'systems/spell_system.dart';
import 'systems/event_system.dart';
import 'systems/audio_system.dart';
import 'systems/tutorial_system.dart';
import 'systems/wave_buff_system.dart';
import 'systems/wave_modifier_system.dart';
import 'systems/spatial_grid.dart';
import 'data/t4_branch_data.dart';
import '../meta/artifact_system.dart';
import 'rendering/sprite_cache.dart';
import 'components/rendering/castle_sprites.dart';
import 'components/rendering/tower_sprites.dart';
import 'components/rendering/enemy_sprites.dart';
import 'components/debug_overlay.dart';

enum GamePhase { prep, waveActive, waveBreak, paused, gameOver }

class KaleGame extends FlameGame {
  static const double fixedCellSize = 64.0;
  static final double _gameWidth = GameConfig.gridColumns * fixedCellSize;
  static final double _gameHeight = GameConfig.gridRows * fixedCellSize;
  // Extra sky strip above the grid for parallax sky/stars/moon visibility
  static const double _skyExtension = 90.0;
  static final double _viewportHeight = _gameHeight + _skyExtension;

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
  final bool isFirstRun;

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

  // Tracked projectile list (avoids O(n) whereType scans)
  final List<Projectile> _projectiles = [];

  // Spatial grid for O(1) range queries instead of O(N) enemy scans
  final SpatialGrid _spatialGrid = SpatialGrid();

  // Debug overlay (toggle with debugOverlayEnabled)
  late final DebugOverlay _debugOverlay;

  // Enemy management
  final List<Enemy> _enemies = [];
  int _enemiesKilled = 0;
  int get enemiesKilled => _enemiesKilled;
  int _cachedEnemiesAlive = 0;
  int get enemiesAlive => _cachedEnemiesAlive;

  // Achievement tracking
  int _bossesKilled = 0;
  int get bossesKilled => _bossesKilled;

  // Run objectives
  bool get objectiveWaves => waveSystem.currentWave >= 10;
  bool get objectiveKills => _enemiesKilled >= 50;
  bool get objectiveBoss => _bossesKilled >= 1;
  int get objectiveBonusSpirit {
    int bonus = 0;
    if (objectiveWaves) bonus += 10;
    if (objectiveKills) bonus += 10;
    if (objectiveBoss) bonus += 15;
    return bonus;
  }
  int _totalTowersPlacedThisRun = 0;
  int get totalTowersPlacedThisRun => _totalTowersPlacedThisRun;
  int _consecutivePerfectWaves = 0;
  int _bestPerfectWaves = 0;
  int get bestPerfectWaves => _bestPerfectWaves;
  bool _damageTakenThisWave = false;

  // Wave spawning
  List<WaveEntry> _pendingSpawns = [];
  double _spawnTimer = 0;
  double _waveActiveTimer = 0; // safety: force-end stuck waves
  int _spawnIndex = 0;
  double _currentSpawnDelay = 0.8;
  int _waveEnemyTotal = 0;
  int get waveEnemyTotal => _waveEnemyTotal;

  // Wave path pattern — controls which paths enemies use each wave
  WavePathPattern _wavePathPattern = WavePathPattern.spread;
  int _focusedPathIndex = 0; // for focused/pincer patterns
  int _waveSpawnCounter = 0; // tracks spawn index for round-robin
  WavePathPattern get wavePathPattern => _wavePathPattern;
  int get focusedPathIndex => _focusedPathIndex;

  /// Preview of what path pattern the next wave will use.
  WavePathPattern get nextWavePathPattern {
    final nextWave = waveSystem.currentWave + 1;
    final pathRng = math.Random(mapSeed + nextWave);
    return WavePathSelector.selectPattern(nextWave, gameMap.enemyPaths.length, pathRng);
  }

  // Wave break
  double _breakTimer = 0;
  WaveIncomingWarning? _waveWarning;
  double get breakTimeRemaining => _breakTimer;

  // Gold UI reject feedback (increments on each insufficient-gold attempt)
  int _goldRejectCounter = 0;
  int get goldRejectCounter => _goldRejectCounter;

  // Artifact state
  bool _totemUsed = false;
  double _healerTickTimer = 0;
  double _chaosStoneTimer = 0; // Artifact #7: random synergy trigger

  // Synergy effect timers
  double _kiyametTimer = 0;
  bool _buzulCagiActive = false;
  bool _ultimateSynergyActive = false;
  double _ultimateSynergyTimer = 0;
  double _dengePatlamasiTimer = 0;
  bool _buzHapsiActive = false;

  // Castle AoE meta
  double _castleAoeTimer = 0;

  // Son Nefes invincibility
  double _invincibilityTimer = 0;
  bool _sonNefesUsed = false;

  // Screen shake
  late ScreenShake screenShake;
  late DangerVignette _dangerVignette;
  late AtmosphereOverlay _atmosphere;

  // Hit-stop (micro freeze on strong impacts)
  double _hitStopTimer = 0;
  static const double _hitStopTimeScale = 0.05; // near-freeze
  static const double _hitStopMax = 0.08; // cap duration

  // Kill streak
  int _killStreak = 0;
  double _killStreakTimer = 0;
  static const double _killStreakWindow = 1.5; // seconds to chain kills
  int _bestKillStreak = 0;
  int get bestKillStreak => _bestKillStreak;
  int _totalPerfectWaves = 0;
  int get totalPerfectWaves => _totalPerfectWaves;

  // Tower ambient presence
  double _towerAmbientTimer = 0;
  static const double _towerAmbientInterval = 5.0;

  // Meta: Çift Sur (Kale 4) - secondary HP shield
  int _secondaryShield = 0;
  int _maxSecondaryShield = 0;

  // Track total damage dealt for stats
  int _totalDamageDealt = 0;
  int get totalDamageDealt => _totalDamageDealt;
  int _goldStolen = 0;
  int get goldStolen => _goldStolen;

  // New systems
  late ComboSystem comboSystem;
  late SpellSystem spellSystem;
  late final TutorialSystem tutorialSystem;

  // ═══ Wave Modifier System ═══
  WaveModifier _activeWaveModifier = WaveModifier.none;
  WaveModifier get activeWaveModifier => _activeWaveModifier;

  // ═══ Enemy Adaptation: dominant tower type tracking ═══
  TowerType? _dominantTowerType;
  static const int _adaptationThreshold = 3; // need 3+ of same type

  // ═══ Build Identity Tracking ═══
  String _currentBuildLabel = '';
  String get currentBuildLabel => _currentBuildLabel;
  bool _buildLabelAnnounced = false;
  // Track most-used tower type for death screen summary
  TowerType? _mostUsedTowerType;
  TowerType? get mostUsedTowerType => _mostUsedTowerType;
  // Track previously active synergy IDs for per-synergy discovery
  final Set<int> _previousSynergyIds = {};
  String _topSynergyName = '';
  String get topSynergyName => _topSynergyName;

  // ═══ Castle Attrition: escalating pressure after wave 15 ═══
  static const int _attritionStartWave = 15;

  // Elite enemy RNG
  late math.Random _eliteRng;

  // Boss ability tracking
  final Map<Enemy, double> _bossAbilityTimers = {};
  bool _hasBossAlive = false;
  final List<Enemy> _activeBosses = [];

  // Staged boss spawn: spread boss intro across multiple frames
  Enemy? _pendingBossSpawn;
  int _bossSpawnStage = 0; // 0=idle, 1=entity created, 2=effects, 3=audio+abilities

  // === BOSS DEBUG FLAGS — toggle to isolate freeze culprit ===
  // Set any to true to DISABLE that subsystem during boss combat.
  // Test on device: enable one at a time to find which removes the freeze.
  bool debugDisableBossAura = false;       // boss aura + ground shadow rendering
  bool debugDisableBossAbilities = false;  // boss special attacks (teleport/breath)
  bool debugDisableBossAudio = false;      // boss-specific audio (bossRoar)
  bool debugDisableBossEffects = false;    // hit effects during boss combat
  bool debugDisableBossTexts = false;      // floating texts during boss combat
  bool debugDisableTowerFire = false;      // all tower firing (nuclear option)

  // T4 branch selection
  Tower? _pendingT4Tower;
  Tower? get pendingT4Tower => _pendingT4Tower;

  // Spell system state
  List<SpellType> get availableSpells => spellSystem.availableSpells(waveSystem.currentWave);
  bool canCastSpell(SpellType type) => spellSystem.canCast(type) && _phase == GamePhase.waveActive;
  double spellCooldown(SpellType type) => spellSystem.getCooldown(type);
  double spellMaxCooldown(SpellType type) => spellSystem.getMaxCooldown(type);

  // Wave events
  WaveEventDef? _currentEvent;
  WaveEventDef? get currentEvent => _currentEvent;
  bool _merchantAvailable = false;
  bool get merchantAvailable => _merchantAvailable;

  // Tower curse tracking (event)
  final Map<Tower, int> _cursedTowerWaves = {};

  // Infinite wave tracking
  double _endlessScaling = 1.0;
  bool get showEndlessPrompt => false; // No prompt — waves are always infinite

  // Roguelike buff system (per-run)
  final RunBuffState runBuffs = RunBuffState();
  List<WaveBuff>? _pendingBuffChoices;
  List<WaveBuff>? get pendingBuffChoices => _pendingBuffChoices;

  void selectWaveBuff(WaveBuff buff) {
    runBuffs.applyBuff(buff);
    _pendingBuffChoices = null;
    // Apply castle heal immediately if that buff was chosen
    if (runBuffs.castleHealPending > 0) {
      castle.heal(runBuffs.castleHealPending);
      runBuffs.castleHealPending = 0;
    }
    onStateChanged?.call();
  }

  // ═══ Wave 2 Tower Choice System ═══
  // Player picks Fire OR SpikeWall at wave 2; unchosen unlocks at wave 4
  TowerType? _wave2Choice;
  TowerType? get wave2Choice => _wave2Choice;
  bool _pendingTowerChoice = false;
  bool get pendingTowerChoice => _pendingTowerChoice;
  static const _wave2Options = [TowerType.fire, TowerType.spikeWall];

  void selectWave2Tower(TowerType chosen) {
    _wave2Choice = chosen;
    _pendingTowerChoice = false;
    onStateChanged?.call();
  }

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

  /// Trigger a micro-freeze hit-stop. Refreshes if stronger; caps at _hitStopMax.
  void triggerHitStop(double duration) {
    final capped = duration.clamp(0.0, _hitStopMax);
    if (capped > _hitStopTimer) {
      _hitStopTimer = capped;
    }
  }

  // Callbacks for Flutter overlays
  VoidCallback? onStateChanged;
  void Function(bool isVictory)? onGameOver;

  bool hasArtifact(int id) => artifacts.any((a) => a.id == id);

  // Base camera X offset to center the grid on wide screens
  double _cameraBaseX = 0;

  KaleGame({
    required this.mapSeed,
    this.difficulty = DifficultyTier.apprentice,
    this.artifacts = const [],
    this.metaLevels = const {},
    this.mutations = const [],
    this.initialScreenShakeEnabled = true,
    this.isFirstRun = false,
  }) {
    tutorialSystem = TutorialSystem(isFirstRun: isFirstRun);
  }

  @override
  Color backgroundColor() => const Color(0xFF080C14);

  /// Set when onLoad fails — read by AppShell to show error UI.
  String? loadError;

  @override
  Future<void> onLoad() async {
    int lastStep = 0;
    final sw = Stopwatch()..start();
    try {
      debugPrint('[KaleGame] [1] onLoad START (difficulty: ${difficulty.name}, biome: ${difficulty.biome.type.name})');
      lastStep = 1;
      await super.onLoad();

      // [2] Initialize sprites — each with individual timeout detection
      debugPrint('[KaleGame] [2] Starting sprite/audio initialization...');
      lastStep = 2;

      // Run each initializer individually so we can pinpoint which one hangs
      final spriteSw = Stopwatch()..start();

      debugPrint('[KaleGame] [2a] SpriteCache.initialize...');
      await SpriteCache.instance.initialize(biome: difficulty.biome)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('[2a] SpriteCache.initialize hung after 15s');
      });
      debugPrint('[KaleGame] [2a] SpriteCache done (${spriteSw.elapsedMilliseconds}ms)');

      debugPrint('[KaleGame] [2b] CastleSpriteGenerator.initialize...');
      await CastleSpriteGenerator.instance.initialize()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('[2b] CastleSpriteGenerator hung after 15s');
      });
      debugPrint('[KaleGame] [2b] CastleSprites done (${spriteSw.elapsedMilliseconds}ms)');

      debugPrint('[KaleGame] [2c] TowerSpriteGenerator.initialize...');
      await TowerSpriteGenerator.instance.initialize()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('[2c] TowerSpriteGenerator hung after 15s');
      });
      debugPrint('[KaleGame] [2c] TowerSprites done (${spriteSw.elapsedMilliseconds}ms)');

      debugPrint('[KaleGame] [2d] EnemySpriteGenerator.initialize...');
      await EnemySpriteGenerator.instance.initialize()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('[2d] EnemySpriteGenerator hung after 15s');
      });
      debugPrint('[KaleGame] [2d] EnemySprites done (${spriteSw.elapsedMilliseconds}ms)');

      debugPrint('[KaleGame] [2e] AudioSystem.initialize...');
      await AudioSystem.instance.initialize()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('[2e] AudioSystem.initialize hung after 15s');
      });
      debugPrint('[KaleGame] [2e] Audio done (${spriteSw.elapsedMilliseconds}ms)');

      debugPrint('[KaleGame] [2] ALL sprites loaded in ${spriteSw.elapsedMilliseconds}ms');

      // [3] Verify sprite state
      debugPrint('[KaleGame] [3] Verifying sprite cache state...');
      lastStep = 3;
      final shadowLordCached = EnemySpriteGenerator.instance.getWalkSheet(EnemyType.shadowLord) != null;
      final dragonCached = EnemySpriteGenerator.instance.getWalkSheet(EnemyType.dragonEmperor) != null;
      debugPrint('[KaleGame] [3] SpriteCache.initialized=${SpriteCache.instance.isInitialized}, '
          'Castle=${CastleSpriteGenerator.instance.isInitialized}, '
          'Tower=${TowerSpriteGenerator.instance.isInitialized}, '
          'Enemy=${EnemySpriteGenerator.instance.isInitialized}, '
          'bosses: shadowLord=$shadowLordCached dragon=$dragonCached');
      AudioSystem.instance.startMusic();

      // [4] Camera setup
      debugPrint('[KaleGame] [4] Camera setup (size: $size)');
      lastStep = 4;
      final zoom = size.y / _viewportHeight;
      if (zoom <= 0 || !zoom.isFinite) {
        throw StateError('[4] Invalid zoom: $zoom (size.y=${size.y}, viewportH=$_viewportHeight)');
      }
      camera.viewfinder.zoom = zoom;
      camera.viewfinder.anchor = Anchor.topLeft;
      final visibleWidth = size.x / zoom;
      _cameraBaseX = (_gameWidth - visibleWidth) / 2;
      camera.viewfinder.position = Vector2(_cameraBaseX, 0);
      cellSize = fixedCellSize;
      debugPrint('[KaleGame] [4] Camera done (zoom: ${zoom.toStringAsFixed(3)})');

      // [5] World components
      debugPrint('[KaleGame] [5] Creating world components...');
      lastStep = 5;
      screenShake = ScreenShake()..enabled = initialScreenShakeEnabled;
      add(screenShake);

      final spawnCount = difficulty == DifficultyTier.apprentice ? 2
          : difficulty == DifficultyTier.knight ? 2
          : difficulty == DifficultyTier.lord ? 3
          : 3;
      gameMap = GameMap(cellSize: cellSize);
      gameMap.generate(seed: mapSeed, spawnCount: spawnCount);
      world.add(ParallaxBackground(biome: difficulty.biome));
      world.add(gameMap);
      _atmosphere = AtmosphereOverlay(
        biomeType: difficulty.biome.type,
      );
      world.add(_atmosphere);

      _dangerVignette = DangerVignette();
      world.add(_dangerVignette);

      castle = Castle(cellSize: cellSize);
      world.add(castle);
      world.add(_GridTapHandler(this));
      debugPrint('[KaleGame] [5] World components added');

      // [6] Game systems
      debugPrint('[KaleGame] [6] Initializing game systems...');
      lastStep = 6;
      economy = EconomySystem();
      economy.difficultyMultiplier = difficulty.spiritMultiplier;
      waveSystem = WaveSystem(difficulty: difficulty, mapSeed: mapSeed);
      synergySystem = SynergySystem();
      comboSystem = ComboSystem();
      spellSystem = SpellSystem();
      _eliteRng = math.Random(mapSeed);
      _mutationWavePrepMult = MutationSystem.wavePrepMultiplier(mutations);
      _mutationGoldMult = MutationSystem.goldRewardMultiplier(mutations);
      _mutationTowerCostMult = MutationSystem.towerCostMultiplier(mutations);
      debugPrint('[KaleGame] [6] Systems ready');

      // [7] Meta bonuses
      debugPrint('[KaleGame] [7] Applying meta bonuses: $metaLevels');
      lastStep = 7;
      _applyMetaBonuses();
      debugPrint('[KaleGame] [7] Meta bonuses applied');

      // [8] Final setup
      debugPrint('[KaleGame] [8] Final setup...');
      lastStep = 8;
      _debugOverlay = DebugOverlay();
      camera.viewport.add(_debugOverlay);

      _phase = GamePhase.prep;
      _isReady = true;
      debugPrint('[KaleGame] [8] onLoad COMPLETE in ${sw.elapsedMilliseconds}ms — game is ready');
      tutorialSystem.tryShow(TutorialTrigger.gameStart);
      onStateChanged?.call();
    } on TimeoutException catch (e) {
      debugPrint('[KaleGame] TIMEOUT at step [$lastStep]: $e');
      debugPrint('[KaleGame] Total elapsed: ${sw.elapsedMilliseconds}ms');
      loadError = 'Yükleme zaman aşımı (adım $lastStep): $e';
      _isReady = false;
      onStateChanged?.call();
    } catch (e, stack) {
      debugPrint('[KaleGame] FAILED at step [$lastStep]: $e');
      debugPrint('[KaleGame] Stack trace: $stack');
      debugPrint('[KaleGame] Total elapsed: ${sw.elapsedMilliseconds}ms');
      loadError = 'Adım $lastStep hatası: $e';
      _isReady = false;
      onStateChanged?.call();
    }
  }

  /// Toggle the debug FPS/entity overlay
  bool get debugOverlayEnabled => _debugOverlay.enabled;
  set debugOverlayEnabled(bool v) => _debugOverlay.enabled = v;

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
    // Efsane 7 (Ebedi Kale) — infinite mode is now always on; bonus: +5% starting HP
    if (efsane >= 7) _metaInfiniteHpBonus = 0.05;
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
  double _metaInfiniteHpBonus = 0;
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
    final adjustedCost = (stats.cost * _mutationTowerCostMult * runBuffs.towerCostMultiplier).round();
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
    _totalTowersPlacedThisRun++;
    _towerPositions[(col: col, row: row)] = type;
    world.add(tower);

    _recalculateSynergies();
    AudioSystem.instance.play(GameSound.towerPlace);
    if (_towers.length == 1) tutorialSystem.tryShow(TutorialTrigger.firstTowerPlaced);
    onStateChanged?.call();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Merge system: combine two same-type, same-tier towers → free upgrade
  // ---------------------------------------------------------------------------

  /// Whether [source] can merge into [target].
  bool canMerge(Tower source, Tower target) {
    if (source == target) return false;
    if (source.type != target.type) return false;
    if (source.tier != target.tier) return false;
    if (source.tier >= 4) return false; // max tier, can't merge further
    // Don't merge if target already has a T4 branch chosen
    if (target.t4Branch != T4BranchPath.none) return false;
    return true;
  }

  /// Merge [source] tower into [target]. Target gets upgraded, source is removed.
  /// Returns true if merge succeeded.
  bool mergeTowers(Tower source, Tower target) {
    if (!canMerge(source, target)) return false;

    // Upgrade the target tower
    target.upgrade();
    // Transfer the source's total investment to target (for sell value calc)
    target.addSpent(source.totalSpent);

    // Remove source tower
    _towers.remove(source);
    _towerPositions.remove((col: source.col, row: source.row));
    _spikeWallTimers.remove(source); // prevent dead tower reference leak
    source.removeFromParent();

    // Visual feedback: merge text + enhanced merge effect
    target.triggerMergeEffect();
    world.add(FloatingText(
      text: 'BİRLEŞTİ!',
      pos: Vector2(target.col * cellSize + cellSize / 2, target.row * cellSize - 8),
      color: const Color(0xFFFFD700),
      fontSize: 14,
    ));

    _recalculateSynergies();
    AudioSystem.instance.play(GameSound.towerMerge);
    onStateChanged?.call();
    return true;
  }

  /// Get list of towers that can merge with the given tower.
  List<Tower> getMergeCandidates(Tower tower) {
    return _towers.where((t) => canMerge(tower, t)).toList();
  }

  int sellTower(Tower tower) {
    final refund = tower.sellValue;
    economy.earnGold(refund);

    // Spawn dissolve effect at tower position before removing
    world.add(SellEffect(
      pos: tower.position.clone(),
      cellSize: cellSize,
      color: Tower.primaryColor(tower.type),
    ));
    // Show gold refund amount
    world.add(FloatingText(
      text: '+${refund}g',
      pos: tower.position + Vector2(0, -10),
      color: const Color(0xFFFFD700),
      fontSize: 9,
    ));

    _towers.remove(tower);
    _towerPositions.remove((col: tower.col, row: tower.row));
    _spikeWallTimers.remove(tower); // prevent dead tower reference leak
    tower.removeFromParent();

    _recalculateSynergies();
    AudioSystem.instance.play(GameSound.towerSell);
    onStateChanged?.call();
    return refund;
  }

  bool upgradeTower(Tower tower) {
    if (!tower.canUpgrade) return false;
    // T4 needs branch selection via UI
    if (tower.needsT4Choice) {
      requestT4Upgrade(tower);
      return false; // don't deduct yet, wait for branch selection
    }
    final cost = (_metaUpgradeCostReduction > 0)
        ? (tower.upgradeCost * (1.0 - _metaUpgradeCostReduction)).round()
        : tower.upgradeCost;
    final towerPos = Vector2(tower.col * cellSize + cellSize / 2, tower.row * cellSize - 8);
    if (!economy.trySpend(cost)) {
      // Insufficient gold for upgrade
      _goldRejectCounter++;
      onStateChanged?.call();
      world.add(FloatingText(
        text: 'YETERSİZ ALTIN',
        pos: towerPos,
        color: const Color(0xFFFF4444),
        fontSize: 8,
      ));
      return false;
    }
    tower.upgrade();
    tower.triggerTierUpEffect();
    // Tier name (gold, celebratory)
    world.add(FloatingText(
      text: tower.stats.tierNames[tower.tier - 1],
      pos: towerPos,
      color: const Color(0xFFFFD700),
      fontSize: 12,
    ));
    // Spend cost (smaller, offset below tier name)
    world.add(FloatingText(
      text: '-${cost}g',
      pos: towerPos + Vector2(0, 12),
      color: const Color(0xFFFF9966),
      fontSize: 8,
    ));
    AudioSystem.instance.play(GameSound.towerUpgrade);
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

        // Apply bonuses based on synergy type (nerfed multipliers)
        switch (synergy.id) {
          case 1: // Dondur-Patlat: 1.3x damage (was 2x)
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.3 * synergyMult);
            break;
          case 2: // Buhar Hasarı: +0.5 range, faster fire
            tower.applySynergyBonus(rangeBonus: 0.5 * synergyMult, fireRateMultiplier: 0.85);
            break;
          case 3: // Şok Dalgası: 1.3x damage (was 2x)
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.3 * synergyMult);
            break;
          case 4: // Asit Tuzağı: +1.0 range (was +1.5)
            tower.applySynergyBonus(rangeBonus: 1.0 * synergyMult);
            break;
          case 5: // Yanık Asit: 1.25x damage (was 1.5x)
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.25 * synergyMult);
            break;
          case 6: // Denge Patlaması: 1.25x damage (was 1.5x)
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.25 * synergyMult);
            break;
          case 7: // Buz Hapsi: 3s full freeze on hit
            tower.applySynergyBonus(rangeBonus: 0.3 * synergyMult);
            tower.synergyFreezeOnHit = true;
            break;
          case 8: // Cehennem Hattı: 1.4x damage (was 1.8x)
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.4 * synergyMult);
            break;
          case 9: // Buzul Çağı: +1.0 range (was +2)
            tower.applySynergyBonus(rangeBonus: 1.0 * synergyMult);
            break;
          case 10: // Kıyamet: 1.5x damage (was 2.5x)
            tower.applySynergyBonus(damageMultiplier: 1.0 + 0.5 * synergyMult);
            break;
          case 11: // Tanrıların Gazabı: 1.8x damage (was 3x, requires meta)
            if (_metaUltimateSynergy) {
              tower.applySynergyBonus(damageMultiplier: 1.0 + 0.8 * synergyMult, rangeBonus: 1.0);
            }
            break;
        }
      }
    }

    // Track synergy effects
    _buzulCagiActive = active.any((s) => s.id == 9);
    _ultimateSynergyActive = _metaUltimateSynergy && active.any((s) => s.id == 11);
    _buzHapsiActive = active.any((s) => s.id == 7);

    // ═══ Synergy Recognition: per-synergy discovery labels ═══
    final currentIds = active.map((s) => s.id).toSet();
    for (final synergy in active) {
      if (!_previousSynergyIds.contains(synergy.id)) {
        // New synergy discovered — show unique label + visual burst
        final anchor = synergy.anchorPosition;
        final pos = Vector2(
          (anchor.col + 0.5) * cellSize,
          (anchor.row + 0.5) * cellSize,
        );
        world.add(FloatingText(
          text: synergy.name,
          pos: pos + Vector2(0, -20),
          color: const Color(0xFFFFD700),
          fontSize: 12,
          isCritical: true,
        ));
        _addEffect(HitEffect(
          pos: pos,
          color: const Color(0xFFFFD700),
          count: 10,
          speed: 70,
          size: 2.5,
          maxLife: 0.5,
        ));
        // Track top synergy for death screen
        _topSynergyName = synergy.name;
      }
    }
    _previousSynergyIds
      ..clear()
      ..addAll(currentIds);

    // Track synergy discovery
    if (active.isNotEmpty) {
      onSynergyDiscovered?.call();
    }
  }

  void _applyingSupportBuffs() {
    for (final support in _towers) {
      if (support.type != TowerType.support) continue;
      // Support tower buffs adjacent (8-directional) towers
      // +8% damage per support tier, +3% range per tier (nerfed)
      final dmgBonus = 1.0 + 0.08 * support.tier;
      final rangeBonus = 1.0 + 0.03 * support.tier;

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
    // Cap support multipliers to prevent excessive stacking
    for (final tower in _towers) {
      tower.supportDamageMultiplier = tower.supportDamageMultiplier.clamp(0.0, 2.0);
      tower.supportRangeMultiplier = tower.supportRangeMultiplier.clamp(0.0, 2.0);
    }
  }

  // --- Wave Control ---

  void startNextWave() {
    if (_phase != GamePhase.prep && _phase != GamePhase.waveBreak) return;

    // Remove incoming warning if active
    _waveWarning?.removeFromParent();
    _waveWarning = null;

    waveSystem.startNextWave();
    _pendingSpawns = List.from(waveSystem.currentComposition);
    _spawnIndex = 0;
    _spawnTimer = 0;
    _currentSpawnDelay = _pendingSpawns.isNotEmpty ? _pendingSpawns[0].spawnDelay : 0.8;
    _waveEnemyTotal = _pendingSpawns.fold(0, (sum, e) => sum + e.count);
    _damageTakenThisWave = false;
    _waveActiveTimer = 0;
    // Select path pattern for this wave
    final pathRng = math.Random(mapSeed + waveSystem.currentWave);
    _wavePathPattern = WavePathSelector.selectPattern(
      waveSystem.currentWave, gameMap.enemyPaths.length, pathRng,
    );
    _focusedPathIndex = pathRng.nextInt(gameMap.enemyPaths.length.clamp(1, 99));
    _waveSpawnCounter = 0;
    _phase = GamePhase.waveActive;
    AudioSystem.instance.play(GameSound.waveStart);

    // ═══ Wave Modifier: roll challenge for this wave ═══
    _activeWaveModifier = WaveModifierSystem.roll(waveSystem.currentWave, mapSeed);
    if (_activeWaveModifier != WaveModifier.none) {
      world.add(FloatingText(
        text: _activeWaveModifier.description,
        pos: Vector2(_gameWidth / 2, _gameHeight * 0.3),
        color: const Color(0xFFFF6600),
        fontSize: 12,
      ));
    }

    // ═══ Enemy Adaptation: compute dominant tower type ═══
    _updateDominantTowerType();
    _classifyBuild();

    // Wave start banner
    final hasBoss = _pendingSpawns.any((e) =>
        e.type == EnemyType.shadowLord || e.type == EnemyType.dragonEmperor);
    if (hasBoss) {
      debugPrint('WAVE_START boss wave ${waveSystem.currentWave}: '
          'enemies=${_enemies.length} towers=${_towers.length} '
          'texts=${FloatingText.totalActive} effects=${HitEffect.totalActive} '
          'audio=${AudioSystem.instance.activePlayerCount}/${AudioSystem.instance.poolSize} '
          'firstSpawnDelay=${_currentSpawnDelay}');
    }
    world.add(WaveBanner(
      waveNumber: waveSystem.currentWave,
      worldSize: Vector2(_gameWidth, _gameHeight),
      isBossWave: hasBoss,
    ));
    _atmosphere.triggerEventPulse(0.8);

    // ═══ Boss Info Card: show boss abilities before fight ═══
    if (hasBoss) {
      final hasShadow = _pendingSpawns.any((e) => e.type == EnemyType.shadowLord);
      final hasDragon = _pendingSpawns.any((e) => e.type == EnemyType.dragonEmperor);
      if (hasShadow) {
        world.add(FloatingText(
          text: 'SHADOW LORD',
          pos: Vector2(_gameWidth / 2, _gameHeight * 0.25),
          color: const Color(0xFFAA00FF),
          fontSize: 13,
        ));
        world.add(FloatingText(
          text: 'Yakındaki kuleleri zayıflatır | Işınlanır ve iyileşir',
          pos: Vector2(_gameWidth / 2, _gameHeight * 0.25 + 18),
          color: const Color(0xAACC88FF),
          fontSize: 9,
        ));
      }
      if (hasDragon) {
        world.add(FloatingText(
          text: 'DRAGON EMPEROR',
          pos: Vector2(_gameWidth / 2, _gameHeight * 0.25 + (hasShadow ? 40 : 0)),
          color: const Color(0xFFFF4400),
          fontSize: 13,
        ));
        world.add(FloatingText(
          text: 'Nefes saldırısı kaleye vurur | %50 HP altında öfkelenir',
          pos: Vector2(_gameWidth / 2, _gameHeight * 0.25 + (hasShadow ? 58 : 18)),
          color: const Color(0xAAFFAA88),
          fontSize: 9,
        ));
      }
    }

    if (waveSystem.currentWave == 1) tutorialSystem.tryShow(TutorialTrigger.firstWaveStart);

    // ═══ Wave 2 Choice Impact Reinforcement (System 3) ═══
    if (_wave2Choice != null && !hasBoss) {
      final w = waveSystem.currentWave;
      if (w == 3 && _wave2Choice == TowerType.fire) {
        _showContextHint('Ateş kulesi zamanla yakar — gruplar için ideal!');
      } else if (w == 3 && _wave2Choice == TowerType.spikeWall) {
        _showContextHint('Diken Duvarı geçen düşmana hasar verir — dar geçitlerde güçlü!');
      } else if (w == 4) {
        final unchosen = _wave2Options.firstWhere((t) => t != _wave2Choice);
        final name = TowerData.getStats(unchosen).name;
        _showContextHint('$name artık kullanılabilir!');
      }
    }

    // ═══ Choice Consequence Hints (System 4) ═══
    if (!hasBoss && waveSystem.currentWave >= 3) {
      final hasSwarm = _pendingSpawns.any((e) => e.count >= 8);
      final hasArmored = _pendingSpawns.any((e) =>
          e.type == EnemyType.troll || e.type == EnemyType.darkKnight);
      final hasFast = _pendingSpawns.any((e) => e.type == EnemyType.cavalry);
      if (hasSwarm && _currentBuildLabel == 'Yıkım Yapısı') {
        _showContextHint('Kalabalık dalga! Yıkım yapısı tek hedefe odaklı — AoE düşün.');
      } else if (hasArmored && _currentBuildLabel == 'Kontrol Yapısı') {
        _showContextHint('Zırhlı düşmanlar! Kontrol yavaşlatır ama hasar kuleleri lazım.');
      } else if (hasFast && _towers.every((t) => t.type != TowerType.ice && t.type != TowerType.spikeWall)) {
        _showContextHint('Süvari dalgası! Buz veya Diken yavaşlatmada etkili.');
      }
    }

    onStateChanged?.call();
  }

  /// Show a brief contextual hint as floating text (non-intrusive).
  void _showContextHint(String text) {
    world.add(FloatingText(
      text: text,
      pos: Vector2(_gameWidth / 2, _gameHeight * 0.15),
      color: const Color(0xAADDCCAA),
      fontSize: 9,
    ));
  }

  static const int _baseMaxEnemies = 60;
  static const int _baseMaxProjectiles = 80;
  // Dynamic caps that reduce in late waves for performance
  int get _maxActiveEnemies {
    final wave = waveSystem.currentWave;
    if (wave >= 60) return 35;
    if (wave >= 40) return 45;
    return _baseMaxEnemies;
  }
  int get _maxActiveProjectiles {
    final wave = waveSystem.currentWave;
    if (wave >= 60) return 50;
    if (wave >= 40) return 65;
    return _baseMaxProjectiles;
  }

  // Per-frame creation caps (avoid O(n) whereType scans)
  int _effectsThisFrame = 0;
  int _textsThisFrame = 0;
  int get _maxEffectsPerFrame => waveSystem.currentWave >= 40 ? 2 : 4;
  int get _maxTextsPerFrame => waveSystem.currentWave >= 40 ? 1 : 3;
  // Tighter caps during boss combat (sustained focus-fire = heavy object churn)
  static const int _maxEffectsPerFrameBoss = 2;
  static const int _maxTextsPerFrameBoss = 1;

  // ═══ Boss Damage Batching ═══
  // Accumulates all tower hits against a boss in one frame, then flushes once.
  // Eliminates N×takeDamage, N×applyEffect, N×comboCheck, N×audio per frame.
  int _bossBatchDamage = 0;
  int _bossBatchHits = 0;
  Enemy? _bossBatchTarget;
  final List<Tower> _bossBatchTowers = [];
  final List<int> _bossBatchDmgPerTower = [];
  final Set<TowerType> _bossBatchTowerTypes = {};
  bool _bossBatchHadSynergyFreeze = false;
  bool _bossBatchHadCannon = false;

  // ═══ Boss Batch Debug Stats (visible in debug overlay) ═══
  int debugBossHitsThisFrame = 0;
  int debugBossDamageFlushed = 0;
  int debugBossEffectsMerged = 0;
  bool debugBossBatchActive = false;

  void _spawnEnemy(EnemyType type) {
    if (gameMap.enemyPaths.isEmpty) return; // safety
    // Cap active enemies to prevent mobile performance collapse
    if (_enemies.length >= _maxActiveEnemies) return;

    final isBossType = type == EnemyType.shadowLord || type == EnemyType.dragonEmperor;
    final Stopwatch? sw = isBossType ? (Stopwatch()..start()) : null;

    // Pick path based on wave pattern
    final paths = gameMap.enemyPaths;
    final pathIdx = WavePathSelector.pickPath(
      _wavePathPattern, _waveSpawnCounter, paths.length, _focusedPathIndex,
    );
    _waveSpawnCounter++;
    final path = paths[pathIdx];
    final enemy = EnemyFactory.create(
      type: type,
      path: path,
      cellSize: cellSize,
      difficulty: difficulty,
    );
    if (sw != null) debugPrint('BOSS_SPAWN create: ${sw.elapsedMicroseconds}µs');

    // Wave-based HP scaling: +12% per wave (normal), +6% (boss)
    // Plus infinite-mode scaling that ramps every 5 waves
    final wave = waveSystem.currentWave;
    if (enemy.baseStats.isBoss) {
      final bossHpScale = (1.0 + (wave - 1) * 0.06) * _endlessScaling;
      enemy.scaleHp(bossHpScale);
    } else {
      final waveHpScale = (1.0 + (wave - 1) * 0.12) * _endlessScaling;
      enemy.scaleHp(waveHpScale);
    }
    // Roguelike buff: enemy speed reduction
    if (runBuffs.enemySpeedMultiplier < 1.0) {
      final slowFactor = 1.0 - runBuffs.enemySpeedMultiplier;
      enemy.applyEffect(StatusEffect.slow(factor: slowFactor, duration: 999999.0));
    }
    // Mutation: fast enemies
    if (mutations.contains(MutationType.fastEnemies)) {
      enemy.applyEffect(StatusEffect.slow(factor: -0.3, duration: 999999.0)); // negative = speed boost
    }
    // Mutation: armored all
    final bonusArmor = MutationSystem.bonusArmor(mutations);
    if (bonusArmor > 0) {
      enemy.addBonusArmor(bonusArmor);
    }
    // ═══ Wave Modifier effects on spawn ═══
    switch (_activeWaveModifier) {
      case WaveModifier.armoredSurge:
        enemy.addBonusArmor(8);
      case WaveModifier.speedRush:
        enemy.applyEffect(StatusEffect.slow(factor: -0.4, duration: 999999.0));
      case WaveModifier.iceImmune:
        // Handled in combat: slow effects ignored
        break;
      default:
        break;
    }
    // ═══ Enemy Adaptation: bonus armor vs dominant tower type ═══
    if (_dominantTowerType != null && !enemy.baseStats.isBoss) {
      enemy.adaptedAgainst = _dominantTowerType;
    }
    // Artifact: Gölge Pelerin (id 5) - First wave enemies 50% slow
    if (hasArtifact(5) && waveSystem.currentWave == 1) {
      enemy.applyEffect(StatusEffect.slow(factor: 0.5, duration: 999.0));
    }
    // Elite system: 15% chance for non-boss enemies
    if (EliteSystem.shouldBeElite(type, _eliteRng)) {
      enemy.isElite = true;
      enemy.eliteModifier = EliteSystem.rollModifier(_eliteRng);
      AudioSystem.instance.play(GameSound.eliteSpawn);
      tutorialSystem.tryShow(TutorialTrigger.eliteAppeared);
      switch (enemy.eliteModifier!) {
        case EliteModifier.fast:
          enemy.applyEffect(StatusEffect.slow(factor: -0.5, duration: 999999.0));
          break;
        case EliteModifier.armored:
          enemy.addBonusArmor(10);
          break;
        case EliteModifier.regenerating:
          break; // handled in update loop
        case EliteModifier.splitting:
          break; // handled in _processEnemies
      }
    }
    if (sw != null) debugPrint('BOSS_SPAWN setup: ${sw.elapsedMicroseconds}µs');

    _enemies.add(enemy);
    world.add(enemy);
    if (sw != null) debugPrint('BOSS_SPAWN world.add: ${sw.elapsedMicroseconds}µs');

    tutorialSystem.tryShowEnemyWeakness(enemy.type);
    // Boss spawn: staged across multiple frames to prevent single-frame spike
    if (enemy.baseStats.isBoss) {
      _hasBossAlive = true;
      _activeBosses.add(enemy);
      // STAGE 1 (this frame): entity created and added to world — nothing else
      // Effects, audio, and abilities deferred to next frames via _processBossSpawnStaging
      _pendingBossSpawn = enemy;
      _bossSpawnStage = 1;
      enemy.abilitiesDisabled = true; // disable until stage 3
      debugPrint('BOSS_SPAWN stage1 TOTAL: ${sw!.elapsedMicroseconds}µs '
          'type=${enemy.type.name} enemies=${_enemies.length} '
          'towers=${_towers.length} proj=${_projectiles.length} '
          'texts=${FloatingText.totalActive} effects=${HitEffect.totalActive} '
          'sprite_cached=${EnemySpriteGenerator.instance.getWalkSheet(type) != null}');
    }
  }

  /// Staged boss spawn: spread intro effects across 3 frames to prevent spike.
  void _processBossSpawnStaging() {
    if (_pendingBossSpawn == null) return;
    final boss = _pendingBossSpawn!;
    if (boss.isDead) {
      _pendingBossSpawn = null;
      _bossSpawnStage = 0;
      return;
    }

    _bossSpawnStage++;
    switch (_bossSpawnStage) {
      case 2:
        // STAGE 2: visual effects (hitStop + screenShake + atmosphere)
        triggerHitStop(0.03);
        screenShake.shake(duration: 0.25, intensity: 3.0);
        _atmosphere.triggerEventPulse(0.8);
        debugPrint('BOSS_SPAWN stage2: visual effects applied');
        break;
      case 3:
        // STAGE 3: audio + enable abilities
        AudioSystem.instance.play(GameSound.bossRoar);
        boss.abilitiesDisabled = false;
        _pendingBossSpawn = null;
        _bossSpawnStage = 0;
        debugPrint('BOSS_SPAWN stage3: audio+abilities enabled, spawn complete');
        break;
    }
  }

  // --- Game Loop ---

  // Frame spike detection (boss combat debugging)
  int _spikeLogCooldown = 0; // throttle: max 1 log per 60 frames

  @override
  void update(double dt) {
    super.update(dt);

    if (!_isReady) return;
    if (_phase == GamePhase.paused || _phase == GamePhase.gameOver) return;

    // Frame spike detection: log when frame > 33ms (< 30 FPS) during boss combat
    if (_hasBossAlive && _spikeLogCooldown <= 0 && dt > 0.033) {
      _spikeLogCooldown = 60; // suppress for 60 frames
      debugPrint('SPIKE: ${(dt * 1000).toStringAsFixed(1)}ms '
          'enemies:${_enemies.length} proj:${_projectiles.length} '
          'towers:${_towers.length} texts:${FloatingText.totalActive} '
          'effects:${HitEffect.totalActive} '
          'audio:${AudioSystem.instance.activePlayerCount}/${AudioSystem.instance.poolSize}');
    }
    if (_spikeLogCooldown > 0) _spikeLogCooldown--;

    // Reset per-frame creation counters
    _effectsThisFrame = 0;
    _textsThisFrame = 0;

    // Hit-stop micro freeze: tick with raw dt so feel is consistent across speeds
    if (_hitStopTimer > 0) {
      _hitStopTimer -= dt;
      if (_hitStopTimer < 0) _hitStopTimer = 0;
    }

    dt *= _gameSpeed;

    // Scale game dt to near-zero during active hit-stop
    if (_hitStopTimer > 0) {
      dt *= _hitStopTimeScale;
    }

    if (_phase == GamePhase.waveBreak) {
      if (showEndlessPrompt) return; // never true in infinite mode
      final oldSec = _breakTimer.ceil();
      final oldBreak = _breakTimer;
      _breakTimer -= dt;
      // Spawn incoming wave warning when timer crosses below 3s
      if (oldBreak > 3.0 && _breakTimer <= 3.0 && _waveWarning == null) {
        _waveWarning = WaveIncomingWarning(
          waveNumber: waveSystem.currentWave + 1,
          worldSize: Vector2(_gameWidth, _gameHeight),
        );
        world.add(_waveWarning!);
      }
      if (_breakTimer <= 0) {
        // Handle ambush event before starting next wave
        if (_currentEvent?.type == WaveEventType.ambush) {
          _currentEvent = null;
          final ambushRng = math.Random(mapSeed + waveSystem.currentWave * 7);
          final ambushCount = 3 + ambushRng.nextInt(4); // 3-6
          final types = [EnemyType.soldier, EnemyType.cavalry, EnemyType.goblin];
          for (int i = 0; i < ambushCount; i++) {
            _spawnEnemy(types[ambushRng.nextInt(types.length)]);
          }
        }
        startNextWave();
      } else if (_breakTimer.ceil() != oldSec) {
        onStateChanged?.call();
      }
      return;
    }

    if (_phase != GamePhase.waveActive) return;

    // Process staged boss spawn (one stage per frame)
    _processBossSpawnStaging();

    // Rebuild spatial grid once per frame (all range queries use this)
    _spatialGrid.rebuild(_enemies);

    // Spawn enemies
    _updateSpawning(dt);

    // Tower targeting & firing
    _updateTowerCombat(dt);

    // Healer enemy mechanic
    _updateHealerEnemies(dt);

    // Troll regeneration: 1.5 HP/sec, capped at 60% maxHP
    // Elite regenerating: 2 HP/sec
    // Wave modifier regenWave: ALL enemies regen 1 HP/sec
    for (final enemy in _enemies) {
      if (enemy.isDead || enemy.reachedCastle) continue;
      if (enemy.type == EnemyType.troll && enemy.hp < (enemy.maxHp * 0.6).round()) {
        enemy.heal((1.5 * dt).ceil());
      }
      if (enemy.isElite && enemy.eliteModifier == EliteModifier.regenerating && enemy.hp < enemy.maxHp) {
        enemy.heal((2 * dt).ceil());
      }
      if (_activeWaveModifier == WaveModifier.regenWave && enemy.hp < enemy.maxHp) {
        enemy.heal((1 * dt).ceil());
      }
    }

    // Boss special abilities
    if (!debugDisableBossAbilities) _updateBossAbilities(dt);

    // Combo system tick
    comboSystem.update(dt);

    // Spell cooldowns
    spellSystem.update(dt);
    tutorialSystem.update(dt);

    // Contextual tutorial checks
    if (_phase == GamePhase.waveActive && castle.hp < castle.maxHp * 0.3) {
      tutorialSystem.tryShow(TutorialTrigger.lowHp);
    }
    if (spellSystem.availableSpells(waveSystem.currentWave).isNotEmpty) {
      tutorialSystem.tryShow(TutorialTrigger.spellUnlocked);
    }
    if (_towers.any((t) => t.needsT4Choice)) {
      tutorialSystem.tryShow(TutorialTrigger.t4Available);
    }

    // DarkKnight aura: nearby allies get +5 armor (throttled)
    _updateDarkKnightAura(dt);

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

    // Safety: force-kill stuck enemies after 60 seconds of wave active
    _waveActiveTimer += dt;
    if (_pendingSpawns.isEmpty && _enemies.isNotEmpty && _waveActiveTimer > 60) {
      for (final enemy in _enemies) {
        if (!enemy.isDead && !enemy.reachedCastle) {
          enemy.takeDamage(enemy.hp + 1, bypassArmor: true);
        }
      }
    }

    // Update debug overlay counters
    _debugOverlay.enemyCount = _cachedEnemiesAlive;
    _debugOverlay.projectileCount = _projectiles.length;
    _debugOverlay.towerCount = _towers.length;
    _debugOverlay.bossHits = debugBossHitsThisFrame;
    _debugOverlay.bossDamage = debugBossDamageFlushed;
    _debugOverlay.bossEffects = debugBossEffectsMerged;
    _debugOverlay.bossBatchActive = debugBossBatchActive;

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

    // Tower ambient presence tick
    if (_towers.isNotEmpty) {
      _towerAmbientTimer += dt;
      if (_towerAmbientTimer >= _towerAmbientInterval) {
        _towerAmbientTimer = 0;
        final tower = _towers[_damageTextRng.nextInt(_towers.length)];
        AudioSystem.instance.play(_towerAmbientSound(tower.type));
      }
    }

    // Danger vignette + atmosphere track castle health & boss presence
    final currentHpRatio = castle.maxHp > 0 ? castle.hp / castle.maxHp : 1.0;
    _dangerVignette.hpRatio = currentHpRatio;
    _atmosphere.hpRatio = currentHpRatio;
    _atmosphere.isBossWave = _hasBossAlive;
    // Sync debug flag to enemy renderer
    Enemy.debugSkipBossAura = debugDisableBossAura;

    // Screen shake (preserve horizontal centering offset)
    camera.viewfinder.position = Vector2(_cameraBaseX, 0) + screenShake.offset;

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
        AudioSystem.instance.play(GameSound.defeat);
        onGameOver?.call(false);
      }
    }
  }

  // --- Boss Special Abilities ---
  void _updateBossAbilities(double dt) {
    if (_activeBosses.isEmpty) return;
    for (final enemy in _activeBosses) {
      if (enemy.isDead || enemy.reachedCastle) continue;
      // EMP T4: re-enable abilities when slow effect expires
      if (enemy.abilitiesDisabled && !enemy.hasSlowEffect) {
        enemy.abilitiesDisabled = false;
      }
      if (enemy.abilitiesDisabled) continue;

      enemy.bossAbilityTimer += dt;

      // Enraged dragon fires abilities faster (3s instead of 5s)
      final abilityCooldown = (enemy.isEnraged && enemy.type == EnemyType.dragonEmperor) ? 3.0 : 5.0;
      final telegraphStart = abilityCooldown - 1.2;

      // Telegraph warning 1.2s before ability fires
      if (enemy.bossAbilityTimer >= telegraphStart && enemy.bossAbilityTimer < abilityCooldown) {
        _renderBossTelegraph(enemy, dt, telegraphStart);
      }

      if (enemy.bossAbilityTimer < abilityCooldown) continue;
      enemy.bossAbilityTimer = 0;

      // Release frame: clear telegraph, add impact cues
      enemy.telegraphTimer = 0;
      enemy.telegraphProgress = 0;
      enemy.attackReleaseTimer = 0.4;
      triggerHitStop(0.04);
      screenShake.shake(duration: 0.2, intensity: 4.0);
      _atmosphere.triggerEventPulse(0.6);

      if (enemy.type == EnemyType.shadowLord) {
        _shadowLordAbility(enemy);
      } else if (enemy.type == EnemyType.dragonEmperor) {
        _dragonEmperorAbility(enemy);
      }
    }
  }

  void _renderBossTelegraph(Enemy boss, double dt, double telegraphStart) {
    final color = boss.type == EnemyType.dragonEmperor
        ? const Color(0xFFFF4400) : const Color(0xFFAA00FF);
    // Set visual telegraph on enemy with escalating progress
    boss.telegraphColor = color;
    boss.telegraphTimer = 0.2; // refresh each frame during window
    boss.telegraphProgress = ((boss.bossAbilityTimer - telegraphStart) / 1.2).clamp(0.0, 1.0);

    // Only fire text + shake + atmosphere accent once when timer first crosses telegraphStart
    if (boss.bossAbilityTimer - dt < telegraphStart) {
      final warning = boss.type == EnemyType.dragonEmperor
          ? 'NEFES HAZIRLANIYOR!' : 'IŞINLANMA HAZIRLANIYOR!';
      world.add(FloatingText(
        text: warning,
        pos: boss.position + Vector2(0, -30),
        color: color,
        fontSize: 11,
      ));
      screenShake.shake(duration: 0.15, intensity: 2.0);
      _atmosphere.triggerEventPulse(0.5);
    }
  }

  final Map<int, int> _bossSpawnCount = {}; // enemyId -> times spawned

  void _shadowLordAbility(Enemy shadowLord) {
    // Teleport: advance on path + spawn minions + heal
    final spawnCount = _bossSpawnCount[shadowLord.enemyId] ?? 0;
    final remaining = shadowLord.remainingPath;
    if (remaining.length > 4 && spawnCount < 3 && _enemies.length < _maxActiveEnemies) {
      _bossSpawnCount[shadowLord.enemyId] = spawnCount + 1;
      // Spawn shield bearers on 2nd+ use, soldiers first time
      final spawnType = spawnCount >= 1 ? EnemyType.shieldBearer : EnemyType.soldier;
      for (int i = 0; i < 2; i++) {
        final minionPath = shadowLord.remainingPath;
        if (minionPath.length > 1) {
          final minion = EnemyFactory.create(
            type: spawnType,
            path: minionPath,
            cellSize: cellSize,
            difficulty: difficulty,
          );
          _enemies.add(minion);
          world.add(minion);
        }
      }
    }
    // Heal 10% of max HP on teleport
    final healAmount = (shadowLord.maxHp * 0.10).round();
    shadowLord.heal(healAmount);
    // Visual effect
    _addEffect(HitEffect(pos: shadowLord.position, color: const Color(0xFF8800AA), count: 8, speed: 50));
    world.add(FloatingText(
      text: 'IŞINLANMA! +$healAmount HP',
      pos: shadowLord.position + Vector2(0, -20),
      color: const Color(0xFFAA00FF),
      fontSize: 11,
    ));
  }

  /// ShadowLord passive: towers within 3 cells deal 25% less damage.
  bool isShadowLordAuraActive(Vector2 towerPos) {
    for (final enemy in _activeBosses) {
      if (enemy.isDead || enemy.reachedCastle || enemy.type != EnemyType.shadowLord) continue;
      final dist = (enemy.position - towerPos).length;
      if (dist <= cellSize * 3) return true;
    }
    return false;
  }

  void _dragonEmperorAbility(Enemy dragon) {
    // Breath attack: disable towers in a 4-cell line toward castle
    final castleCenter = castle.position + castle.size / 2;
    final dragonPos = dragon.position;
    final direction = (castleCenter - dragonPos).normalized();

    int disabledCount = 0;
    for (final tower in _towers) {
      if (tower.type == TowerType.spikeWall) continue;
      final towerCenter = tower.position + tower.size / 2;
      final toTower = towerCenter - dragonPos;
      final projDist = toTower.dot(direction);
      if (projDist < 0 || projDist > cellSize * 4) continue;
      final perpDist = (toTower - direction * projDist).length;
      if (perpDist <= cellSize * 2) {
        tower.disableTimer = 3.0;
        _addEffect(HitEffect.fire(pos: towerCenter));
        disabledCount++;
      }
    }
    // Direct castle damage: breath scorches the castle for 3 HP
    castle.takeDamage(3);
    _damageTakenThisWave = true;
    screenShake.shake(duration: 0.3, intensity: 5.0);

    world.add(FloatingText(
      text: 'NEFES SALDIRISI! -3 HP',
      pos: dragonPos + Vector2(0, -25),
      color: const Color(0xFFFF4400),
      fontSize: 12,
    ));

    // Enrage: when below 50% HP, speed up and abilities fire faster
    if (!dragon.isEnraged && dragon.hp < dragon.maxHp * 0.5) {
      dragon.isEnraged = true;
      dragon.applyEffect(StatusEffect.slow(factor: -0.5, duration: 999999.0)); // negative = speed boost
      world.add(FloatingText(
        text: 'ÖFKE MODU!',
        pos: dragonPos + Vector2(0, -40),
        color: const Color(0xFFFF0000),
        fontSize: 14,
        isCritical: true,
      ));
    }
  }

  // --- Castle Spells ---
  void castSpell(SpellType spell) {
    if (!canCastSpell(spell)) return;
    spellSystem.cast(spell);

    // Audio per spell type
    switch (spell) {
      case SpellType.fireRain: AudioSystem.instance.play(GameSound.spellFireRain); break;
      case SpellType.iceStorm: AudioSystem.instance.play(GameSound.spellIceStorm); break;
      case SpellType.castleRepair: AudioSystem.instance.play(GameSound.spellRepair); break;
    }

    // Visual overlay effect
    final overlayInfo = switch (spell) {
      SpellType.fireRain => ('assets/images/effects/fire_rain.webp', const Color(0xFFFF5511)),
      SpellType.iceStorm => ('assets/images/effects/ice_storm.webp', const Color(0xFF22CCEE)),
      SpellType.castleRepair => ('assets/images/effects/castle_repair.webp', const Color(0xFF00CC44)),
    };
    world.add(SpellOverlay(
      assetPath: overlayInfo.$1,
      tintColor: overlayInfo.$2,
      worldSize: Vector2(GameConfig.gridColumns * fixedCellSize, GameConfig.gridRows * fixedCellSize),
    ));

    switch (spell) {
      case SpellType.fireRain:
        final dmg = 15 + waveSystem.currentWave * 3;
        int fireEffects = 0;
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
          enemy.takeDamage(dmg, bypassArmor: true);
          enemy.applyEffect(StatusEffect.burn(dps: 5, duration: 3.0));
          if (fireEffects < 10) {
            _addEffect(HitEffect.fire(pos: enemy.position));
            fireEffects++;
          }
        }
        world.add(FloatingText(
          text: 'ATEŞ YAĞMURU!',
          pos: castle.position + Vector2(0, -30),
          color: const Color(0xFFFF4400),
          fontSize: 14,
        ));
        break;
      case SpellType.iceStorm:
        int iceEffects = 0;
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle) continue;
          enemy.applyEffect(StatusEffect.slow(factor: 0.7, duration: 3.0));
          if (iceEffects < 10) {
            _addEffect(HitEffect.ice(pos: enemy.position));
            iceEffects++;
          }
        }
        world.add(FloatingText(
          text: 'BUZ FIRTINASI!',
          pos: castle.position + Vector2(0, -30),
          color: const Color(0xFF22CCEE),
          fontSize: 14,
        ));
        break;
      case SpellType.castleRepair:
        castle.heal((castle.maxHp * 0.10).round());
        world.add(FloatingText(
          text: '+%10 HP',
          pos: castle.position + Vector2(0, -30),
          color: const Color(0xFF00FF44),
          fontSize: 14,
        ));
        break;
    }
    onStateChanged?.call();
  }

  // --- T4 Branch Selection ---
  void requestT4Upgrade(Tower tower) {
    _pendingT4Tower = tower;
    onStateChanged?.call();
  }

  void selectT4Branch(T4BranchPath path) {
    if (_pendingT4Tower == null) return;
    final cost = (_metaUpgradeCostReduction > 0)
        ? (_pendingT4Tower!.upgradeCost * (1.0 - _metaUpgradeCostReduction)).round()
        : _pendingT4Tower!.upgradeCost;
    if (!economy.trySpend(cost)) return;
    final t4Tower = _pendingT4Tower!;
    t4Tower.upgradeToT4(path, cost);
    final branchColor = path == T4BranchPath.pathA
        ? const Color(0xFFFFCC50)
        : const Color(0xFF78B4FF);
    t4Tower.triggerMergeEffect(color: branchColor);
    world.add(FloatingText(
      text: t4Tower.t4Name,
      pos: Vector2(t4Tower.col * cellSize + cellSize / 2, t4Tower.row * cellSize - 8),
      color: branchColor,
      fontSize: 13,
    ));
    _pendingT4Tower = null;
    _recalculateSynergies();
    AudioSystem.instance.play(GameSound.t4Upgrade);
    onStateChanged?.call();
  }

  void cancelT4Selection() {
    _pendingT4Tower = null;
    onStateChanged?.call();
  }

  // --- Wave Events ---
  void acceptMerchantEvent() {
    if (!_merchantAvailable) return;
    if (!economy.trySpend(50)) return;
    _merchantAvailable = false;
    // Grant a random artifact-like bonus
    final bonusType = _damageTextRng.nextInt(3);
    switch (bonusType) {
      case 0: // Damage boost all towers
        for (final tower in _towers) {
          tower.artifactDamageMultiplier *= 1.1;
        }
        world.add(FloatingText(text: 'Tüm kulelere +%10 hasar!', pos: castle.position + Vector2(0, -30), color: const Color(0xFFFFD700), fontSize: 12));
        break;
      case 1: // Gold bonus
        economy.earnGold(100);
        world.add(FloatingText(text: '+100 Altın!', pos: castle.position + Vector2(0, -30), color: const Color(0xFFFFD700), fontSize: 12));
        break;
      case 2: // Heal castle
        castle.heal((castle.maxHp * 0.25).round());
        world.add(FloatingText(text: 'Kale iyileştirildi!', pos: castle.position + Vector2(0, -30), color: const Color(0xFF00FF44), fontSize: 12));
        break;
    }
    onStateChanged?.call();
  }

  void dismissEvent() {
    _currentEvent = null;
    _merchantAvailable = false;
    onStateChanged?.call();
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
    if (_hasBossAlive && debugDisableTowerFire) return; // debug: skip ALL tower combat

    // Reset boss damage batch for this frame
    _bossBatchDamage = 0;
    _bossBatchHits = 0;
    _bossBatchTarget = null;
    _bossBatchTowers.clear();
    _bossBatchDmgPerTower.clear();
    _bossBatchTowerTypes.clear();
    _bossBatchHadSynergyFreeze = false;

    // Reset debug stats for this frame
    debugBossHitsThisFrame = 0;
    debugBossDamageFlushed = 0;
    debugBossEffectsMerged = 0;
    debugBossBatchActive = false;
    _bossBatchHadCannon = false;

    // ═══ ShadowLord Aura Visual: update tower debuff flag ═══
    for (final tower in _towers) {
      tower.shadowAuraAffected = isShadowLordAuraActive(tower.position + tower.size / 2);
    }

    for (final tower in _towers) {
      // Spike walls deal contact damage to enemies on same cell
      if (tower.type == TowerType.spikeWall) {
        _updateSpikeWallDamage(tower, dt);
        continue;
      }

      if (!tower.canFire()) continue;

      // Target caching: only re-scan when needed (every 200ms or target invalid)
      Enemy? target;
      if (tower.needsRetarget(dt)) {
        // Use spatial grid for range query instead of full enemy list scan
        final tcx = tower.position.x + tower.size.x / 2;
        final tcy = tower.position.y + tower.size.y / 2;
        final rangePx = tower.currentRange * tower.cellSize;
        final candidates = _spatialGrid.queryRange(tcx, tcy, rangePx);

        double bestScore = double.infinity;
        for (int i = 0; i < candidates.length; i++) {
          final enemy = candidates[i];
          double score;
          switch (tower.targetingMode) {
            case TargetingMode.nearest:
              final dx = tcx - enemy.position.x;
              final dy = tcy - enemy.position.y;
              score = dx * dx + dy * dy;
            case TargetingMode.first:
              score = enemy.remainingPathLength.toDouble();
            case TargetingMode.strongest:
              score = -enemy.hp.toDouble();
          }
          if (score < bestScore) {
            bestScore = score;
            target = enemy;
          }
        }
        tower.setCachedTarget(target);
      } else {
        target = tower.cachedTarget;
      }

      if (target != null) {
        final proj = tower.tryFire(target.position);
        if (proj != null) {
          if (_projectiles.length < _maxActiveProjectiles) {
            _projectiles.add(proj);
            world.add(proj);
          }
          AudioSystem.instance.play(GameSound.towerFire);
          // Screen shake for heavy towers
          final atkProfile = tower.attackProfile;
          if (atkProfile.shakeIntensity > 0) {
            screenShake.shake(
              duration: atkProfile.shakeDuration,
              intensity: atkProfile.shakeIntensity,
            );
          }

          if (target.baseStats.isBoss) {
            // ═══ BATCHED: accumulate boss damage, defer all processing ═══
            _bossBatchAccumulate(tower, target);
          } else {
            // ═══ DIRECT: per-hit processing for normal enemies ═══
            _applyTowerDamage(tower, target);
          }

          // Cannon AoE splash still targets OTHER enemies individually
          if (tower.type == TowerType.cannon) {
            _applyCannonSplash(tower, target);
          }
          // Wizard chain still targets OTHER enemies individually
          if (tower.type == TowerType.wizard) {
            _applyWizardChain(tower, target);
          }
          // Lightning T4 Path A (Tanrı Öfkesi): chain to 4 nearby enemies
          if (tower.type == TowerType.lightning && tower.t4Branch == T4BranchPath.pathA) {
            _applyLightningChain(tower, target);
          }
        }
      }
    }

    // ═══ Flush boss batch: 1 damage call, 1 visual, 1 audio, 1 combo check ═══
    if (_bossBatchTarget != null && _bossBatchHits > 0) {
      _bossBatchFlush();
    }

    // Clean up projectiles using tracked list (O(n) on tracked list, not all children)
    _projectiles.removeWhere((p) {
      if (p.isDone ||
          p.position.x < -200 || p.position.x > _gameWidth + 200 ||
          p.position.y < -200 || p.position.y > _gameHeight + 200) {
        p.removeFromParent();
        return true;
      }
      return false;
    });
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

    final cx = spikeWall.position.x + spikeWall.size.x / 2;
    final cy = spikeWall.position.y + spikeWall.size.y / 2;
    final contactRange = cellSize * 0.8;
    // Use spatial grid for contact range query
    final nearby = _spatialGrid.queryRange(cx, cy, contactRange);
    for (int i = 0; i < nearby.length; i++) {
      nearby[i].takeDamage(spikeWall.currentDamage);
    }
  }

  void _applyCannonSplash(Tower cannon, Enemy primaryTarget) {
    final splashRadius = cellSize * 1.5;
    final splashDamage = (cannon.currentDamage * 0.5).round();
    _addEffect(HitEffect.explosion(pos: primaryTarget.position, radius: splashRadius));
    // Use spatial grid instead of full enemy scan
    final nearby = _spatialGrid.queryRangeExcluding(
      primaryTarget.position.x, primaryTarget.position.y, splashRadius, primaryTarget,
    );
    for (int i = 0; i < nearby.length; i++) {
      nearby[i].takeDamage(splashDamage);
    }
  }

  // DarkKnight aura: gives adjacent enemies armor (throttled to every 0.5s)
  final Set<Enemy> _darkKnightBuffed = {};
  double _darkKnightAuraTimer = 0;

  void _updateDarkKnightAura(double dt) {
    _darkKnightAuraTimer += dt;
    if (_darkKnightAuraTimer < 0.5) return;
    _darkKnightAuraTimer = 0;

    final auraRange = cellSize * 2.0;
    for (final dk in _enemies) {
      if (dk.isDead || dk.reachedCastle || dk.type != EnemyType.darkKnight) continue;
      // Use spatial grid for nearby enemies
      final nearby = _spatialGrid.queryRange(dk.position.x, dk.position.y, auraRange);
      for (int i = 0; i < nearby.length; i++) {
        final other = nearby[i];
        if (other == dk) continue;
        if (_darkKnightBuffed.contains(other)) continue;
        other.addBonusArmor(5);
        _darkKnightBuffed.add(other);
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
        // Telegraph: warn 0.6s before dash
        if (timer >= 3.4) {
          enemy.telegraphColor = const Color(0xFFFF8800);
          enemy.telegraphTimer = 0.15;
        }
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

    // Denge Patlaması (id 6): AoE burst every 5 seconds around synergy anchor
    final dengePatlamasiSynergy = synergySystem.activeSynergies.where((s) => s.id == 6);
    if (dengePatlamasiSynergy.isNotEmpty) {
      _dengePatlamasiTimer += dt;
      if (_dengePatlamasiTimer >= 5.0) {
        _dengePatlamasiTimer = 0;
        final anchor = dengePatlamasiSynergy.first.anchorPosition;
        final burstCenter = Vector2((anchor.col + 0.5) * cellSize, (anchor.row + 0.5) * cellSize);
        final burstRange = cellSize * 3.5;
        final burstDmg = 20 + waveSystem.currentWave * 4;
        // Use spatial grid
        final nearby = _spatialGrid.queryRange(burstCenter.x, burstCenter.y, burstRange);
        int effectCount = 0;
        for (int i = 0; i < nearby.length; i++) {
          final enemy = nearby[i];
          enemy.takeDamage(burstDmg, bypassArmor: true);
          if (effectCount < 8) {
            _showDamageText(enemy.position, burstDmg);
            _addEffect(HitEffect.explosion(pos: enemy.position, radius: 15));
            effectCount++;
          }
        }
        _addEffect(HitEffect.explosion(pos: burstCenter, radius: 30));
      }
    } else {
      _dengePatlamasiTimer = 0;
    }

    // Kıyamet (id 10): massive AoE every 15 seconds
    final kiyametActive = synergySystem.activeSynergies.any((s) => s.id == 10);
    if (kiyametActive) {
      _kiyametTimer += dt;
      if (_kiyametTimer >= 15.0) {
        _kiyametTimer = 0;
        int effectCount = 0;
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
          final dmg = 25 + waveSystem.currentWave * 3;
          enemy.takeDamage(dmg, bypassArmor: true);
          // Limit visual effects to prevent frame drops
          if (effectCount < 8) {
            _showDamageText(enemy.position, dmg);
            _addEffect(HitEffect.explosion(pos: enemy.position, radius: 20));
            effectCount++;
          }
        }
      }
    }

    // Tanrıların Gazabı (id 11): continuous AoE every 8 seconds + burn all
    if (_ultimateSynergyActive) {
      _ultimateSynergyTimer += dt;
      if (_ultimateSynergyTimer >= 8.0) {
        _ultimateSynergyTimer = 0;
        int effectCount = 0;
        for (final enemy in _enemies) {
          if (enemy.isDead || enemy.reachedCastle || enemy.isBurrowed) continue;
          final dmg = 40 + waveSystem.currentWave * 5;
          enemy.takeDamage(dmg, bypassArmor: true);
          enemy.applyEffect(StatusEffect.burn(duration: 3.0, dps: 8 + waveSystem.currentWave));
          enemy.applyEffect(StatusEffect.curse(duration: 4.0, armorReduce: 10));
          if (effectCount < 8) {
            _showDamageText(enemy.position, dmg);
            _addEffect(HitEffect.explosion(pos: enemy.position, radius: 25));
            effectCount++;
          }
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

    final ccx = castle.position.x + castle.size.x / 2;
    final ccy = castle.position.y + castle.size.y / 2;
    final aoeRange = cellSize * 3.0;
    // Use spatial grid
    final nearby = _spatialGrid.queryRange(ccx, ccy, aoeRange);
    final dmg = 5 + waveSystem.currentWave;
    for (int i = 0; i < nearby.length; i++) {
      nearby[i].takeDamage(dmg, bypassArmor: true);
    }
  }

  void _updateChaosStone(double dt) {
    if (!hasArtifact(7)) return;
    _chaosStoneTimer += dt;
    if (_chaosStoneTimer < 20.0) return;
    _chaosStoneTimer = 0;

    if (_enemies.isEmpty) return;

    // Pick a random synergy effect to apply
    final effect = _damageTextRng.nextInt(4);
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
          _addEffect(HitEffect.explosion(pos: enemy.position, radius: 12));
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
    final dcx = castle.position.x + castle.size.x / 2;
    final dcy = castle.position.y + castle.size.y / 2;
    final dragonRange = cellSize * 8;
    // Use spatial grid
    final nearby = _spatialGrid.queryRange(dcx, dcy, dragonRange);
    final dmg = 10 + waveSystem.currentWave * 2;
    int dragonEffects = 0;
    for (int i = 0; i < nearby.length; i++) {
      final enemy = nearby[i];
      enemy.takeDamage(dmg, bypassArmor: true);
      enemy.applyEffect(StatusEffect.burn(dps: 5, duration: 3.0));
      if (dragonEffects < 6) {
        _addEffect(HitEffect.fire(pos: enemy.position));
        dragonEffects++;
      }
    }
  }

  void _applyLightningChain(Tower tower, Enemy primaryTarget) {
    // T4 Path A "Tanrı Öfkesi": chain to 4 nearby enemies
    final chainRange = cellSize * 2.5;
    final chainDamage = (tower.currentDamage * 0.6).round();
    int chains = 0;
    const maxChains = 4;
    const chainColor = Color(0xFFFFD700); // lightning gold

    final nearby = _spatialGrid.queryRangeExcluding(
      primaryTarget.position.x, primaryTarget.position.y, chainRange, primaryTarget,
    );
    for (int i = 0; i < nearby.length; i++) {
      if (chains >= maxChains) break;
      final enemy = nearby[i];
      // Lightning wet bonus applies to chain too
      final actualDmg = enemy.isWet ? chainDamage * 2 : chainDamage;
      enemy.takeDamage(actualDmg);
      world.add(ChainEffect(from: primaryTarget.position, to: enemy.position, color: chainColor));
      chains++;
    }
  }

  void _applyWizardChain(Tower wizard, Enemy primaryTarget) {
    // Chain to up to 2 additional enemies within 2 cells of primary target
    final chainRange = cellSize * 2.0;
    final chainDamage = (wizard.currentDamage * 0.5).round();
    int chains = 0;
    final maxChains = wizard.t4Branch == T4BranchPath.pathA ? 5 : (2 + (wizard.tier > 2 ? 1 : 0)); // Archmage: 5 chains
    const chainColor = Color(0xFF9966FF); // wizard purple

    // Use spatial grid for chain targets
    final nearby = _spatialGrid.queryRangeExcluding(
      primaryTarget.position.x, primaryTarget.position.y, chainRange, primaryTarget,
    );
    for (int i = 0; i < nearby.length; i++) {
      if (chains >= maxChains) break;
      final enemy = nearby[i];
      enemy.takeDamage(chainDamage);
      world.add(ChainEffect(from: primaryTarget.position, to: enemy.position, color: chainColor));
      chains++;
    }
  }

  // ═══ Boss Damage Batch: Accumulate ═══
  // Calculates damage for this tower→boss hit and stores it without processing.
  void _bossBatchAccumulate(Tower tower, Enemy boss) {
    int damage = (tower.currentDamage * runBuffs.damageMultiplier).round();
    if (_metaEarlyWaveDamageBonus > 0 && waveSystem.currentWave <= 3) {
      damage = (damage * (1.0 + _metaEarlyWaveDamageBonus)).round();
    }
    if (_metaPhysicalDamageBonus > 0 &&
        (tower.type == TowerType.arrow || tower.type == TowerType.cannon || tower.type == TowerType.spikeWall)) {
      damage = (damage * (1.0 + _metaPhysicalDamageBonus)).round();
    }
    damage = (damage * _artifactBossDamageMultiplier).round();
    // Lightning wet bonus
    if (tower.type == TowerType.lightning && boss.isWet) {
      damage *= 2;
    }
    // Holy bonus vs undead/shadow
    if (tower.type == TowerType.holy &&
        (boss.type == EnemyType.undead || boss.type == EnemyType.darkKnight || boss.type == EnemyType.shadowLord)) {
      damage = (damage * 1.5).round();
    }

    _bossBatchDamage += damage;
    _bossBatchHits++;
    _bossBatchTarget = boss;
    _bossBatchTowers.add(tower);
    _bossBatchDmgPerTower.add(damage);
    _bossBatchTowerTypes.add(tower.type);
    if (tower.synergyFreezeOnHit) _bossBatchHadSynergyFreeze = true;
    if (tower.type == TowerType.cannon) _bossBatchHadCannon = true;
  }

  // ═══ Boss Damage Batch: Flush ═══
  // Processes all accumulated damage as a SINGLE event:
  //   1 takeDamage, 1 hit effect, 1 floating text, 1 audio, 1 combo check.
  void _bossBatchFlush() {
    final boss = _bossBatchTarget!;
    final totalDmg = _bossBatchDamage;

    // Populate debug stats
    debugBossHitsThisFrame = _bossBatchHits;
    debugBossDamageFlushed = totalDmg;
    debugBossEffectsMerged = _bossBatchTowerTypes.length;
    debugBossBatchActive = true;

    // --- 1. Per-tower stat tracking (no game logic, just counters) ---
    for (int i = 0; i < _bossBatchTowers.length; i++) {
      final dmg = _bossBatchDmgPerTower[i];
      _totalDamageDealt += dmg;
      _bossBatchTowers[i].totalDamageDealt += dmg;
    }

    // --- 2. Single damage application ---
    final willKill = boss.hp > 0 && boss.hp <= totalDmg;
    boss.takeDamage(totalDmg); // 1 call instead of N

    // --- 3. Deduplicated status effects (1 per type, not N) ---
    for (final towerType in _bossBatchTowerTypes) {
      switch (towerType) {
        case TowerType.ice:
          boss.applyEffect(StatusEffect.slow(factor: 0.4, duration: 2.0 * _artifactSlowDurationMultiplier));
        case TowerType.fire:
          boss.applyEffect(StatusEffect.burn(dps: 4, duration: 3.0));
        case TowerType.poison:
          boss.applyEffect(StatusEffect.poison(dps: 3, duration: 5.0));
        case TowerType.water:
          boss.applyEffect(StatusEffect.wet(duration: 3.0));
        case TowerType.dark:
          boss.applyEffect(StatusEffect.curse(armorReduce: 8, duration: 4.0));
        default:
          break; // arrow/cannon/lightning/holy: no persistent effect
      }
    }

    // --- 4. Synergy freeze (once, not per-tower) ---
    if (_bossBatchHadSynergyFreeze && !boss.isDead) {
      boss.applyEffect(StatusEffect.slow(factor: 1.0, duration: 3.0));
    }

    // --- 5. Single visual feedback ---
    // One combined damage text
    _showDamageText(boss.position, totalDmg);
    // One hit effect (pick visually prominent color based on tower mix)
    final effectColor = _bossBatchTowerTypes.contains(TowerType.fire)
        ? const Color(0xFFFF4500)
        : _bossBatchTowerTypes.contains(TowerType.ice)
            ? const Color(0xFF87CEEB)
            : _bossBatchTowerTypes.contains(TowerType.lightning)
                ? const Color(0xFFFFD700)
                : const Color(0xFFFFAA44);
    _addEffect(HitEffect(pos: boss.position, color: effectColor, count: 6, speed: 55, maxLife: 0.25));

    // --- 6. Lightning T4 specials (chain + EMP on boss) ---
    for (final tower in _bossBatchTowers) {
      if (tower.type != TowerType.lightning) continue;
      if (tower.t4Branch == T4BranchPath.pathA) {
        _applyLightningChain(tower, boss);
      } else if (tower.t4Branch == T4BranchPath.pathB) {
        boss.abilitiesDisabled = true;
        boss.applyEffect(StatusEffect.slow(factor: 0.2, duration: 4.0));
      }
    }

    // --- 7. Kill handling ---
    if (willKill || boss.isDead) {
      _addEffect(HitEffect(pos: boss.position, color: const Color(0xFFFFFFFF), count: 6, speed: 65, size: 2.5, maxLife: 0.18));
      triggerHitStop(0.07);
      for (final tower in _bossBatchTowers) {
        tower.kills++;
        // T4 Phoenix heal on kill
        if (tower.type == TowerType.fire && tower.t4Branch == T4BranchPath.pathB) {
          castle.heal(3 + waveSystem.currentWave);
        }
      }
    }
    // Cannon hit-stop once (not per-cannon)
    else if (_bossBatchHadCannon) {
      triggerHitStop(0.02);
    }

    // --- 8. Single combo check (after all effects applied) ---
    if (!boss.isDead) {
      final combo = comboSystem.checkCombos(boss.activeEffects, boss.enemyId);
      if (combo != null) {
        _applyCombo(combo, boss);
      }
    }
  }

  // ═══ Non-boss: original per-hit damage (unchanged) ═══
  void _applyTowerDamage(Tower tower, Enemy enemy) {
    enemy.lastHitTowerType = tower.type;
    int damage = (tower.currentDamage * runBuffs.damageMultiplier).round();

    // Meta: Savaş Çığlığı - +30% damage first 3 waves
    if (_metaEarlyWaveDamageBonus > 0 && waveSystem.currentWave <= 3) {
      damage = (damage * (1.0 + _metaEarlyWaveDamageBonus)).round();
    }
    // Meta: Çelik Yumruk - +15% physical (arrow, cannon, spikeWall)
    if (_metaPhysicalDamageBonus > 0 &&
        (tower.type == TowerType.arrow || tower.type == TowerType.cannon || tower.type == TowerType.spikeWall)) {
      damage = (damage * (1.0 + _metaPhysicalDamageBonus)).round();
    }
    // ═══ Enemy Adaptation: 30% damage reduction vs dominant tower type ═══
    if (enemy.adaptedAgainst == tower.type) {
      damage = (damage * 0.7).round();
    }
    // ═══ ShadowLord Aura: 25% damage reduction for nearby towers ═══
    if (isShadowLordAuraActive(tower.position + tower.size / 2)) {
      damage = (damage * 0.75).round();
    }

    _totalDamageDealt += damage;
    tower.totalDamageDealt += damage;
    _showDamageText(enemy.position, damage);

    // Track kill (pre-check: if this damage will kill the enemy)
    final willKill = enemy.hp > 0 && enemy.hp <= damage;

    switch (tower.type) {
      case TowerType.ice:
        enemy.takeDamage(damage);
        if (_activeWaveModifier != WaveModifier.iceImmune) {
          enemy.applyEffect(StatusEffect.slow(factor: 0.4, duration: 2.0 * _artifactSlowDurationMultiplier));
        }
        _addEffect(HitEffect.ice(pos: enemy.position));
        break;
      case TowerType.fire:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.burn(dps: 4, duration: 3.0));
        _addEffect(HitEffect.fire(pos: enemy.position));
        break;
      case TowerType.poison:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.poison(dps: 3, duration: 5.0));
        _addEffect(HitEffect.poison(pos: enemy.position));
        break;
      case TowerType.water:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.wet(duration: 3.0));
        _addEffect(HitEffect(pos: enemy.position, color: const Color(0xFF4169E1), count: 5, speed: 40));
        break;
      case TowerType.dark:
        enemy.takeDamage(damage);
        enemy.applyEffect(StatusEffect.curse(armorReduce: 8, duration: 4.0));
        _addEffect(HitEffect(pos: enemy.position, color: const Color(0xFF8B00FF), count: 6, speed: 45));
        break;
      case TowerType.lightning:
        final actualDmg = enemy.isWet ? damage * 2 : damage;
        enemy.takeDamage(actualDmg);
        _addEffect(HitEffect.lightning(pos: enemy.position));
        // T4 Path B (EMP Darbesi): disable enemy abilities for 4 seconds
        if (tower.t4Branch == T4BranchPath.pathB && enemy.baseStats.isBoss) {
          enemy.abilitiesDisabled = true;
          enemy.applyEffect(StatusEffect.slow(factor: 0.2, duration: 4.0));
        }
        break;
      case TowerType.holy:
        final holyBonus = (enemy.type == EnemyType.undead || enemy.type == EnemyType.darkKnight || enemy.type == EnemyType.shadowLord)
            ? (damage * 0.5).round()
            : 0;
        enemy.takeDamage(damage + holyBonus);
        _addEffect(HitEffect(pos: enemy.position, color: const Color(0xFFFFFACD), count: 7, speed: 55));
        break;
      default:
        // Arrow / cannon / spikeWall: sharper spark
        enemy.takeDamage(damage);
        _addEffect(HitEffect(pos: enemy.position, color: const Color(0xFFEEDDCC), count: 5, speed: 50, size: 2.0, maxLife: 0.25));
        break;
    }
    // Killing blow: extra impact burst + hit-stop + kill shake
    if (willKill) {
      _addEffect(HitEffect(pos: enemy.position, color: const Color(0xFFFFFFFF), count: 6, speed: 65, size: 2.5, maxLife: 0.18));
      if (enemy.isElite) {
        triggerHitStop(0.05);
        screenShake.shake(duration: 0.12, intensity: 2.0);
      } else {
        triggerHitStop(0.03);
        screenShake.shake(duration: 0.08, intensity: 1.0);
      }
    }
    // Cannon non-kill hit: short hit-stop for weight
    else if (tower.type == TowerType.cannon) {
      triggerHitStop(0.02);
    }

    // Buz Hapsi synergy: full freeze (100% slow) for 3 seconds on hit
    if (tower.synergyFreezeOnHit && !enemy.isDead) {
      enemy.applyEffect(StatusEffect.slow(factor: 1.0, duration: 3.0));
      _addEffect(HitEffect.ice(pos: enemy.position));
    }

    // Combo system check
    if (!enemy.isDead) {
      final combo = comboSystem.checkCombos(enemy.activeEffects, enemy.enemyId);
      if (combo != null) {
        _applyCombo(combo, enemy);
      }
    }

    // T4 special: Phoenix (fire pathB) - heal castle on kill
    if ((willKill || enemy.isDead) && tower.type == TowerType.fire && tower.t4Branch == T4BranchPath.pathB) {
      castle.heal(3 + waveSystem.currentWave);
    }

    if (willKill || enemy.isDead) {
      tower.kills++;
    }
  }

  // ═══ Enemy Adaptation: find player's most-used tower type ═══
  void _updateDominantTowerType() {
    if (_towers.isEmpty) { _dominantTowerType = null; return; }
    final counts = <TowerType, int>{};
    for (final t in _towers) {
      counts[t.type] = (counts[t.type] ?? 0) + 1;
    }
    TowerType? dominant;
    int maxCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
      }
    }
    _dominantTowerType = (maxCount >= _adaptationThreshold) ? dominant : null;

    // Track most-used tower type (for death screen)
    _mostUsedTowerType = dominant;
  }

  /// Classify player's build archetype based on tower composition.
  void _classifyBuild() {
    if (_towers.length < 3) { _currentBuildLabel = ''; return; }
    final counts = <TowerType, int>{};
    for (final t in _towers) {
      counts[t.type] = (counts[t.type] ?? 0) + 1;
    }
    // Group by archetype
    final archetypes = <String, int>{
      'Ateş Yapısı': (counts[TowerType.fire] ?? 0) + (counts[TowerType.cannon] ?? 0),
      'Kontrol Yapısı': (counts[TowerType.ice] ?? 0) + (counts[TowerType.spikeWall] ?? 0) + (counts[TowerType.water] ?? 0),
      'Yıkım Yapısı': (counts[TowerType.lightning] ?? 0) + (counts[TowerType.wizard] ?? 0),
      'Zehir Yapısı': (counts[TowerType.poison] ?? 0) + (counts[TowerType.dark] ?? 0),
      'Destek Yapısı': (counts[TowerType.support] ?? 0) + (counts[TowerType.holy] ?? 0),
    };
    String? best;
    int bestCount = 0;
    for (final e in archetypes.entries) {
      if (e.value > bestCount) { bestCount = e.value; best = e.key; }
    }
    final newLabel = (bestCount >= 2) ? (best ?? '') : '';
    if (newLabel.isNotEmpty && newLabel != _currentBuildLabel && !_buildLabelAnnounced) {
      _buildLabelAnnounced = true;
      _atmosphere.triggerEventPulse(0.6);
      world.add(FloatingText(
        text: newLabel,
        pos: Vector2(_gameWidth / 2, _gameHeight * 0.22),
        color: const Color(0xFFFFD700),
        fontSize: 13,
        isCritical: true,
      ));
    }
    _currentBuildLabel = newLabel;
  }

  void _applyCombo(ComboType combo, Enemy enemy) {
    AudioSystem.instance.play(GameSound.comboTrigger);
    tutorialSystem.tryShow(TutorialTrigger.comboOccurred);
    screenShake.shake(duration: 0.2, intensity: 3.0);
    switch (combo) {
      case ComboType.frozen:
        // Full freeze for 5 seconds + 50% bonus damage marker
        enemy.applyEffect(StatusEffect.slow(factor: 1.0, duration: 5.0));
        _addEffect(HitEffect.ice(pos: enemy.position));
        world.add(FloatingText(
          text: 'DONMUŞ!', pos: enemy.position + Vector2(0, -20),
          color: const Color(0xFF22CCEE), fontSize: 12, isCritical: true,
        ));
        break;
      case ComboType.meltdown:
        // Burn+poison combo (nerfed)
        enemy.applyEffect(StatusEffect.burn(dps: 8, duration: 3.0));
        _addEffect(HitEffect.fire(pos: enemy.position));
        world.add(FloatingText(
          text: 'ERİME!', pos: enemy.position + Vector2(0, -20),
          color: const Color(0xFFFF6600), fontSize: 12, isCritical: true,
        ));
        break;
      case ComboType.soulShatter:
        // Zero armor for 5 seconds
        enemy.applyEffect(StatusEffect.curse(armorReduce: 999, duration: 5.0));
        _addEffect(HitEffect(pos: enemy.position, color: const Color(0xFF8800FF), count: 8, speed: 50));
        world.add(FloatingText(
          text: 'RUH PARÇALAMA!', pos: enemy.position + Vector2(0, -20),
          color: const Color(0xFF8800FF), fontSize: 12, isCritical: true,
        ));
        break;
    }
  }

  // Reusable lists for _processEnemies (avoid per-frame allocation)
  final List<Enemy> _peToRemove = [];
  final List<Enemy> _peToSpawn = [];

  void _processEnemies() {
    _peToRemove.clear();
    _peToSpawn.clear();
    final toRemove = _peToRemove;
    final toSpawn = _peToSpawn;
    for (final enemy in _enemies) {
      if (enemy.isDead) {
        double goldMult = _mutationGoldMult * runBuffs.goldMultiplier;
        if (enemy.baseStats.isBoss && _metaBossGoldMultiplier > 1.0) {
          goldMult *= _metaBossGoldMultiplier;
        }
        // Hard cap total gold multiplier to prevent economy explosion
        if (goldMult > 3.0) goldMult = 3.0;
        final goldEarned = (enemy.goldReward * goldMult).round();
        economy.earnGold(goldEarned);
        _enemiesKilled++;
        if (!(enemy.baseStats.isBoss && debugDisableBossAudio)) {
          AudioSystem.instance.play(enemy.baseStats.isBoss ? GameSound.bossRoar : GameSound.enemyDeath);
        }
        AudioSystem.instance.play(GameSound.goldEarn);
        if (enemy.baseStats.isBoss) {
          _bossesKilled++;
          _activeBosses.remove(enemy);
          _hasBossAlive = _activeBosses.isNotEmpty;
        }
        // Kill streak tracking
        _killStreak++;
        _killStreakTimer = _killStreakWindow;
        if (_killStreak > _bestKillStreak) _bestKillStreak = _killStreak;
        if (_killStreak >= 3) {
          final streakBonus = _killStreak;
          economy.earnGold(streakBonus);
        }
        // ═══ Kill Combo Milestones ═══
        if (_killStreak == 5) {
          _atmosphere.triggerEventPulse(0.4);
          world.add(FloatingText(
            text: 'COMBO x5!',
            pos: Vector2(_gameWidth / 2, _gameHeight * 0.35),
            color: const Color(0xFFFF8800),
            fontSize: 14,
            isCritical: true,
          ));
        } else if (_killStreak == 10) {
          screenShake.shake(duration: 0.15, intensity: 3.0);
          _atmosphere.triggerEventPulse(0.7);
          world.add(FloatingText(
            text: 'RAMPAGE!',
            pos: Vector2(_gameWidth / 2, _gameHeight * 0.35),
            color: const Color(0xFFFF2200),
            fontSize: 16,
            isCritical: true,
          ));
        } else if (_killStreak == 20) {
          screenShake.shake(duration: 0.2, intensity: 4.0);
          _atmosphere.triggerEventPulse(1.0);
          world.add(FloatingText(
            text: 'UNSTOPPABLE!',
            pos: Vector2(_gameWidth / 2, _gameHeight * 0.35),
            color: const Color(0xFFFFDD00),
            fontSize: 18,
            isCritical: true,
          ));
        }
        // ═══ Element-specific Kill Effects ═══
        if (enemy.baseStats.isBoss) {
          _addEffect(HitEffect.bossDeath(pos: enemy.position));
          screenShake.shake(duration: 0.35, intensity: 8.0);
          triggerHitStop(0.07);
          _atmosphere.triggerEventPulse(1.2);
          _atmosphere.triggerRelease(1.5);
        } else if (enemy.isElite) {
          _addEffect(HitEffect.death(pos: enemy.position, color: const Color(0xFFFF6600)));
          triggerHitStop(0.03); // mini hitstop for elites
        } else {
          // Element kill: use color of the last tower that hit this enemy
          final killColor = enemy.lastHitTowerType != null
              ? _elementKillColor(enemy.lastHitTowerType!)
              : null;
          if (killColor != null) {
            _addEffect(HitEffect.death(pos: enemy.position, color: killColor));
          } else {
            _addEffect(HitEffect.death(pos: enemy.position));
          }
        }
        // Show gold earned text (easy enemies get smaller text)
        final isEasy = enemy.baseStats.difficulty == EnemyDifficulty.easy && _killStreak < 3;
        final streakText = _killStreak >= 3 ? ' x$_killStreak!' : '';
        world.add(FloatingText(
          text: '+${goldEarned}g$streakText',
          pos: enemy.position + Vector2(0, -15),
          color: _killStreak >= 5 ? const Color(0xFFFF4444) : _killStreak >= 3 ? const Color(0xFFFF8800) : const Color(0xFFFFD700),
          fontSize: _killStreak >= 5 ? 13 : _killStreak >= 3 ? 11 : isEasy ? 7 : 9,
        ));
        // Wave Modifier: death explosion damages castle
        if (_activeWaveModifier == WaveModifier.deathExplosion && !enemy.baseStats.isBoss) {
          castle.takeDamage(1);
        }
        // Elite splitting: spawn 2 copies on death
        if (enemy.isElite && enemy.eliteModifier == EliteModifier.splitting && enemy.baseStats.splitCount == 0) {
          final remainingPath = enemy.remainingPath;
          if (remainingPath.length > 1) {
            for (int i = 0; i < 2; i++) {
              final split = Enemy(
                type: enemy.type,
                baseStats: EnemyStats(
                  type: enemy.type, name: enemy.baseStats.name,
                  hp: (enemy.maxHp * 0.4).round(), armor: 0,
                  speed: enemy.baseStats.speed * 1.1,
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
          AudioSystem.instance.play(GameSound.castleHit);
          _damageTakenThisWave = true;
          screenShake.shake(
            duration: 0.2,
            intensity: (dmg * 1.5).clamp(2.0, 8.0).toDouble(),
          );
        }
        // Gold loss on castle breach (reduced for balance)
        final goldPenalty = enemy.type == EnemyType.goblin
            ? (8 + waveSystem.currentWave).clamp(0, 30).clamp(0, economy.gold)
            : (3 + waveSystem.currentWave ~/ 2).clamp(0, 15).clamp(0, economy.gold);
        if (goldPenalty > 0) {
          economy.trySpend(goldPenalty);
          _goldStolen += goldPenalty;
        }
        toRemove.add(enemy);
      }
    }
    // Clean up per-enemy tracked state and trigger death/remove visuals
    for (final enemy in toRemove) {
      _cavalryDashTimers.remove(enemy);
      _darkKnightBuffed.remove(enemy);
      _bossAbilityTimers.remove(enemy);
      comboSystem.removeEnemy(enemy.enemyId);
      if (enemy.isDead) {
        enemy.startDeathAnim(); // Fade-out animation, self-removes after 0.45s
      } else {
        enemy.removeFromParent(); // Reached castle, remove immediately
      }
    }
    // Batch remove — O(n) instead of O(n²) from repeated .remove() calls
    if (toRemove.isNotEmpty) {
      final removeSet = toRemove.toSet();
      _enemies.removeWhere((e) => removeSet.contains(e));
    }
    for (final enemy in toSpawn) {
      _enemies.add(enemy);
      world.add(enemy);
    }
    // Update cached count
    int alive = 0;
    for (final e in _enemies) {
      if (!e.isDead && !e.reachedCastle) alive++;
    }
    _cachedEnemiesAlive = alive;
    if (toRemove.isNotEmpty) onStateChanged?.call();
  }

  void _updateHealerEnemies(double dt) {
    _healerTickTimer += dt;
    if (_healerTickTimer < 1.0) return;
    _healerTickTimer = 0;

    final healRange = cellSize * 2.0;
    for (final healer in _enemies) {
      if (healer.isDead || healer.reachedCastle || healer.type != EnemyType.healer) continue;
      // Use spatial grid for nearby allies
      final nearby = _spatialGrid.queryRange(healer.position.x, healer.position.y, healRange);
      final healAmount = _activeWaveModifier == WaveModifier.fastHealers ? 4 : 2;
      int healed = 0;
      for (int i = 0; i < nearby.length; i++) {
        final other = nearby[i];
        if (other == healer || other.hp >= other.maxHp) continue;
        other.heal(healAmount);
        healed++;
      }
      if (healed > 0) {
        world.add(FloatingText(
          text: '+${healAmount * healed}',
          pos: healer.position + Vector2(0, -10),
          color: const Color(0xFF00FF00),
          fontSize: 8,
        ));
      }
    }
  }

  void _onWaveComplete() {
    // Wave clear celebration overlay
    world.add(WaveClearEffect(
      waveNumber: waveSystem.currentWave,
      worldSize: Vector2(_gameWidth, _gameHeight),
      isPerfect: !_damageTakenThisWave,
    ));
    AudioSystem.instance.play(GameSound.waveComplete);
    AudioSystem.instance.resetStats(); // reset debug counters per wave

    // ═══ Castle Attrition: escalating wear after wave 15 ═══
    // Every 5 waves after 15, castle takes (wave/10) damage
    final w = waveSystem.currentWave;
    if (w >= _attritionStartWave && w % 5 == 0) {
      final attritionDmg = (w ~/ 10).clamp(1, 5);
      castle.takeDamage(attritionDmg);
      world.add(FloatingText(
        text: 'Kale yıpranması -$attritionDmg',
        pos: castle.position + Vector2(0, -25),
        color: const Color(0xFFFF4444),
        fontSize: 10,
      ));
    }

    // Clear wave modifier
    _activeWaveModifier = WaveModifier.none;

    // Wave-end sweep: clear all per-enemy tracking maps
    _bossSpawnCount.clear();
    _darkKnightBuffed.clear();
    _cavalryDashTimers.clear();
    _bossAbilityTimers.clear();
    _activeBosses.clear();
    _hasBossAlive = false;

    // Clear stale projectiles that might still be in-flight
    for (final p in _projectiles) {
      p.removeFromParent();
    }
    _projectiles.clear();

    // Invalidate all tower target caches for fresh start
    // Stagger retarget timers so towers don't all re-scan on the same frame
    for (int i = 0; i < _towers.length; i++) {
      _towers[i].setCachedTarget(null);
      _towers[i].staggerRetargetTimer(i * 0.02); // 20ms stagger per tower
    }
    if (waveSystem.currentWave == 1) tutorialSystem.tryShow(TutorialTrigger.firstWaveComplete);
    // Track perfect waves (no damage taken)
    if (!_damageTakenThisWave) {
      _totalPerfectWaves++;
      _consecutivePerfectWaves++;
      if (_consecutivePerfectWaves > _bestPerfectWaves) {
        _bestPerfectWaves = _consecutivePerfectWaves;
      }
    } else {
      _consecutivePerfectWaves = 0;
    }
    _damageTakenThisWave = false;

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
      if (_damageTextRng.nextDouble() < _metaBonusGoldRoom) {
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
      if (_damageTextRng.nextDouble() < _metaAncientArtifactChance) {
        final bonus = 50 + waveSystem.currentWave * 5;
        economy.earnGold(bonus);
      }
    }
    // Çift Sur: regenerate shield between waves
    if (_maxSecondaryShield > 0 && _secondaryShield < _maxSecondaryShield) {
      _secondaryShield = (_secondaryShield + (_maxSecondaryShield * 0.3).round())
          .clamp(0, _maxSecondaryShield);
    }

    // Show total wave bonus gold
    final waveBonus = economy.gold - goldBefore;
    if (waveBonus > 0) {
      world.add(FloatingText(
        text: '+${waveBonus}g',
        pos: castle.position + Vector2(castle.size.x / 2, -20),
        color: const Color(0xFFFFD700),
        fontSize: 11,
      ));
    }

    // ═══ Tower Unlock Notifications ═══
    if (!_metaAllTowersUnlocked) {
      final nextWave = waveSystem.currentWave + 1;
      final newTowers = TowerData.allTypes.where((t) {
        final stats = TowerData.getStats(t);
        return stats.unlockWave == nextWave;
      }).toList();
      double yOffset = 0;
      for (final tower in newTowers) {
        final stats = TowerData.getStats(tower);
        world.add(FloatingText(
          text: '${stats.name} Açıldı!',
          pos: Vector2(_gameWidth / 2, _gameHeight * 0.4 + yOffset),
          color: const Color(0xFF44DDFF),
          fontSize: 12,
        ));
        world.add(FloatingText(
          text: stats.roleHint,
          pos: Vector2(_gameWidth / 2, _gameHeight * 0.4 + yOffset + 16),
          color: const Color(0xAABBDDEE),
          fontSize: 9,
        ));
        yOffset += 36;
      }
    }

    // Decrement tower curse counters
    final curseExpired = <Tower>[];
    for (final entry in _cursedTowerWaves.entries) {
      _cursedTowerWaves[entry.key] = entry.value - 1;
      if (entry.value - 1 <= 0) {
        entry.key.curseDebuffMult = 1.0;
        curseExpired.add(entry.key);
      }
    }
    for (final t in curseExpired) {
      _cursedTowerWaves.remove(t);
    }

    // Roll wave event
    final rng = math.Random(mapSeed + waveSystem.currentWave);
    _currentEvent = EventSystem.rollEvent(waveSystem.currentWave, rng);
    _merchantAvailable = false;

    if (_currentEvent != null) tutorialSystem.tryShow(TutorialTrigger.eventAppeared);
    // Apply non-interactive events immediately
    if (_currentEvent != null) {
      switch (_currentEvent!.type) {
        case WaveEventType.treasure:
          economy.earnGold(_currentEvent!.goldAmount ?? 50);
          break;
        case WaveEventType.castleRepair:
          castle.heal((castle.maxHp * 0.15).round());
          break;
        case WaveEventType.curse:
          if (_towers.isNotEmpty) {
            final cursedTower = _towers[rng.nextInt(_towers.length)];
            cursedTower.curseDebuffMult = 0.8;
            _cursedTowerWaves[cursedTower] = 2;
          }
          break;
        case WaveEventType.merchant:
          _merchantAvailable = true;
          break;
        case WaveEventType.ambush:
          // Ambush spawns enemies immediately after wave break starts
          break;
      }
    }

    // Infinite scaling: +10% every 5 waves (applied to enemy HP at spawn)
    if (waveSystem.currentWave % 5 == 0) {
      _endlessScaling += 0.10;
    }

    // ═══ Wave 2 Tower Choice: offer after wave 1 ═══
    if (waveSystem.currentWave == 1 && _wave2Choice == null && !_metaAllTowersUnlocked) {
      _pendingTowerChoice = true;
    }

    // Roguelike buff selection every 5 waves
    if (WaveBuffSystem.shouldOfferBuff(waveSystem.currentWave)) {
      _pendingBuffChoices = WaveBuffSystem.getChoices(
        rng: math.Random(mapSeed + waveSystem.currentWave),
      );
    }

    if (_autoWave) {
      // Short break before next wave in auto mode
      _breakTimer = 3.0;
      _currentEvent = null;
      _phase = GamePhase.waveBreak;
      onStateChanged?.call();
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
      final goldBefore = economy.gold;
      if (placeTower(col, row, selectedTowerType!)) {
        final spent = goldBefore - economy.gold;
        if (spent > 0) {
          world.add(FloatingText(
            text: '-${spent}g',
            pos: Vector2(col * cellSize + cellSize / 2, row * cellSize - 6),
            color: const Color(0xFFFF9966),
            fontSize: 8,
          ));
        }
        selectedTowerType = null;
        updatePlacementHighlight();
      } else if (_towerPositions.containsKey((col: col, row: row)) == false &&
          gameMap.canPlaceTower(col, row, isSpikeWall: selectedTowerType == TowerType.spikeWall) &&
          economy.gold < adjustedTowerCost(selectedTowerType!)) {
        // Placement failed due to insufficient gold
        _goldRejectCounter++;
        world.add(FloatingText(
          text: 'YETERSİZ ALTIN',
          pos: Vector2(col * cellSize + cellSize / 2, row * cellSize - 6),
          color: const Color(0xFFFF4444),
          fontSize: 8,
        ));
        onStateChanged?.call();
      }
      return;
    }

    // Otherwise, check if there's a placed tower at this position
    final existingType = _towerPositions[(col: col, row: row)];
    if (existingType != null) {
      final tower = _towers.firstWhere((t) => t.col == col && t.row == row);

      // Merge check: if we have a selected tower and tap a different same-type tower
      if (_selectedPlacedTower != null && _selectedPlacedTower != tower) {
        if (canMerge(_selectedPlacedTower!, tower)) {
          mergeTowers(_selectedPlacedTower!, tower);
          _selectPlacedTower(tower); // select the merged result
          return;
        }
      }

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

  List<TowerType> get availableTowers {
    final base = TowerData.availableAt(waveSystem.currentWave, allUnlocked: _metaAllTowersUnlocked);
    if (_metaAllTowersUnlocked || _wave2Choice != null) {
      // If choice made, hide unchosen tower until wave 4
      if (_wave2Choice != null && waveSystem.currentWave < 4) {
        final unchosen = _wave2Options.firstWhere((t) => t != _wave2Choice);
        return base.where((t) => t != unchosen).toList();
      }
      return base;
    }
    // Before choice: hide both wave-2 options
    if (waveSystem.currentWave >= 2 && waveSystem.currentWave < 4) {
      return base.where((t) => !_wave2Options.contains(t)).toList();
    }
    return base;
  }

  int adjustedTowerCost(TowerType type) =>
      (TowerData.getStats(type).cost * _mutationTowerCostMult * runBuffs.towerCostMultiplier).round();

  /// Preview of next wave composition
  List<WaveEntry> get nextWavePreview {
    final next = waveSystem.currentWave + 1;
    return WaveData.getWave(next, difficulty, seed: mapSeed);
  }

  /// Extra wave previews (Kesif node 6: preview +1 additional wave)
  List<List<WaveEntry>> get extraWavePreviews {
    if (_metaPreviewWaves <= 1) return [];
    final previews = <List<WaveEntry>>[];
    for (int i = 2; i <= _metaPreviewWaves; i++) {
      final waveNum = waveSystem.currentWave + i;
      previews.add(WaveData.getWave(waveNum, difficulty, seed: mapSeed));
    }
    return previews;
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

  // Shared RNG for damage text offsets (avoid per-call allocation)
  static final math.Random _damageTextRng = math.Random();

  Color _elementKillColor(TowerType type) {
    switch (type) {
      case TowerType.fire: return const Color(0xFFFF5511);
      case TowerType.ice: return const Color(0xFF22CCEE);
      case TowerType.lightning: return const Color(0xFFFFDD00);
      case TowerType.poison: return const Color(0xFF33FF33);
      case TowerType.water: return const Color(0xFF00BBCC);
      case TowerType.dark: return const Color(0xFF8833DD);
      case TowerType.holy: return const Color(0xFFFFDD66);
      case TowerType.cannon: return const Color(0xFFFF6633);
      default: return const Color(0xFFFF8844);
    }
  }

  void _showDamageText(Vector2 pos, int damage) {
    if (_hasBossAlive && debugDisableBossTexts) return;
    // Smart filtering: skip tiny damage numbers to reduce visual noise
    if (damage < 5 && _damageTextRng.nextDouble() > 0.3) return;
    final cap = _hasBossAlive ? _maxTextsPerFrameBoss : _maxTextsPerFrame;
    if (_textsThisFrame >= cap) return;
    _textsThisFrame++;

    final isCritical = damage >= 30;
    final color = damage >= 30
        ? const Color(0xFFFF4444)
        : damage >= 15
            ? const Color(0xFFFFAA00)
            : const Color(0xFFFFFFFF);
    final offsetX = (_damageTextRng.nextDouble() - 0.5) * 12.0;
    world.add(FloatingText(
      text: '-$damage',
      pos: pos + Vector2(offsetX, -10),
      color: color,
      fontSize: damage >= 30 ? 14 : 10,
      isCritical: isCritical,
    ));
  }

  /// Add a HitEffect only if under the per-frame limit
  void _addEffect(HitEffect effect) {
    if (_hasBossAlive && debugDisableBossEffects) return; // debug: skip all effects during boss
    final cap = _hasBossAlive ? _maxEffectsPerFrameBoss : _maxEffectsPerFrame;
    if (_effectsThisFrame >= cap) return;
    _effectsThisFrame++;
    world.add(effect);
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

  GameSound _towerAmbientSound(TowerType type) {
    switch (type) {
      case TowerType.ice:
      case TowerType.water:
        return GameSound.ambiCold;
      case TowerType.fire:
      case TowerType.cannon:
        return GameSound.ambiHot;
      case TowerType.lightning:
      case TowerType.support:
        return GameSound.ambiElectric;
      case TowerType.arrow:
      case TowerType.poison:
      case TowerType.spikeWall:
      case TowerType.wizard:
      case TowerType.dark:
      case TowerType.holy:
        return GameSound.ambiMystic;
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
