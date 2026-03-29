import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/kale_game.dart';
import 'game/data/game_config.dart';
import 'game/systems/mutation_system.dart';
import 'game/systems/spell_system.dart';
import 'game/systems/audio_system.dart';
import 'game/systems/tutorial_system.dart';
import 'game/data/t4_branch_data.dart';
import 'meta/artifact_system.dart';
import 'meta/meta_tree.dart';
import 'meta/achievements.dart';
import 'meta/save_manager.dart';
import 'screens/main_menu.dart';
import 'screens/run_setup.dart';
import 'screens/death_screen.dart';
import 'screens/meta_screen.dart';
import 'screens/game_hud.dart';
import 'screens/wave_break.dart';
import 'screens/pause_overlay.dart';
import 'screens/settings_screen.dart';
import 'screens/bestiary_screen.dart';
import 'screens/synergy_guide.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Orientation is enforced by AndroidManifest sensorLandscape
  // System UI mode set after first frame to avoid emulator rendering issues
  runApp(const KaleKronikleriApp());
  // Defer system chrome changes to avoid zero-size init
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  });
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

enum AppScreen { mainMenu, runSetup, game, meta, death, settings, bestiary, synergyGuide }

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
    debugPrint('KaleKronikleri: Loading save...');
    _saveManager = await SaveManager.create();
    // Sync audio settings from save
    AudioSystem.instance.setSoundEnabled(_saveManager!.soundEnabled);
    debugPrint('KaleKronikleri: Save loaded, showing main menu');
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
      initialScreenShakeEnabled: _saveManager!.screenShakeEnabled,
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
      // Check synergy-related achievements
      AchievementSystem.checkAll(_saveManager!);
    };

    game.onGameOver = (isVictory) {
      _lastVictory = isVictory;
      _lastWaves = game.waveSystem.currentWave;
      _lastSpiritEarned = game.economy.stoneSpirit;
      _lastEnemiesKilled = game.enemiesKilled;
      _lastTowersPlaced = game.towersPlaced;

      // Persist
      _saveManager!.addStoneSpirit(_lastSpiritEarned);
      _saveManager!.addSpiritEarned(_lastSpiritEarned);
      _saveManager!.incrementRuns();
      _saveManager!.addKills(_lastEnemiesKilled);
      _saveManager!.updateBestWave(_lastWaves);
      _saveManager!.addTowersPlaced(game.totalTowersPlacedThisRun);
      _saveManager!.addBossKills(game.bossesKilled);
      _saveManager!.updateBestPerfectWaves(game.bestPerfectWaves);

      // Update best difficulty on victory
      if (isVictory) {
        _saveManager!.updateBestDifficulty(game.difficulty.index);
      }

      // Check achievements
      AchievementSystem.checkAll(_saveManager!);

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
      return Scaffold(
        backgroundColor: const Color(0xFF1A150E),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/ui/loading_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            Container(color: const Color(0x66000000)),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFBA7517)),
                  SizedBox(height: 16),
                  Text(
                    'KALE KRONIKLERI',
                    style: TextStyle(
                      color: Color(0xFFD4A843),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        final kesif = _saveManager!.metaKesif;
        final efsane = _saveManager!.metaEfsane;
        final improved = kesif >= 5; // Bilge Göz: better artifact quality
        final extraChoice = efsane >= 5; // Kader Yazıcı: +1 artifact choice
        final choices = ArtifactData.rollChoices(
          seed: DateTime.now().millisecondsSinceEpoch,
          improved: improved,
        );
        return RunSetup(
          artifactChoices: extraChoice ? [...choices, ...ArtifactData.rollChoices(seed: DateTime.now().millisecondsSinceEpoch + 1, improved: improved)] : choices,
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
            AchievementSystem.checkAll(_saveManager!);
            setState(() {});
          },
          onBack: _goToMainMenu,
        );

      case AppScreen.settings:
        return SettingsScreen(
          soundEnabled: _saveManager!.soundEnabled,
          musicEnabled: _saveManager!.musicEnabled,
          screenShakeEnabled: _saveManager!.screenShakeEnabled,
          onSoundChanged: (v) {
            _saveManager!.setSoundEnabled(v);
            AudioSystem.instance.setSoundEnabled(v);
          },
          onMusicChanged: (v) => _saveManager!.setMusicEnabled(v),
          onScreenShakeChanged: (v) {
            _saveManager!.setScreenShakeEnabled(v);
            _game?.screenShake.enabled = v;
          },
          onBack: _goToMainMenu,
        );

      case AppScreen.death:
        return DeathScreen(
          isVictory: _lastVictory,
          wavesCompleted: _lastWaves,
          totalWaves: _game?.waveSystem.totalWaves ?? 20,
          spiritEarned: _lastSpiritEarned,
          totalSpirit: _saveManager!.stoneSpirit,
          towersPlaced: _lastTowersPlaced,
          enemiesKilled: _lastEnemiesKilled,
          totalDamageDealt: _game?.totalDamageDealt ?? 0,
          difficultyName: _game?.difficulty.displayName ?? '',
          activeSynergies: _game?.activeSynergyNames ?? [],
          onContinue: _goToRunSetup,
          onMainMenu: _goToMainMenu,
        );

      case AppScreen.bestiary:
        return BestiaryScreen(
          onBack: () => setState(() => _screen = AppScreen.game),
        );

      case AppScreen.synergyGuide:
        return SynergyGuide(
          onBack: () => setState(() => _screen = AppScreen.game),
          discoveredSynergies: _game?.activeSynergyNames ?? [],
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
          totalWaves: game.waveSystem.totalWaves,
          availableTowers: game.availableTowers,
          selectedTower: game.selectedTowerType,
          isWaveActive: game.phase == GamePhase.waveActive,
          towerSlots: game.towerSlots,
          towersPlaced: game.towersPlaced,
          enemiesAlive: game.enemiesAlive,
          enemiesKilled: game.enemiesKilled,
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
            game.updatePlacementHighlight();
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
          secondaryShield: game.secondaryShield,
          maxSecondaryShield: game.maxSecondaryShield,
          showSynergyHints: game.showSynergyHints,
          autoWave: game.autoWave,
          onToggleAutoWave: () {
            game.toggleAutoWave();
            setState(() {});
          },
          onCycleTargeting: () {
            game.cycleSelectedTowerTargeting();
            setState(() {});
          },
          waveEnemyTotal: game.waveEnemyTotal,
          availableSpells: game.availableSpells,
          spellCooldowns: {
            for (final s in SpellType.values) s: game.spellCooldown(s),
          },
          spellMaxCooldowns: {
            for (final s in SpellType.values) s: game.spellMaxCooldown(s),
          },
          onCastSpell: (spell) {
            game.castSpell(spell);
            setState(() {});
          },
          pendingT4Tower: game.pendingT4Tower,
          onT4BranchSelected: (path) {
            game.selectT4Branch(path);
            setState(() {});
          },
          onT4Cancel: () {
            game.cancelT4Selection();
            setState(() {});
          },
          tutorialMessage: game.tutorialSystem.currentHint?.message,
          onDismissTutorial: () {
            game.tutorialSystem.dismiss();
            setState(() {});
          },
        ),
        // Wave break overlay
        if (game.isReady && game.phase == GamePhase.waveBreak)
          WaveBreak(
            nextWave: game.waveSystem.currentWave + 1,
            totalWaves: game.waveSystem.totalWaves,
            gold: game.economy.gold,
            timeRemaining: game.breakTimeRemaining,
            wavePreview: game.nextWavePreview,
            onStartNow: () => game.startNextWave(),
            showEnemyWeakness: game.showEnemyWeakness,
            loreMessage: _getLoreMessage(game.waveSystem.currentWave + 1),
            currentEvent: game.currentEvent,
            merchantAvailable: game.merchantAvailable,
            onAcceptMerchant: () {
              game.acceptMerchantEvent();
              setState(() {});
            },
            onDismissEvent: () {
              game.dismissEvent();
              setState(() {});
            },
            showEndlessPrompt: game.showEndlessPrompt,
            onContinueEndless: () {
              game.continueToEndless();
              setState(() {});
            },
            onDeclineEndless: () {
              game.declineEndless();
            },
            pathCount: game.gameMap.enemyPaths.length,
            nextWavePattern: game.nextWavePathPattern,
          ),
        // Pause overlay
        if (game.isReady && game.phase == GamePhase.paused)
          PauseOverlay(
            onResume: () {
              game.togglePause();
              setState(() {});
            },
            onBestiary: () {
              setState(() => _screen = AppScreen.bestiary);
            },
            onSynergyGuide: () {
              setState(() => _screen = AppScreen.synergyGuide);
            },
            onMainMenu: () {
              _game = null;
              _goToMainMenu();
            },
          ),
      ],
    );
  }

  static const Map<int, String> _loreMessages = {
    5: 'Troller ormandan çıktı... Dikkatli ol!',
    10: 'Gölge Lord\'u uyanıyor. Karanlık yaklaşıyor.',
    15: 'Karanlık şövalyeler kalenin kapısına dayandı!',
    20: 'Ejderha İmparatoru geliyor... Son savaş başlıyor!',
    25: 'Gölgeler yeniden toplandı. Bu sefer daha güçlüler.',
    30: 'Karanlığın kalbi atıyor. Sonunu getir!',
    35: 'Efsanevi güçler savaş alanını kaplıyor...',
    40: 'Kader anı geldi. Kalen sonsuza dek hatırlanacak!',
  };

  static String? _getLoreMessage(int nextWave) {
    return _loreMessages[nextWave];
  }

  List<DifficultyTier> _unlockedDifficulties() {
    return DifficultyTier.values
        .where((d) => d.runsToUnlock <= _saveManager!.totalRuns)
        .toList();
  }
}
