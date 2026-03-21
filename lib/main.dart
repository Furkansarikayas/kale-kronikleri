import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/kale_game.dart';
import 'game/data/game_config.dart';
import 'game/systems/mutation_system.dart';
import 'meta/artifact_system.dart';
import 'meta/meta_tree.dart';
import 'meta/save_manager.dart';
import 'screens/main_menu.dart';
import 'screens/run_setup.dart';
import 'screens/death_screen.dart';
import 'screens/meta_screen.dart';
import 'screens/game_hud.dart';
import 'screens/wave_break.dart';
import 'screens/pause_overlay.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const KaleKronikleriApp());
}

class KaleKronikleriApp extends StatelessWidget {
  const KaleKronikleriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A150E),
      ),
      home: const AppShell(),
    );
  }
}

enum AppScreen { mainMenu, runSetup, game, meta, death, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppScreen _screen = AppScreen.mainMenu;
  KaleGame? _game;
  SaveManager? _saveManager;
  bool _saveLoaded = false;

  // Run results for death screen
  bool _lastVictory = false;
  int _lastWaves = 0;
  int _lastSpiritEarned = 0;
  int _lastEnemiesKilled = 0;
  int _lastTowersPlaced = 0;

  @override
  void initState() {
    super.initState();
    _loadSave();
  }

  // Debug: set to false before release
  static const _debugAutoStart = false;

