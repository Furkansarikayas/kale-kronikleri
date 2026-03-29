import 'dart:typed_data';
import 'dart:math' as math;
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
}

/// Centralized audio manager with procedural WAV generation.
/// No external audio files needed — all sounds are synthesized at startup.
class AudioSystem {
  static final AudioSystem instance = AudioSystem._();
  AudioSystem._();

  bool _soundEnabled = true;
  bool _initialized = false;

  final Map<GameSound, Uint8List> _wavCache = {};

  // Throttle: prevent same sound from playing too rapidly
  final Map<GameSound, int> _lastPlayTime = {};
  static const int _minIntervalMs = 80; // min ms between same sound

  // Player pool to avoid creating new players per sound
  final List<AudioPlayer> _playerPool = [];
  static const int _maxPlayers = 8;
  int _nextPlayer = 0;

  bool get soundEnabled => _soundEnabled;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Create player pool
    for (int i = 0; i < _maxPlayers; i++) {
      _playerPool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }

    // Pre-generate all WAV data
    _generateAllSounds();
  }

  void _generateAllSounds() {
    _wavCache[GameSound.towerPlace] = _genWav(_sineWave(440, 0.1, 0.4));
    _wavCache[GameSound.towerSell] = _genWav(_sineWave(330, 0.12, 0.35, descending: true));
    _wavCache[GameSound.towerUpgrade] = _genWav(_chirp(400, 800, 0.18, 0.45));
    _wavCache[GameSound.towerFire] = _genWav(_noise(0.04, 0.2));
    _wavCache[GameSound.enemyHit] = _genWav(_noise(0.03, 0.15));
    _wavCache[GameSound.enemyDeath] = _genWav(_sineWave(200, 0.12, 0.3, descending: true));
    _wavCache[GameSound.bossRoar] = _genWav(_chirp(150, 80, 0.35, 0.5));
    _wavCache[GameSound.castleHit] = _genWav(_squareWave(120, 0.15, 0.4));
    _wavCache[GameSound.waveStart] = _genWav(_chirp(300, 600, 0.25, 0.4));
    _wavCache[GameSound.waveComplete] = _genWav(_fanfare([523, 659, 784], 0.1));
    _wavCache[GameSound.spellFireRain] = _genWav(_chirp(500, 200, 0.25, 0.4));
    _wavCache[GameSound.spellIceStorm] = _genWav(_filteredNoise(0.25, 0.3));
    _wavCache[GameSound.spellRepair] = _genWav(_chirp(350, 550, 0.2, 0.35));
    _wavCache[GameSound.comboTrigger] = _genWav(_chirp(600, 1000, 0.12, 0.45));
    _wavCache[GameSound.eliteSpawn] = _genWav(_squareWave(180, 0.15, 0.35));
    _wavCache[GameSound.eventMerchant] = _genWav(_fanfare([523, 659, 523], 0.08));
    _wavCache[GameSound.buttonClick] = _genWav(_sineWave(660, 0.04, 0.25));
    _wavCache[GameSound.victory] = _genWav(_fanfare([523, 587, 659, 784, 1047], 0.14));
    _wavCache[GameSound.defeat] = _genWav(_chirp(400, 100, 0.4, 0.45));
    _wavCache[GameSound.goldEarn] = _genWav(_sineWave(880, 0.06, 0.2));
    _wavCache[GameSound.t4Upgrade] = _genWav(_chirp(400, 1200, 0.25, 0.45));
  }

  void play(GameSound sound) {
    if (!_soundEnabled || !_initialized) return;
    final wav = _wavCache[sound];
    if (wav == null) return;

    // Throttle rapid repeated sounds
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastPlayTime[sound] ?? 0;
    if (now - last < _minIntervalMs) return;
    _lastPlayTime[sound] = now;

    _playBytes(wav);
  }

  void _playBytes(Uint8List wavData) {
    try {
      final player = _playerPool[_nextPlayer];
      _nextPlayer = (_nextPlayer + 1) % _maxPlayers;
      player.play(BytesSource(wavData, mimeType: 'audio/wav'), volume: 1.0);
    } catch (e) {
      debugPrint('AudioSystem: play error: $e');
    }
  }

  void dispose() {
    for (final player in _playerPool) {
      player.dispose();
    }
    _playerPool.clear();
  }

  // --- Procedural WAV Generation ---

  static const int _sampleRate = 22050;

  Uint8List _genWav(Float64List samples) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;

    final buffer = ByteData(fileSize);
    // RIFF header
    const riff = [0x52, 0x49, 0x46, 0x46]; // RIFF
    const wave = [0x57, 0x41, 0x56, 0x45]; // WAVE
    const fmt = [0x66, 0x6D, 0x74, 0x20]; // fmt
    const data = [0x64, 0x61, 0x74, 0x61]; // data

    for (int i = 0; i < 4; i++) buffer.setUint8(i, riff[i]);
    buffer.setUint32(4, fileSize - 8, Endian.little);
    for (int i = 0; i < 4; i++) buffer.setUint8(8 + i, wave[i]);
    for (int i = 0; i < 4; i++) buffer.setUint8(12 + i, fmt[i]);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(28, _sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    for (int i = 0; i < 4; i++) buffer.setUint8(36 + i, data[i]);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final sample = (samples[i].clamp(-1.0, 1.0) * 32767).toInt();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  Float64List _sineWave(double freq, double duration, double volume, {bool descending = false}) {
    final n = (_sampleRate * duration).toInt();
    final samples = Float64List(n);
    for (int i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final env = 1.0 - (i / n);
      final f = descending ? freq * (1.0 - 0.5 * i / n) : freq;
      samples[i] = math.sin(2 * math.pi * f * t) * volume * env;
    }
    return samples;
  }

  Float64List _squareWave(double freq, double duration, double volume) {
    final n = (_sampleRate * duration).toInt();
    final samples = Float64List(n);
    for (int i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final env = 1.0 - (i / n);
      final v = math.sin(2 * math.pi * freq * t) > 0 ? 1.0 : -1.0;
      samples[i] = v * volume * env * 0.5; // softer square
    }
    return samples;
  }

  Float64List _chirp(double freqStart, double freqEnd, double duration, double volume) {
    final n = (_sampleRate * duration).toInt();
    final samples = Float64List(n);
    double phase = 0;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final freq = freqStart + (freqEnd - freqStart) * t;
      final env = 1.0 - t * 0.8;
      phase += 2 * math.pi * freq / _sampleRate;
      samples[i] = math.sin(phase) * volume * env;
    }
    return samples;
  }

  Float64List _noise(double duration, double volume) {
    final rng = math.Random(42);
    final n = (_sampleRate * duration).toInt();
    final samples = Float64List(n);
    for (int i = 0; i < n; i++) {
      final env = 1.0 - (i / n);
      samples[i] = (rng.nextDouble() * 2 - 1) * volume * env;
    }
    return samples;
  }

  /// Filtered noise (softer, ice-like)
  Float64List _filteredNoise(double duration, double volume) {
    final rng = math.Random(99);
    final n = (_sampleRate * duration).toInt();
    final samples = Float64List(n);
    double prev = 0;
    for (int i = 0; i < n; i++) {
      final env = 1.0 - (i / n);
      final raw = (rng.nextDouble() * 2 - 1) * volume * env;
      prev = prev * 0.7 + raw * 0.3; // simple low-pass filter
      samples[i] = prev;
    }
    return samples;
  }

  /// Multiple ascending notes (fanfare/jingle)
  Float64List _fanfare(List<double> notes, double noteLen) {
    final total = (notes.length * noteLen * _sampleRate).toInt();
    final samples = Float64List(total);
    for (int n = 0; n < notes.length; n++) {
      final start = (n * noteLen * _sampleRate).toInt();
      final len = (noteLen * _sampleRate).toInt();
      for (int i = 0; i < len && start + i < total; i++) {
        final t = i / _sampleRate;
        final env = 1.0 - (i / len) * 0.6;
        samples[start + i] = math.sin(2 * math.pi * notes[n] * t) * 0.4 * env;
      }
    }
    return samples;
  }
}
