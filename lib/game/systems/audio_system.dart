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

/// Centralized audio manager with player pooling, cooldowns, and overlap limiting.
class AudioSystem {
  static final AudioSystem instance = AudioSystem._();
  AudioSystem._();

  bool _soundEnabled = true;
  bool _initialized = false;
  double _volume = 0.7; // 0.0 - 1.0

  // Per-sound cooldowns to prevent audio thread overload
  final Map<GameSound, int> _lastPlayTime = {};

  // Different cooldown intervals per sound type (ms)
  static const Map<GameSound, int> _cooldownMs = {
    GameSound.towerFire: 80,      // was 50 — give more spacing
    GameSound.enemyHit: 80,       // was 60
    GameSound.enemyDeath: 60,     // was 40
    GameSound.goldEarn: 150,      // was 100
    GameSound.castleHit: 150,     // was 120
    GameSound.comboTrigger: 250,  // was 200
    GameSound.bossRoar: 500,     // boss spawn/death — prevent overlap
    GameSound.eliteSpawn: 200,   // elite spawn bursts
    GameSound.waveStart: 1000,   // prevent double-play
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

  // Overlap tracking: limit concurrent plays of the same sound
  final Map<GameSound, int> _activePlays = {};
  static const Map<GameSound, int> _maxOverlap = {
    GameSound.towerFire: 2,
    GameSound.enemyHit: 2,
    GameSound.enemyDeath: 2,
    GameSound.goldEarn: 1,
    GameSound.bossRoar: 1,
  };
  static const int _defaultMaxOverlap = 3;

  // Player pool to avoid creating new players per sound
  final List<AudioPlayer> _playerPool = [];
  static const int _maxPlayers = 8;
  int _nextPlayer = 0;

  // Track which sound each player is playing (for overlap counting)
  final List<GameSound?> _playerSounds = List.filled(_maxPlayers, null);

  // Background music
  AudioPlayer? _musicPlayer;
  bool _musicEnabled = true;
  double _musicVolume = 0.3;

  // Debug stats
  int _totalPlayed = 0;
  int _totalSkippedCooldown = 0;
  int _totalSkippedFrameLimit = 0;
  int _totalSkippedOverlap = 0;

  bool get soundEnabled => _soundEnabled;
  double get volume => _volume;

  /// Debug stats for overlay
  int get totalPlayed => _totalPlayed;
  int get totalSkipped => _totalSkippedCooldown + _totalSkippedFrameLimit + _totalSkippedOverlap;
  int get activePlayerCount {
    int count = 0;
    for (int i = 0; i < _playerPool.length; i++) {
      if (_playerSounds[i] != null) count++;
    }
    return count;
  }
  int get poolSize => _playerPool.length;

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
      final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _playerPool.add(player);

      // Listen for completion to update overlap tracking
      player.onPlayerComplete.listen((_) {
        if (i < _playerSounds.length) {
          final sound = _playerSounds[i];
          if (sound != null) {
            final count = _activePlays[sound] ?? 0;
            if (count > 0) _activePlays[sound] = count - 1;
            _playerSounds[i] = null;
          }
        }
      });
    }
  }

  void play(GameSound sound) {
    if (!_soundEnabled || !_initialized) {
      if (_totalPlayed == 0) {
        debugPrint('AudioSystem: play(${sound.name}) SKIPPED — enabled=$_soundEnabled init=$_initialized pool=${_playerPool.length}');
      }
      return;
    }
    final file = _soundFiles[sound];
    if (file == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Per-sound cooldown
    final last = _lastPlayTime[sound] ?? 0;
    final cooldown = _cooldownMs[sound] ?? _defaultCooldownMs;
    if (now - last < cooldown) {
      _totalSkippedCooldown++;
      return;
    }

    // Frame-level limit: prevent audio thread overload
    if (now - _lastFrameTime > 16) {
      // New frame (~60fps)
      _lastFrameTime = now;
      _soundsThisFrame = 0;
    }
    if (_soundsThisFrame >= _maxSoundsPerFrame) {
      _totalSkippedFrameLimit++;
      return;
    }

    // Overlap limit: don't play if too many of same sound are active
    final currentOverlap = _activePlays[sound] ?? 0;
    final maxOvl = _maxOverlap[sound] ?? _defaultMaxOverlap;
    if (currentOverlap >= maxOvl) {
      _totalSkippedOverlap++;
      return;
    }

    _soundsThisFrame++;
    _lastPlayTime[sound] = now;
    _activePlays[sound] = currentOverlap + 1;
    _totalPlayed++;
    _playAsset(file, sound);
  }

  void _playAsset(String fileName, GameSound sound) {
    try {
      final playerIdx = _nextPlayer;
      final player = _playerPool[playerIdx];
      _nextPlayer = (_nextPlayer + 1) % _maxPlayers;

      // If this player was still playing something, decrement its overlap count
      final prevSound = _playerSounds[playerIdx];
      if (prevSound != null) {
        final count = _activePlays[prevSound] ?? 0;
        if (count > 0) _activePlays[prevSound] = count - 1;
      }
      _playerSounds[playerIdx] = sound;

      // Stop previous sound to free the native player resource
      player.stop();
      player.play(AssetSource('audio/$fileName'), volume: _volume);
    } catch (e) {
      debugPrint('AudioSystem: play error: $e');
    }
  }

  /// Stop all active SFX players (call between waves or on pause).
  void stopAll() {
    for (int i = 0; i < _playerPool.length; i++) {
      _playerPool[i].stop();
      _playerSounds[i] = null;
    }
    _activePlays.clear();
  }

  /// Reset debug counters (call on new wave).
  void resetStats() {
    _totalPlayed = 0;
    _totalSkippedCooldown = 0;
    _totalSkippedFrameLimit = 0;
    _totalSkippedOverlap = 0;
  }

  void dispose() {
    stopMusic();
    for (int i = 0; i < _playerPool.length; i++) {
      _playerPool[i].dispose();
    }
    _playerPool.clear();
    _playerSounds.fillRange(0, _playerSounds.length, null);
    _activePlays.clear();
  }
}
