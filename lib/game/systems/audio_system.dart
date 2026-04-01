import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// All game sound effects.
enum GameSound {
  towerPlace,
  towerSell,
  towerUpgrade,
  towerFire,
  enemyHit,
  enemyDeath,
  bossRoar,
  castleHit,
  waveStart,
  waveComplete,
  spellFireRain,
  spellIceStorm,
  spellRepair,
  comboTrigger,
  eliteSpawn,
  eventMerchant,
  buttonClick,
  victory,
  defeat,
  goldEarn,
  t4Upgrade,
  towerMerge,
  // Tower ambient presence
  ambiCold,
  ambiHot,
  ambiElectric,
  ambiMystic,
}

/// Maps each GameSound to its asset file name.
const Map<GameSound, String> _soundFiles = {
  GameSound.towerPlace: 'tower_place.ogg',
  GameSound.towerSell: 'tower_sell.ogg',
  GameSound.towerUpgrade: 'tower_upgrade.ogg',
  GameSound.towerFire: 'tower_fire.ogg',
  GameSound.enemyHit: 'enemy_hit.ogg',
  GameSound.enemyDeath: 'enemy_death.ogg',
  GameSound.bossRoar: 'boss_roar.ogg',
  GameSound.castleHit: 'castle_hit.ogg',
  GameSound.waveStart: 'wave_start.ogg',
  GameSound.waveComplete: 'wave_complete.ogg',
  GameSound.spellFireRain: 'spell_fire_rain.ogg',
  GameSound.spellIceStorm: 'spell_ice_storm.ogg',
  GameSound.spellRepair: 'spell_repair.ogg',
  GameSound.comboTrigger: 'combo_trigger.ogg',
  GameSound.eliteSpawn: 'elite_spawn.ogg',
  GameSound.eventMerchant: 'event_merchant.ogg',
  GameSound.buttonClick: 'button_click.ogg',
  GameSound.victory: 'victory.ogg',
  GameSound.defeat: 'defeat.ogg',
  GameSound.goldEarn: 'gold_earn.ogg',
  GameSound.t4Upgrade: 't4_upgrade.ogg',
  GameSound.towerMerge: 'tower_merge.ogg',
  GameSound.ambiCold: 'ambi_cold.ogg',
  GameSound.ambiHot: 'ambi_hot.ogg',
  GameSound.ambiElectric: 'ambi_electric.ogg',
  GameSound.ambiMystic: 'ambi_mystic.ogg',
};

/// Centralized audio manager using real audio asset files.
class AudioSystem {
  static final AudioSystem instance = AudioSystem._();
  AudioSystem._();

  bool _soundEnabled = true;
  bool _initialized = false;
  double _volume = 0.7; // 0.0 - 1.0

  // Per-sound cooldowns to prevent audio thread overload
  final Map<GameSound, int> _lastPlayTime = {};

  // Different cooldown intervals per sound type
  static const Map<GameSound, int> _cooldownMs = {
    GameSound.towerFire: 50,
    GameSound.enemyHit: 60,
    GameSound.enemyDeath: 40,
    GameSound.goldEarn: 100,
    GameSound.castleHit: 120,
    GameSound.comboTrigger: 200,
    GameSound.ambiCold: 2000,
    GameSound.ambiHot: 2000,
    GameSound.ambiElectric: 2000,
    GameSound.ambiMystic: 2000,
  };
  static const int _defaultCooldownMs = 80;

  // Frame-level dedup: prevent identical sounds in same frame
  int _lastFrameTime = 0;
  int _soundsThisFrame = 0;
  static const int _maxSoundsPerFrame = 3;

  // Player pool to avoid creating new players per sound
  final List<AudioPlayer> _playerPool = [];
  static const int _maxPlayers = 8;
  int _nextPlayer = 0;

  // Background music
  AudioPlayer? _musicPlayer;
  bool _musicEnabled = true;
  double _musicVolume = 0.3;

  bool get soundEnabled => _soundEnabled;
  double get volume => _volume;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
  }

  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _musicPlayer?.stop();
    } else {
      startMusic();
    }
  }

  void setMusicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    _musicPlayer?.setVolume(_musicVolume);
  }

  /// Start looping background music from asset file.
  Future<void> startMusic() async {
    if (!_musicEnabled || !_initialized) return;
    // Stop existing music if any to prevent leaking players
    if (_musicPlayer != null) {
      _musicPlayer!.stop();
      _musicPlayer!.dispose();
      _musicPlayer = null;
    }

    _musicPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
    try {
      await _musicPlayer!.play(
        AssetSource('audio/background_music.ogg'),
        volume: _musicVolume,
      );
    } catch (e) {
      debugPrint('AudioSystem: music error: $e');
    }
  }

  void stopMusic() {
    _musicPlayer?.stop();
    _musicPlayer?.dispose();
    _musicPlayer = null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Create player pool
    for (int i = 0; i < _maxPlayers; i++) {
      _playerPool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }
  }

  void play(GameSound sound) {
    if (!_soundEnabled || !_initialized) return;
    final file = _soundFiles[sound];
    if (file == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Per-sound cooldown
    final last = _lastPlayTime[sound] ?? 0;
    final cooldown = _cooldownMs[sound] ?? _defaultCooldownMs;
    if (now - last < cooldown) return;

    // Frame-level limit: prevent audio thread overload
    if (now - _lastFrameTime > 16) {
      // New frame (~60fps)
      _lastFrameTime = now;
      _soundsThisFrame = 0;
    }
    if (_soundsThisFrame >= _maxSoundsPerFrame) return;
    _soundsThisFrame++;

    _lastPlayTime[sound] = now;
    _playAsset(file);
  }

  void _playAsset(String fileName) {
    try {
      final player = _playerPool[_nextPlayer];
      _nextPlayer = (_nextPlayer + 1) % _maxPlayers;
      // Stop previous sound to free the native player resource
      player.stop();
      player.play(AssetSource('audio/$fileName'), volume: _volume);
    } catch (e) {
      debugPrint('AudioSystem: play error: $e');
    }
  }

  void dispose() {
    stopMusic();
    for (final player in _playerPool) {
      player.dispose();
    }
    _playerPool.clear();
  }
}