  Future<void> _loadSave() async {
    _saveManager = await SaveManager.create();
    setState(() => _saveLoaded = true);
    if (_debugAutoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startGame(DifficultyTier.apprentice, []);
      });
    }
  }

  void _goToMainMenu() => setState(() => _screen = AppScreen.mainMenu);

  void _goToRunSetup() => setState(() => _screen = AppScreen.runSetup);

  void _goToMeta() => setState(() => _screen = AppScreen.meta);

  void _goToSettings() => setState(() => _screen = AppScreen.settings);

  void _startGame(DifficultyTier difficulty, List<ArtifactDef> artifacts) {
    final seed = Random().nextInt(999999);
    final weeklyMutations = MutationSystem.getWeeklyMutations();
    final game = KaleGame(
      mapSeed: seed,
      difficulty: difficulty,
      artifacts: artifacts,
      metaLevels: {
        'savas': _saveManager!.metaSavas,
        'kesif': _saveManager!.metaKesif,
        'kale': _saveManager!.metaKale,
        'efsane': _saveManager!.metaEfsane,
      },
      mutations: weeklyMutations,
    );

    game.onStateChanged = () {
      if (mounted) setState(() {});
    };
    game.onSynergyDiscovered = () {
      // Save discovered synergies
      for (final synergy in game.activeSynergyNames) {
        final synergyId = game.synergySystem.activeSynergies
            .where((s) => s.name == synergy)
            .map((s) => s.id)
            .firstOrNull;
        if (synergyId != null) {
          _saveManager!.discoverSynergy(synergyId);
        }
      }
    };

    game.onGameOver = (isVictory) {
      _lastVictory = isVictory;
      _lastWaves = game.waveSystem.currentWave;
      _lastSpiritEarned = game.economy.stoneSpirit;
      _lastEnemiesKilled = game.enemiesKilled;
      _lastTowersPlaced = game.towersPlaced;

      // Persist
      _saveManager!.addStoneSpirit(_lastSpiritEarned);
      _saveManager!.incrementRuns();
      _saveManager!.addKills(_lastEnemiesKilled);
      _saveManager!.updateBestWave(_lastWaves);

      if (mounted) setState(() => _screen = AppScreen.death);
    };

    setState(() {
      _game = game;
      _screen = AppScreen.game;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_saveLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A150E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFBA7517))),
      );
    }

    switch (_screen) {
      case AppScreen.mainMenu:
        return MainMenu(
          onPlay: _goToRunSetup,
          onMeta: _goToMeta,
          onSettings: _goToSettings,
          stoneSpirit: _saveManager!.stoneSpirit,
          totalRuns: _saveManager!.totalRuns,
          bestWave: _saveManager!.bestWave,
          totalKills: _saveManager!.totalKills,
        );

      case AppScreen.runSetup:
        final choices = ArtifactData.rollChoices(seed: DateTime.now().millisecondsSinceEpoch);
        return RunSetup(
          artifactChoices: choices,
          maxArtifacts: 3,
          selectedDifficulty: DifficultyTier.apprentice,
          unlockedDifficulties: _unlockedDifficulties(),
          weeklyMutations: MutationSystem.getWeeklyMutations(),
          onStart: _startGame,
          onBack: _goToMainMenu,
        );

      case AppScreen.game:
        return _buildGameScreen();

      case AppScreen.meta:
        return MetaScreen(
          stoneSpirit: _saveManager!.stoneSpirit,
          totalRuns: _saveManager!.totalRuns,
          unlockedLevels: {
            'savas': _saveManager!.metaSavas,
            'kesif': _saveManager!.metaKesif,
            'kale': _saveManager!.metaKale,
            'efsane': _saveManager!.metaEfsane,
          },
          onUnlock: (treeId, index) async {
            final tree = MetaTree.trees.firstWhere((t) => t.id == treeId);
            final node = tree.nodes[index];
            await _saveManager!.unlockMetaNode(treeId, cost: node.cost);
            setState(() {});
          },
          onBack: _goToMainMenu,
        );

      case AppScreen.settings:
        return SettingsScreen(
          soundEnabled: _saveManager!.soundEnabled,
          musicEnabled: _saveManager!.musicEnabled,
          onSoundChanged: (v) => _saveManager!.setSoundEnabled(v),
          onMusicChanged: (v) => _saveManager!.setMusicEnabled(v),
          onBack: _goToMainMenu,
        );

      case AppScreen.death:
        return DeathScreen(
          isVictory: _lastVictory,
          wavesCompleted: _lastWaves,
          totalWaves: _game?.difficulty.totalWaves ?? 20,
          spiritEarned: _lastSpiritEarned,
          totalSpirit: _saveManager!.stoneSpirit,
          towersPlaced: _lastTowersPlaced,
          enemiesKilled: _lastEnemiesKilled,
          totalDamageDealt: _game?.totalDamageDealt ?? 0,
          difficultyName: _game?.difficulty.name ?? '',
          onContinue: _goToRunSetup,
          onMainMenu: _goToMainMenu,
        );
    }
  }

  Widget _buildGameScreen() {
    final game = _game;
    if (game == null) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        GameWidget(game: game),
        // HUD overlay (only after game is loaded)
        if (game.isReady) GameHud(
          castleHp: game.castle.hp,
          maxCastleHp: game.castle.maxHp,
          gold: game.economy.gold,
          currentWave: game.waveSystem.currentWave,
          totalWaves: game.difficulty.totalWaves,
          availableTowers: game.availableTowers,
          selectedTower: game.selectedTowerType,
          isWaveActive: game.phase == GamePhase.waveActive,
          towerSlots: game.towerSlots,
          towersPlaced: game.towersPlaced,
          activeSynergies: game.activeSynergyNames,
          selectedPlacedTower: game.selectedPlacedTower,
          onStartWave: () => game.startNextWave(),
          onPause: () {
            game.togglePause();
            setState(() {});
          },
          onTowerSelected: (type) {
            game.selectedTowerType = type;
            game.deselectPlacedTower();
            setState(() {});
          },
          onSellTower: () {
            game.sellSelectedTower();
            setState(() {});
          },
          onUpgradeTower: () {
            game.upgradeSelectedTower();
            setState(() {});
          },
          onToggleSpeed: () {
            game.toggleSpeed();
            setState(() {});
          },
          gameSpeed: game.gameSpeed,
        ),
        // Wave break overlay
        if (game.isReady && game.phase == GamePhase.waveBreak)
          WaveBreak(
            nextWave: game.waveSystem.currentWave + 1,
            totalWaves: game.difficulty.totalWaves,
            gold: game.economy.gold,
            timeRemaining: game.breakTimeRemaining,
            wavePreview: game.nextWavePreview,
            onStartNow: () => game.startNextWave(),
          ),
        // Pause overlay
        if (game.isReady && game.phase == GamePhase.paused)
          PauseOverlay(
            onResume: () {
              game.togglePause();
              setState(() {});
            },
            onMainMenu: () {
              _game = null;
              _goToMainMenu();
            },
          ),
      ],
    );
  }

  List<DifficultyTier> _unlockedDifficulties() {
    return DifficultyTier.values
        .where((d) => d.runsToUnlock <= _saveManager!.totalRuns)
        .toList();
  }
}
