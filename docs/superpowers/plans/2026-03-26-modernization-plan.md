# Kale Kronikleri 2026 Modernizasyon — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kale Kronikleri'ni Canvas çizimlerinden sprite tabanlı, modern görünümlü bir 2026 oyununa dönüştürmek — glassmorphism UI, biome sistemi, parallax arka plan, zengin efektler dahil.

**Architecture:** Mevcut Flame engine altyapısı korunur. Tüm custom `render()` metodları sprite tabanlı render ile değiştirilir. Sprite'lar başlangıçta yüksek kaliteli prosedürel olarak üretilip cache'lenir (mevcut SpriteCache paterni genişletilir), sonra PNG dosyalarıyla değiştirilebilir yapıda olur. UI katmanı Flutter widget'ları ile glassmorphism'e geçer. Biome sistemi DifficultyTier'a bağlanır.

**Tech Stack:** Flutter 3.11+, Flame 1.22.0, Dart Canvas API (sprite generation), BackdropFilter (glassmorphism), SpriteAnimationComponent (animasyonlar)

---

## Chunk 1: Asset Altyapısı & Sprite Manager

### Task 1: Asset dizin yapısını oluştur

**Files:**
- Create: `assets/images/towers/.gitkeep`
- Create: `assets/images/enemies/.gitkeep`
- Create: `assets/images/castle/.gitkeep`
- Create: `assets/images/maps/forest/.gitkeep`
- Create: `assets/images/maps/desert/.gitkeep`
- Create: `assets/images/maps/snow/.gitkeep`
- Create: `assets/images/maps/volcano/.gitkeep`
- Create: `assets/images/maps/dark/.gitkeep`
- Create: `assets/images/effects/.gitkeep`
- Create: `assets/images/ui/.gitkeep`
- Create: `assets/images/backgrounds/.gitkeep`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Dizin yapısını oluştur**

```bash
mkdir -p assets/images/{towers,enemies,castle,maps/{forest,desert,snow,volcano,dark},effects,ui,backgrounds}
touch assets/images/{towers,enemies,castle,maps/forest,maps/desert,maps/snow,maps/volcano,maps/dark,effects,ui,backgrounds}/.gitkeep
```

- [ ] **Step 2: pubspec.yaml'a asset path'leri ekle**

`pubspec.yaml` dosyasının `flutter:` bölümüne ekle:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/towers/
    - assets/images/enemies/
    - assets/images/castle/
    - assets/images/maps/forest/
    - assets/images/maps/desert/
    - assets/images/maps/snow/
    - assets/images/maps/volcano/
    - assets/images/maps/dark/
    - assets/images/effects/
    - assets/images/ui/
    - assets/images/backgrounds/
```

- [ ] **Step 3: Commit**

```bash
git add assets/ pubspec.yaml
git commit -m "chore: add asset directory structure for sprite-based rendering"
```

---

### Task 2: Sprite Manager oluştur

**Files:**
- Create: `lib/game/components/rendering/sprite_manager.dart`

Bu dosya merkezi sprite yönetimini sağlar. Önce asset klasöründe PNG arar, bulamazsa prosedürel sprite üretir. Böylece ileride PNG dosyaları eklenmesiyle otomatik geçiş olur.

- [ ] **Step 1: SpriteManager sınıfını yaz**

```dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import 'sprite_cache.dart';

/// Merkezi sprite yönetimi.
/// Önce assets/images/ altında PNG arar, bulamazsa prosedürel üretir.
class SpriteManager {
  static final SpriteManager instance = SpriteManager._();
  SpriteManager._();

  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Sprite> _spriteCache = {};
  final Map<String, SpriteAnimation> _animationCache = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Tüm sprite'ları yükle veya üret.
  Future<void> initialize() async {
    if (_initialized) return;

    // Mevcut tile sprite cache'i koru
    await SpriteCache.instance.initialize();

    _initialized = true;
  }

  /// Tek bir sprite al. Önce asset'te arar, yoksa prosedürel üretir.
  Future<Sprite> getSprite(String key, {
    Future<ui.Image> Function()? fallbackGenerator,
  }) async {
    if (_spriteCache.containsKey(key)) {
      return _spriteCache[key]!;
    }

    // Önce asset'te ara
    try {
      final image = await Flame.images.load('$key.png');
      final sprite = Sprite(image);
      _spriteCache[key] = sprite;
      return sprite;
    } catch (_) {
      // Asset bulunamadı, prosedürel üret
      if (fallbackGenerator != null) {
        final image = await fallbackGenerator();
        _imageCache[key] = image;
        final sprite = Sprite(image);
        _spriteCache[key] = sprite;
        return sprite;
      }
      throw Exception('Sprite not found and no fallback: $key');
    }
  }

  /// Sprite animation al (sprite sheet'ten).
  Future<SpriteAnimation> getAnimation(String key, {
    required int frameCount,
    required double stepTime,
    required Vector2 textureSize,
    Future<ui.Image> Function()? fallbackGenerator,
  }) async {
    if (_animationCache.containsKey(key)) {
      return _animationCache[key]!;
    }

    try {
      final image = await Flame.images.load('$key.png');
      final animation = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: frameCount,
          stepTime: stepTime,
          textureSize: textureSize,
        ),
      );
      _animationCache[key] = animation;
      return animation;
    } catch (_) {
      if (fallbackGenerator != null) {
        final image = await fallbackGenerator();
        _imageCache[key] = image;
        final animation = SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.sequenced(
            amount: frameCount,
            stepTime: stepTime,
            textureSize: textureSize,
          ),
        );
        _animationCache[key] = animation;
        return animation;
      }
      throw Exception('Animation not found and no fallback: $key');
    }
  }

  /// Cache'i temizle
  void dispose() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    _spriteCache.clear();
    _animationCache.clear();
    _initialized = false;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/game/components/rendering/sprite_manager.dart
git commit -m "feat: add SpriteManager for centralized sprite loading with PNG fallback"
```

---

## Chunk 2: Biome Sistemi & Harita Yenileme

### Task 3: Biome data tanımla

**Files:**
- Create: `lib/game/components/map/biome_data.dart`
- Modify: `lib/game/data/game_config.dart` — DifficultyTier'a biome mapping ekle

- [ ] **Step 1: BiomeData sınıfını yaz**

```dart
import 'dart:ui';

enum BiomeType { forest, desert, snow, volcano, dark }

class BiomeData {
  final BiomeType type;
  final String name;
  final Color groundBase;
  final Color groundAccent;
  final Color pathBase;
  final Color pathAccent;
  final Color skyTop;
  final Color skyBottom;
  final Color fogColor;
  final Color ambientLight;
  final List<Color> decorationColors;

  const BiomeData({
    required this.type,
    required this.name,
    required this.groundBase,
    required this.groundAccent,
    required this.pathBase,
    required this.pathAccent,
    required this.skyTop,
    required this.skyBottom,
    required this.fogColor,
    required this.ambientLight,
    required this.decorationColors,
  });

  static const BiomeData forest = BiomeData(
    type: BiomeType.forest,
    name: 'Orman',
    groundBase: Color(0xFF1a3a18),
    groundAccent: Color(0xFF2a5a25),
    pathBase: Color(0xFF3a3025),
    pathAccent: Color(0xFF4a4035),
    skyTop: Color(0xFF050510),
    skyBottom: Color(0xFF0f1a12),
    fogColor: Color(0x08AABBCC),
    ambientLight: Color(0xFF0a1a0a),
    decorationColors: [Color(0xFF2a5a25), Color(0xFF1a4a18), Color(0xFF3a6a30)],
  );

  static const BiomeData desert = BiomeData(
    type: BiomeType.desert,
    name: 'Çöl',
    groundBase: Color(0xFF4a3a20),
    groundAccent: Color(0xFF6a5a38),
    pathBase: Color(0xFF5a4a30),
    pathAccent: Color(0xFF7a6a48),
    skyTop: Color(0xFF0a0510),
    skyBottom: Color(0xFF1a1008),
    fogColor: Color(0x08DDBB88),
    ambientLight: Color(0xFF1a1008),
    decorationColors: [Color(0xFF6a5a38), Color(0xFF8a7a58), Color(0xFF4a3a20)],
  );

  static const BiomeData snow = BiomeData(
    type: BiomeType.snow,
    name: 'Kar',
    groundBase: Color(0xFF2a3a4a),
    groundAccent: Color(0xFF4a5a6a),
    pathBase: Color(0xFF3a3a4a),
    pathAccent: Color(0xFF5a5a6a),
    skyTop: Color(0xFF050510),
    skyBottom: Color(0xFF101828),
    fogColor: Color(0x10CCDDEE),
    ambientLight: Color(0xFF0a1020),
    decorationColors: [Color(0xFF5a6a7a), Color(0xFF7a8a9a), Color(0xFFaabbcc)],
  );

  static const BiomeData volcano = BiomeData(
    type: BiomeType.volcano,
    name: 'Volkan',
    groundBase: Color(0xFF2a1a15),
    groundAccent: Color(0xFF3a2a20),
    pathBase: Color(0xFF3a2520),
    pathAccent: Color(0xFF4a3530),
    skyTop: Color(0xFF100505),
    skyBottom: Color(0xFF1a0a08),
    fogColor: Color(0x10FF4400),
    ambientLight: Color(0xFF1a0808),
    decorationColors: [Color(0xFF5a2a20), Color(0xFFaa4420), Color(0xFF882200)],
  );

  static const BiomeData dark = BiomeData(
    type: BiomeType.dark,
    name: 'Karanlık Diyar',
    groundBase: Color(0xFF15101a),
    groundAccent: Color(0xFF201828),
    pathBase: Color(0xFF201520),
    pathAccent: Color(0xFF302530),
    skyTop: Color(0xFF030308),
    skyBottom: Color(0xFF0a0512),
    fogColor: Color(0x108800FF),
    ambientLight: Color(0xFF080510),
    decorationColors: [Color(0xFF301a40), Color(0xFF5020a0), Color(0xFF8040c0)],
  );

  /// DifficultyTier'dan biome al
  static BiomeData fromDifficulty(String difficultyName) {
    switch (difficultyName) {
      case 'apprentice': return forest;
      case 'knight': return desert;
      case 'lord': return snow;
      case 'king': return volcano;
      case 'legend': return dark;
      default: return forest;
    }
  }
}
```

- [ ] **Step 2: GameConfig'e biome mapping ekle**

`lib/game/data/game_config.dart` dosyasında `DifficultyTier` enum'una biome field'ı ekle:

```dart
// Import ekle
import '../components/map/biome_data.dart';

// DifficultyTier enum'una biomeType parametresi ekle
enum DifficultyTier {
  apprentice(totalWaves: 20, hpMultiplier: 1.0, speedMultiplier: 1.0, spiritMultiplier: 1.0, runsToUnlock: 0, biomeType: BiomeType.forest),
  knight(totalWaves: 25, hpMultiplier: 1.2, speedMultiplier: 1.0, spiritMultiplier: 1.5, runsToUnlock: 5, biomeType: BiomeType.desert),
  lord(totalWaves: 30, hpMultiplier: 1.4, speedMultiplier: 1.2, spiritMultiplier: 2.5, runsToUnlock: 10, biomeType: BiomeType.snow),
  king(totalWaves: 35, hpMultiplier: 1.6, speedMultiplier: 1.0, spiritMultiplier: 4.0, runsToUnlock: 20, biomeType: BiomeType.volcano),
  legend(totalWaves: 40, hpMultiplier: 2.0, speedMultiplier: 1.5, spiritMultiplier: 8.0, runsToUnlock: 40, biomeType: BiomeType.dark);

  final int totalWaves;
  final double hpMultiplier;
  final double speedMultiplier;
  final double spiritMultiplier;
  final int runsToUnlock;
  final BiomeType biomeType;

  const DifficultyTier({
    required this.totalWaves,
    required this.hpMultiplier,
    required this.speedMultiplier,
    required this.spiritMultiplier,
    required this.runsToUnlock,
    required this.biomeType,
  });

  BiomeData get biome => BiomeData.fromDifficulty(name);
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/map/biome_data.dart lib/game/data/game_config.dart
git commit -m "feat: add biome system with 5 biomes mapped to difficulty tiers"
```

---

### Task 4: SpriteCache'i biome destekli yap

**Files:**
- Modify: `lib/game/components/rendering/sprite_cache.dart`

Mevcut SpriteCache zaten prosedürel tile üretiyor (128x128). Biome renk paletlerini alacak şekilde genişlet. Her biome için farklı tile variant'ları üretilecek.

- [ ] **Step 1: SpriteCache'e biome parametresi ekle**

`sprite_cache.dart` dosyasında `initialize()` metodunu biome alacak şekilde değiştir:

```dart
// Mevcut: Future<void> initialize() async
// Yeni:
BiomeData _currentBiome = BiomeData.forest;

Future<void> initialize({BiomeData? biome}) async {
  _currentBiome = biome ?? BiomeData.forest;
  _cache.clear();
  _initialized = false;
  // Mevcut tile generation kodunu _currentBiome renklerini kullanacak şekilde güncelle
  // ...
  _initialized = true;
}
```

Tüm hardcoded renkleri `_currentBiome` renklerini kullanacak şekilde değiştir:
- Grass tile'lar: `_currentBiome.groundBase`, `_currentBiome.groundAccent`
- Path tile'lar: `_currentBiome.pathBase`, `_currentBiome.pathAccent`
- Blocked tile'lar: biome-spesifik dekorasyon renkleri
- Spawn tile: aynı kalsın (kırmızı rune her yerde aynı)

- [ ] **Step 2: GridCell'de grid gizleme**

`lib/game/components/map/grid_cell.dart` dosyasında grid çizgilerini kaldır. Normal durumda hücreler arası çizgi olmasın. Sadece highlight durumunda (kule yerleştirme) hafif border gösterilsin.

Mevcut highlight rendering'de (`_renderHighlight`) border'ı daha subtle yap:

```dart
// Mevcut kalın çerçeveyi → ince, yarı saydam çizgiyle değiştir
final borderPaint = Paint()
  ..color = const Color(0x3300FF44) // çok hafif yeşil
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.0;
```

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/rendering/sprite_cache.dart lib/game/components/map/grid_cell.dart
git commit -m "feat: biome-aware tile generation and subtle grid display"
```

---

### Task 5: MapGenerator'a biome dekorasyon ekle

**Files:**
- Modify: `lib/game/components/map/map_generator.dart`
- Modify: `lib/game/components/map/game_map.dart`

- [ ] **Step 1: MapGenerator'a biome-spesifik blocked variant seçimi ekle**

Mevcut blocked cell'ler rastgele orman dekorasyonu. Biome'a göre farklı variant isimleri kullanılacak:
- forest: pine, rock, bush, dead_tree (mevcut)
- desert: cactus, sand_rock, skull, dry_bush
- snow: ice_crystal, snow_pile, frozen_tree, ice_rock
- volcano: lava_rock, ash_pile, crystal, fire_vent
- dark: purple_crystal, bone_pile, dark_tree, shadow_pool

SpriteCache'e bu variant'ların prosedürel üretimini ekle.

- [ ] **Step 2: GameMap'e biome geçir**

`game_map.dart` dosyasında initialize sırasında biome bilgisini al ve SpriteCache'e ilet:

```dart
Future<void> initializeMap(int seed, {BiomeData? biome}) async {
  await SpriteCache.instance.initialize(biome: biome);
  // ... mevcut map generation kodu
}
```

- [ ] **Step 3: KaleGame'den biome bilgisini GameMap'e geçir**

`kale_game.dart` dosyasında `onLoad()` içinde:

```dart
// Mevcut difficulty tier'dan biome al
final biome = _difficulty.biome;
await gameMap.initializeMap(seed, biome: biome);
```

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/map/map_generator.dart lib/game/components/map/game_map.dart lib/game/kale_game.dart
git commit -m "feat: biome-specific map generation with difficulty-based biome selection"
```

---

## Chunk 3: Kule Sprite Dönüşümü

### Task 6: Kule sprite üretici oluştur

**Files:**
- Create: `lib/game/components/rendering/tower_sprites.dart`

Mevcut tower.dart render() metodu (lines 111-344) çok detaylı Canvas çizimi yapıyor. Bu çizimleri 256x256 boyutunda yüksek kaliteli sprite'lara dönüştür ve cache'le. Her kule tipi × 4 tier = 48 sprite üretilecek.

- [ ] **Step 1: TowerSpriteGenerator sınıfını yaz**

```dart
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/tower_data.dart';

class TowerSpriteGenerator {
  static final TowerSpriteGenerator instance = TowerSpriteGenerator._();
  TowerSpriteGenerator._();

  final Map<String, ui.Image> _cache = {};
  static const int spriteSize = 256;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    for (final type in TowerType.values) {
      for (int tier = 1; tier <= 4; tier++) {
        final key = '${type.name}_t$tier';
        _cache[key] = await _generateTowerSprite(type, tier);
      }
    }
    _initialized = true;
  }

  ui.Image? getSprite(TowerType type, int tier) {
    return _cache['${type.name}_t$tier'];
  }

  Future<ui.Image> _generateTowerSprite(TowerType type, int tier) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = spriteSize.toDouble();

    _drawTower(canvas, size, type, tier);

    final picture = recorder.endRecording();
    return picture.toImage(spriteSize, spriteSize);
  }

  void _drawTower(Canvas canvas, double size, TowerType type, int tier) {
    final stats = TowerData.stats[type]!;
    final color = _getTowerColor(type);
    final glowColor = _getTowerGlowColor(type);

    // Tüm çizimler 256x256 scale'de yapılacak (40px → 256px = 6.4x scale)
    // Mevcut tower.dart render() mantığının geliştirilmiş versiyonu:

    // 1. Platform shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size / 2, size * 0.88), width: size * 0.7, height: size * 0.12),
      shadowPaint,
    );

    // 2. Stone platform with detailed brick
    _drawPlatform(canvas, size, tier);

    // 3. Tower body with lighting
    _drawBody(canvas, size, color, type, tier);

    // 4. Tower top element (flame, crystal, orb, etc.)
    _drawTopElement(canvas, size, type, glowColor, tier);

    // 5. Tier indicator stars
    _drawTierStars(canvas, size, tier);
  }

  void _drawPlatform(Canvas canvas, double size, int tier) {
    // Detaylı taş platform - tuğla dokusu, 3D kenarlar
    final platformRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size * 0.12, size * 0.75, size * 0.76, size * 0.15),
      const Radius.circular(4),
    );

    // Platform gradient
    final platformPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size * 0.12, size * 0.75),
        Offset(size * 0.12, size * 0.9),
        [const Color(0xFF7a7a7a), const Color(0xFF4a4a4a)],
      );
    canvas.drawRRect(platformRect, platformPaint);

    // Platform highlight (top edge)
    final highlightPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size * 0.14, size * 0.76),
      Offset(size * 0.86, size * 0.76),
      highlightPaint,
    );

    // Brick pattern
    final brickPaint = Paint()
      ..color = const Color(0x15000000)
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = size * 0.78 + i * size * 0.04;
      canvas.drawLine(Offset(size * 0.14, y), Offset(size * 0.86, y), brickPaint);
    }
  }

  void _drawBody(Canvas canvas, double size, Color color, TowerType type, int tier) {
    if (type == TowerType.spikeWall) {
      _drawSpikeWallBody(canvas, size, tier);
      return;
    }
    if (type == TowerType.support) {
      _drawSupportBody(canvas, size, tier);
      return;
    }

    // Ana kule gövdesi
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size * 0.22, size * 0.25, size * 0.56, size * 0.52),
      const Radius.circular(6),
    );

    // Gövde gradient (3D efekt)
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size * 0.22, size * 0.25),
        Offset(size * 0.78, size * 0.77),
        [
          Color.lerp(color, Colors.white, 0.3)!,
          color,
          Color.lerp(color, Colors.black, 0.4)!,
        ],
        [0.0, 0.4, 1.0],
      );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Sol ışık kenarı
    final leftHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size * 0.24, size * 0.28),
      Offset(size * 0.24, size * 0.74),
      leftHighlight,
    );

    // Pencere detayları
    _drawWindows(canvas, size, color);

    // Mazgallar (crenellations)
    _drawCrenellations(canvas, size, color, tier);

    // Border
    final borderPaint = Paint()
      ..color = Color.lerp(color, Colors.white, 0.2)!.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(bodyRect, borderPaint);
  }

  void _drawWindows(Canvas canvas, double size, Color color) {
    final windowColor = Color.lerp(color, Colors.black, 0.6)!;
    final glowColor = Color.lerp(color, Colors.white, 0.5)!;

    for (final xOffset in [0.34, 0.58]) {
      final windowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(size * xOffset, size * 0.4, size * 0.08, size * 0.12),
        const Radius.circular(size * 0.04),
      );
      canvas.drawRRect(windowRect, Paint()..color = windowColor);

      // Inner glow
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(windowRect, glowPaint);
    }
  }

  void _drawCrenellations(Canvas canvas, double size, Color color, int tier) {
    final crenColor = Color.lerp(color, Colors.black, 0.2)!;
    final count = 4 + tier; // Tier arttıkça daha fazla mazgal
    final spacing = size * 0.56 / count;

    for (int i = 0; i < count; i++) {
      final x = size * 0.22 + i * spacing + spacing * 0.15;
      final rect = Rect.fromLTWH(x, size * 0.2, spacing * 0.6, size * 0.07);
      canvas.drawRect(rect, Paint()..color = crenColor);
    }
  }

  void _drawTopElement(Canvas canvas, double size, TowerType type, Color glowColor, int tier) {
    final center = Offset(size / 2, size * 0.18);
    final radius = size * 0.08 + tier * size * 0.01;

    // Outer glow
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 2);
    canvas.drawCircle(center, radius * 2.5, glowPaint);

    // Main orb
    final orbPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [Colors.white, glowColor, glowColor.withValues(alpha: 0.5)],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(center, radius, orbPaint);

    // Core highlight
    canvas.drawCircle(
      center + Offset(-radius * 0.2, -radius * 0.2),
      radius * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _drawSpikeWallBody(Canvas canvas, double size, int tier) {
    // Ahşap taban
    final baseRect = Rect.fromLTWH(size * 0.18, size * 0.55, size * 0.64, size * 0.22);
    canvas.drawRect(baseRect, Paint()..color = const Color(0xFF5a4020));

    // Metal dikenleri
    final spikeCount = 3 + tier;
    final spacing = size * 0.64 / spikeCount;
    for (int i = 0; i < spikeCount; i++) {
      final x = size * 0.18 + i * spacing + spacing / 2;
      final path = Path()
        ..moveTo(x - size * 0.03, size * 0.55)
        ..lineTo(x, size * 0.30 - tier * size * 0.03)
        ..lineTo(x + size * 0.03, size * 0.55);
      canvas.drawPath(path, Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, size * 0.30),
          Offset(x, size * 0.55),
          [const Color(0xFFcccccc), const Color(0xFF666666)],
        ));
      // Spike tip glow
      canvas.drawCircle(
        Offset(x, size * 0.30 - tier * size * 0.03),
        3,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  void _drawSupportBody(Canvas canvas, double size, int tier) {
    final center = Offset(size / 2, size * 0.48);
    final radius = size * 0.15 + tier * size * 0.02;

    // Outer aura
    final auraPaint = Paint()
      ..color = const Color(0xFFffd700).withValues(alpha: 0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius);
    canvas.drawCircle(center, radius * 2, auraPaint);

    // Main orb
    final orbPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [const Color(0xFFfff8e0), const Color(0xFFffd700), const Color(0xFFb8860b)],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(center, radius, orbPaint);

    // Plus sign
    final plusPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center - Offset(radius * 0.5, 0),
      center + Offset(radius * 0.5, 0),
      plusPaint,
    );
    canvas.drawLine(
      center - Offset(0, radius * 0.5),
      center + Offset(0, radius * 0.5),
      plusPaint,
    );
  }

  void _drawTierStars(Canvas canvas, double size, int tier) {
    final starY = size * 0.92;
    final totalWidth = tier * size * 0.06;
    final startX = (size - totalWidth) / 2;

    for (int i = 0; i < tier; i++) {
      final x = startX + i * size * 0.06 + size * 0.03;
      final starColor = tier == 4 ? const Color(0xFFffd700) : const Color(0xFFdddd00);

      // Star glow
      canvas.drawCircle(
        Offset(x, starY),
        size * 0.02,
        Paint()
          ..color = starColor.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Star body
      canvas.drawCircle(
        Offset(x, starY),
        size * 0.015,
        Paint()..color = starColor,
      );
    }
  }

  Color _getTowerColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFF9E5B3C);
      case TowerType.ice: return const Color(0xFF22CCEE);
      case TowerType.fire: return const Color(0xFFFF5511);
      case TowerType.lightning: return const Color(0xFFFFDD00);
      case TowerType.poison: return const Color(0xFF33FF33);
      case TowerType.cannon: return const Color(0xFF4A5568);
      case TowerType.spikeWall: return const Color(0xFF555555);
      case TowerType.support: return const Color(0xFFDDCC00);
      case TowerType.water: return const Color(0xFF00BBCC);
      case TowerType.wizard: return const Color(0xFFAA33DD);
      case TowerType.dark: return const Color(0xFF3311AA);
      case TowerType.holy: return const Color(0xFFFFDD66);
    }
  }

  Color _getTowerGlowColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFFd4a843);
      case TowerType.ice: return const Color(0xFF4ecdc4);
      case TowerType.fire: return const Color(0xFFe94560);
      case TowerType.lightning: return const Color(0xFFa78bfa);
      case TowerType.poison: return const Color(0xFF2ecc71);
      case TowerType.cannon: return const Color(0xFFe67e22);
      case TowerType.spikeWall: return const Color(0xFF95a5a6);
      case TowerType.support: return const Color(0xFFffd700);
      case TowerType.water: return const Color(0xFF3498db);
      case TowerType.wizard: return const Color(0xFF9b59b6);
      case TowerType.dark: return const Color(0xFF8b5cf6);
      case TowerType.holy: return const Color(0xFFffd700);
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/game/components/rendering/tower_sprites.dart
git commit -m "feat: add TowerSpriteGenerator for high-quality cached tower sprites"
```

---

### Task 7: Tower render() metodunu sprite tabanlı yap

**Files:**
- Modify: `lib/game/components/towers/tower.dart` — render() metodunu değiştir (lines 111-344)

- [ ] **Step 1: Tower sınıfına sprite desteği ekle**

`tower.dart` dosyasının başına import ekle:

```dart
import '../rendering/tower_sprites.dart';
```

Mevcut `render()` metodunu (lines 111-344) tamamen yeni sprite tabanlı versiyonla değiştir:

```dart
@override
void render(Canvas canvas) {
  // Sprite-tabanlı render
  final spriteImage = TowerSpriteGenerator.instance.getSprite(type, _tier);
  if (spriteImage != null) {
    // Sprite'ı hücre boyutuna ölçekle
    final src = Rect.fromLTWH(0, 0, spriteImage.width.toDouble(), spriteImage.height.toDouble());
    final dst = Rect.fromLTWH(0, -cellSize * 0.3, cellSize, cellSize * 1.3);
    canvas.drawImageRect(spriteImage, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  // Sinerji glow (Canvas efekt olarak kalır)
  if (_synergyDamageMultiplier > 1.0 || _synergyRangeBonus > 0 || _synergyFireRateMultiplier < 1.0) {
    final glowAlpha = (0.3 + 0.2 * sin(_animTimer * 3)).clamp(0.0, 1.0);
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, -cellSize * 0.32, cellSize + 4, cellSize * 1.34),
        const Radius.circular(4),
      ),
      glowPaint,
    );
  }

  // Support aura glow
  if (supportDamageMultiplier > 1.0 || supportRangeMultiplier > 1.0) {
    final auraPaint = Paint()
      ..color = const Color(0xFFFFFF00).withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cellSize / 2, cellSize / 2), cellSize * 0.6, auraPaint);
  }

  // Range indicator (seçiliyken)
  if (showRange) {
    final rangePx = currentRange * cellSize;
    final rangeCenter = Offset(cellSize / 2, cellSize / 2);
    canvas.drawCircle(rangeCenter, rangePx, Paint()
      ..color = const Color(0x1800FF88)
      ..style = PaintingStyle.fill);
    canvas.drawCircle(rangeCenter, rangePx, Paint()
      ..color = const Color(0x4400FF88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  // Ateş flash efekti
  if (_cooldown > currentFireRate * 0.8) {
    final flashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cellSize / 2, cellSize * 0.15), cellSize * 0.12, flashPaint);
  }
}
```

- [ ] **Step 2: onLoad'da sprite initialization**

Tower sınıfının `onLoad()` metoduna ekle:

```dart
@override
Future<void> onLoad() async {
  await super.onLoad();
  // TowerSpriteGenerator zaten KaleGame.onLoad'da initialize edilmiş olacak
}
```

- [ ] **Step 3: KaleGame.onLoad'da TowerSpriteGenerator'ı initialize et**

`kale_game.dart` dosyasında `onLoad()` metodunun başına ekle:

```dart
await TowerSpriteGenerator.instance.initialize();
```

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/towers/tower.dart lib/game/kale_game.dart
git commit -m "feat: replace tower Canvas rendering with cached sprite-based rendering"
```

---

## Chunk 4: Düşman Sprite Dönüşümü

### Task 8: Düşman sprite üretici oluştur

**Files:**
- Create: `lib/game/components/rendering/enemy_sprites.dart`

Mevcut enemy.dart render() (lines 162-290) çok detaylı. Bu çizimleri 128x128 sprite'lara dönüştür ve yürüme animasyonu için 4 frame üret.

- [ ] **Step 1: EnemySpriteGenerator sınıfını yaz**

Mevcut enemy render mantığını (soldier: daire, cavalry: damla, armoredGiant: altıgen, vs.) alıp 128x128'de daha detaylı çizerek cache'leyen sınıf. Her düşman tipi için 4 yürüme frame'i üretilir (hafif dikey bop + bacak hareketi simülasyonu).

```dart
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/enemy_data.dart';

class EnemySpriteGenerator {
  static final EnemySpriteGenerator instance = EnemySpriteGenerator._();
  EnemySpriteGenerator._();

  final Map<String, ui.Image> _cache = {};
  static const int spriteSize = 128;
  static const int walkFrames = 4;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    for (final type in EnemyType.values) {
      // 4 frame yürüme animasyonu — tek sprite sheet (128 * 4 = 512 x 128)
      _cache[type.name] = await _generateWalkSheet(type);
    }
    _initialized = true;
  }

  ui.Image? getWalkSheet(EnemyType type) => _cache[type.name];

  Future<ui.Image> _generateWalkSheet(EnemyType type) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = spriteSize.toDouble();

    for (int frame = 0; frame < walkFrames; frame++) {
      canvas.save();
      canvas.translate(frame * size, 0);
      _drawEnemy(canvas, size, type, frame);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    return picture.toImage(spriteSize * walkFrames, spriteSize);
  }

  void _drawEnemy(Canvas canvas, double size, EnemyType type, int frame) {
    final color = _getEnemyColor(type);
    final center = Offset(size / 2, size / 2);

    // Yürüme bop animasyonu
    final bobOffset = sin(frame * pi / 2) * size * 0.02;

    canvas.save();
    canvas.translate(0, bobOffset);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size / 2, size * 0.85), width: size * 0.5, height: size * 0.08),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Düşman gövdesi (tipe göre farklı şekil)
    _drawEnemyBody(canvas, size, type, color, frame);

    // Göz detayları
    _drawEyes(canvas, size, type);

    canvas.restore();
  }

  void _drawEnemyBody(Canvas canvas, double size, EnemyType type, Color color, int frame) {
    final center = Offset(size / 2, size * 0.48);
    final bodyRadius = size * 0.28;

    switch (type) {
      case EnemyType.armoredGiant:
        // Altıgen — metalik
        _drawHexagon(canvas, center, bodyRadius, color);
        break;
      case EnemyType.cavalry:
        // Damla şekli — hızlı görünüm
        _drawTeardrop(canvas, center, bodyRadius, color);
        break;
      case EnemyType.goblin:
        // Küçük üçgen — imp
        _drawTriangle(canvas, center, bodyRadius * 0.8, color);
        break;
      case EnemyType.darkKnight:
        // Eşkenar dörtgen — tehditkar
        _drawDiamond(canvas, center, bodyRadius, color);
        break;
      case EnemyType.shieldBearer:
        // Kare — savunma hissi
        _drawRoundedSquare(canvas, center, bodyRadius, color);
        break;
      case EnemyType.shadowLord:
      case EnemyType.dragonEmperor:
        // Büyük — aura + pulse
        _drawBossBody(canvas, center, bodyRadius * 1.4, color, type);
        break;
      default:
        // Standart daire
        _drawCircleBody(canvas, center, bodyRadius, color);
        break;
    }
  }

  void _drawCircleBody(Canvas canvas, Offset center, double radius, Color color) {
    // Outer glow
    canvas.drawCircle(center, radius * 1.3, Paint()
      ..color = color.withValues(alpha: 0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.4));

    // Main body gradient
    canvas.drawCircle(center, radius, Paint()
      ..shader = ui.Gradient.radial(
        center + Offset(-radius * 0.2, -radius * 0.2),
        radius,
        [Color.lerp(color, Colors.white, 0.3)!, color, Color.lerp(color, Colors.black, 0.4)!],
        [0.0, 0.5, 1.0],
      ));

    // Rim light
    canvas.drawCircle(center, radius, Paint()
      ..color = Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * pi / 180;
      final point = center + Offset(cos(angle) * radius, sin(angle) * radius);
      if (i == 0) path.moveTo(point.dx, point.dy);
      else path.lineTo(point.dx, point.dy);
    }
    path.close();

    // Glow
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: 0.15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5));

    canvas.drawPath(path, Paint()
      ..shader = ui.Gradient.linear(
        center - Offset(0, radius),
        center + Offset(0, radius),
        [Color.lerp(color, Colors.white, 0.4)!, color, Color.lerp(color, Colors.black, 0.3)!],
      ));

    canvas.drawPath(path, Paint()
      ..color = Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  void _drawTeardrop(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - radius * 1.2, center.dx - radius * 0.6, center.dy)
      ..quadraticBezierTo(center.dx, center.dy + radius * 0.8, center.dx + radius, center.dy);

    canvas.drawPath(path, Paint()
      ..shader = ui.Gradient.linear(
        center - Offset(0, radius),
        center + Offset(0, radius),
        [Color.lerp(color, Colors.white, 0.3)!, color],
      ));
  }

  void _drawTriangle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - radius * 0.9, center.dy + radius * 0.7)
      ..lineTo(center.dx + radius * 0.9, center.dy + radius * 0.7)
      ..close();

    canvas.drawPath(path, Paint()
      ..shader = ui.Gradient.linear(
        center - Offset(0, radius),
        center + Offset(0, radius),
        [Color.lerp(color, Colors.white, 0.3)!, color],
      ));
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.7, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.7, center.dy)
      ..close();

    canvas.drawPath(path, Paint()
      ..shader = ui.Gradient.linear(
        center - Offset(0, radius),
        center + Offset(0, radius),
        [Color.lerp(color, Colors.white, 0.3)!, color, Color.lerp(color, Colors.black, 0.3)!],
      ));
  }

  void _drawRoundedSquare(Canvas canvas, Offset center, double radius, Color color) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: radius * 1.8, height: radius * 1.8),
      Radius.circular(radius * 0.2),
    );
    canvas.drawRRect(rect, Paint()
      ..shader = ui.Gradient.linear(
        center - Offset(0, radius),
        center + Offset(0, radius),
        [Color.lerp(color, Colors.white, 0.3)!, color, Color.lerp(color, Colors.black, 0.2)!],
      ));
  }

  void _drawBossBody(Canvas canvas, Offset center, double radius, Color color, EnemyType type) {
    // Aura rings
    for (int i = 3; i > 0; i--) {
      canvas.drawCircle(center, radius * (1 + i * 0.2), Paint()
        ..color = color.withValues(alpha: 0.05 * i)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3));
    }

    _drawCircleBody(canvas, center, radius, color);
  }

  void _drawEyes(Canvas canvas, double size, EnemyType type) {
    final eyeY = size * 0.42;
    final eyeSpacing = size * 0.08;

    // Göz rengi
    Color eyeColor;
    switch (type) {
      case EnemyType.undead:
      case EnemyType.darkKnight:
      case EnemyType.shadowLord:
        eyeColor = const Color(0xFFFF0000);
        break;
      case EnemyType.dragonEmperor:
        eyeColor = const Color(0xFFFFAA00);
        break;
      default:
        eyeColor = Colors.white;
    }

    // Sol göz
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size / 2 - eyeSpacing, eyeY), width: size * 0.06, height: size * 0.04),
      Paint()..color = eyeColor,
    );
    // Sağ göz
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size / 2 + eyeSpacing, eyeY), width: size * 0.06, height: size * 0.04),
      Paint()..color = eyeColor,
    );

    // Boss veya undead glow eyes
    if (type == EnemyType.shadowLord || type == EnemyType.dragonEmperor || type == EnemyType.undead || type == EnemyType.darkKnight) {
      final glowPaint = Paint()
        ..color = eyeColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(size / 2 - eyeSpacing, eyeY), size * 0.04, glowPaint);
      canvas.drawCircle(Offset(size / 2 + eyeSpacing, eyeY), size * 0.04, glowPaint);
    }
  }

  Color _getEnemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.soldier: return const Color(0xFFCC4444);
      case EnemyType.cavalry: return const Color(0xFFFF7711);
      case EnemyType.goblin: return const Color(0xFF44DD22);
      case EnemyType.armoredGiant: return const Color(0xFFAABBCC);
      case EnemyType.undead: return const Color(0xFF7799AA);
      case EnemyType.shieldBearer: return const Color(0xFF4488CC);
      case EnemyType.healer: return const Color(0xFF44CCAA);
      case EnemyType.burrower: return const Color(0xFF886644);
      case EnemyType.troll: return const Color(0xFF228833);
      case EnemyType.darkKnight: return const Color(0xFF6633AA);
      case EnemyType.shadowLord: return const Color(0xFF440066);
      case EnemyType.dragonEmperor: return const Color(0xFFDD3300);
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/game/components/rendering/enemy_sprites.dart
git commit -m "feat: add EnemySpriteGenerator with walk animation frames"
```

---

### Task 9: Enemy render() metodunu sprite tabanlı yap

**Files:**
- Modify: `lib/game/components/enemies/enemy.dart` — render() metodunu değiştir (lines 162-290)

- [ ] **Step 1: Enemy render'ı sprite + status overlay ile değiştir**

Mevcut `render()` metodunu (lines 162-290) yeni versiyonla değiştir. Yürüme animasyonu frame seçimi `_animTimer` ile yapılır. HP bar ve status effect göstergeleri Canvas overlay olarak kalır.

```dart
// Import ekle
import '../rendering/enemy_sprites.dart';

// render() metodunu değiştir:
@override
void render(Canvas canvas) {
  if (_isDead || _reachedCastle) return;

  // Burrowed state (mevcut mantık aynı)
  if (_isBurrowed) {
    _renderBurrowed(canvas);
    return;
  }

  final spriteSheet = EnemySpriteGenerator.instance.getWalkSheet(type);
  if (spriteSheet != null) {
    // Walk frame seçimi
    final frameIndex = ((_animTimer * 4) % 4).floor(); // 4 FPS yürüme
    final frameSize = EnemySpriteGenerator.spriteSize.toDouble();
    final src = Rect.fromLTWH(frameIndex * frameSize, 0, frameSize, frameSize);

    // Düşman boyutu (boss daha büyük)
    final scale = _isBoss ? 1.5 : 0.7;
    final drawSize = cellSize * scale;
    final offset = (cellSize - drawSize) / 2;
    final dst = Rect.fromLTWH(offset, offset - drawSize * 0.1, drawSize, drawSize);

    // Yön bazlı flip
    canvas.save();
    if (_movingLeft) {
      canvas.translate(cellSize, 0);
      canvas.scale(-1, 1);
    }

    // Hasar flash
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (_damageFlashTimer > 0) {
      paint.colorFilter = const ColorFilter.mode(Color(0x66FF0000), BlendMode.srcATop);
    }

    canvas.drawImageRect(spriteSheet, src, dst, paint);
    canvas.restore();
  }

  // Status effect particle overlay (Canvas)
  _renderStatusEffects(canvas);

  // HP bar (Canvas — mevcut mantık aynı, pozisyon ayarlanır)
  _renderHpBar(canvas);
}

bool get _movingLeft {
  if (_pathIndex < path.length - 1) {
    return path[_pathIndex + 1].col < path[_pathIndex].col;
  }
  return false;
}

bool get _isBoss => type == EnemyType.shadowLord || type == EnemyType.dragonEmperor;

void _renderStatusEffects(Canvas canvas) {
  final center = Offset(cellSize / 2, cellSize / 2);
  for (final effect in _effects) {
    switch (effect.type) {
      case StatusType.burn:
        // Ateş parçacıkları
        final firePaint = Paint()
          ..color = const Color(0xCCFF4500)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(center + Offset(sin(_animTimer * 8) * 6, -8), 3, firePaint);
        break;
      case StatusType.poison:
        // Yeşil duman
        final poisonPaint = Paint()
          ..color = const Color(0x8800FF00)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(center + Offset(0, -10 - sin(_animTimer * 3) * 4), 5, poisonPaint);
        break;
      case StatusType.slow:
        // Mavi parıltı
        final slowPaint = Paint()
          ..color = const Color(0x4487CEEB)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(center, cellSize * 0.35, slowPaint);
        break;
      case StatusType.wet:
        // Su damlaları
        final wetPaint = Paint()..color = const Color(0xAA4169E1);
        canvas.drawCircle(center + Offset(4, -6), 2, wetPaint);
        canvas.drawCircle(center + Offset(-5, -3), 1.5, wetPaint);
        break;
      case StatusType.curse:
        // Mor aura
        final cursePaint = Paint()
          ..color = const Color(0x33AA00AA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(center, cellSize * 0.4, cursePaint);
        break;
    }
  }
}

void _renderHpBar(Canvas canvas) {
  // Mevcut HP bar kodu korunur, pozisyon ayarlanır
  // ...
}
```

- [ ] **Step 2: KaleGame.onLoad'da EnemySpriteGenerator'ı initialize et**

```dart
await EnemySpriteGenerator.instance.initialize();
```

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/enemies/enemy.dart lib/game/kale_game.dart
git commit -m "feat: replace enemy Canvas rendering with sprite-based walk animation"
```

---

## Chunk 5: Kale Sprite & Parallax Arka Plan

### Task 10: Kale sprite üretici

**Files:**
- Create: `lib/game/components/rendering/castle_sprites.dart`

Mevcut castle.dart render() (lines 40-285) çok detaylı. 3 hasar aşaması (sağlam, hasarlı, yıkık) için ayrı 256x256 sprite üret.

- [ ] **Step 1: CastleSpriteGenerator sınıfını yaz**

Mevcut castle render mantığını (platform, gövde, kuleleri, mazgallar, kapı, pencereler, bayraklar) alıp 256x256'da daha detaylı çizerek 3 hasar versiyonu üret.

Yapı: `_generateCastleSprite(int damagePhase)` — damagePhase 0=sağlam, 1=hasarlı, 2=yıkık

- [ ] **Step 2: Castle render'ını sprite tabanlı yap**

`castle.dart` render() metodunu sprite çizen + hasar overlay (duman, ateş parçacıkları Canvas ile) versiyonla değiştir.

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/rendering/castle_sprites.dart lib/game/components/castle.dart
git commit -m "feat: sprite-based castle with 3 damage phases and particle overlays"
```

---

### Task 11: Parallax arka plan sistemi

**Files:**
- Create: `lib/game/components/background/parallax_background.dart`
- Modify: `lib/game/components/background.dart` — mevcut background'u parallax ile değiştir
- Modify: `lib/game/kale_game.dart` — background component değişikliği

- [ ] **Step 1: ParallaxLayer sınıfı yaz**

```dart
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../map/biome_data.dart';

class ParallaxBackground extends Component {
  final BiomeData biome;
  final double gameWidth;
  final double gameHeight;
  double _scrollOffset = 0;
  double _animTimer = 0;

  late ui.Image _farLayer;    // Uzak dağlar/gökyüzü
  late ui.Image _midLayer;    // Orta plan siluetler
  late ui.Image _nearLayer;   // Ön plan sis/detay

  // Parçacıklar (ateş böceği, toz, kar vs.)
  late List<_AmbientParticle> _particles;

  ParallaxBackground({
    required this.biome,
    required this.gameWidth,
    required this.gameHeight,
  }) : super(priority: -10);

  @override
  Future<void> onLoad() async {
    _farLayer = await _generateFarLayer();
    _midLayer = await _generateMidLayer();
    _nearLayer = await _generateNearLayer();
    _particles = _generateParticles();
  }

  @override
  void update(double dt) {
    _animTimer += dt;
    // Yavaş scroll
    _scrollOffset += dt * 2;

    // Parçacık güncelleme
    for (final p in _particles) {
      p.y += p.vy * dt;
      p.x += p.vx * dt + sin(_animTimer * p.freq) * 0.3;
      p.alpha = (0.3 + 0.3 * sin(_animTimer * p.freq + p.phase)).clamp(0.0, 1.0);

      // Ekran dışına çıkarsa geri getir
      if (p.y < -10) p.y = gameHeight + 10;
      if (p.y > gameHeight + 10) p.y = -10;
      if (p.x < -10) p.x = gameWidth + 10;
      if (p.x > gameWidth + 10) p.x = -10;
    }
  }

  @override
  void render(Canvas canvas) {
    // Gökyüzü gradient
    final skyGradient = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, gameHeight),
        [biome.skyTop, biome.skyBottom],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, gameWidth, gameHeight), skyGradient);

    // Yıldızlar (gece temaları için)
    _renderStars(canvas);

    // Ay
    _renderMoon(canvas);

    // Far layer (en yavaş parallax)
    _renderLayer(canvas, _farLayer, _scrollOffset * 0.1);

    // Mid layer
    _renderLayer(canvas, _midLayer, _scrollOffset * 0.3);

    // Sis katmanı
    _renderFog(canvas);

    // Parçacıklar
    _renderParticles(canvas);

    // Vignette
    _renderVignette(canvas);
  }

  void _renderLayer(Canvas canvas, ui.Image layer, double offset) {
    final src = Rect.fromLTWH(0, 0, layer.width.toDouble(), layer.height.toDouble());
    final dst = Rect.fromLTWH(-offset % gameWidth, 0, gameWidth, gameHeight);
    canvas.drawImageRect(layer, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  void _renderStars(Canvas canvas) {
    final rng = Random(42);
    final starPaint = Paint();
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * gameWidth;
      final y = rng.nextDouble() * gameHeight * 0.4;
      final size = rng.nextDouble() * 1.5 + 0.5;
      final twinkle = (0.4 + 0.6 * sin(_animTimer * (1 + rng.nextDouble()) + i)).clamp(0.0, 1.0);
      starPaint.color = Colors.white.withValues(alpha: twinkle * 0.8);
      canvas.drawCircle(Offset(x, y), size, starPaint);
      // Star glow
      starPaint.color = Colors.white.withValues(alpha: twinkle * 0.15);
      starPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), size * 3, starPaint);
      starPaint.maskFilter = null;
    }
  }

  void _renderMoon(Canvas canvas) {
    final moonCenter = Offset(gameWidth * 0.85, gameHeight * 0.08);
    // Moon glow
    canvas.drawCircle(moonCenter, 30, Paint()
      ..color = const Color(0x15F0E6D0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25));
    // Moon body
    canvas.drawCircle(moonCenter, 12, Paint()
      ..shader = ui.Gradient.radial(
        moonCenter + const Offset(-3, -3),
        12,
        [const Color(0xFFF0E6D0), const Color(0xFFC4B490)],
      ));
  }

  void _renderFog(Canvas canvas) {
    final fogPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, gameHeight * 0.6),
        Offset(0, gameHeight),
        [Colors.transparent, biome.fogColor],
      );
    canvas.drawRect(Rect.fromLTWH(0, gameHeight * 0.6, gameWidth, gameHeight * 0.4), fogPaint);
  }

  void _renderParticles(Canvas canvas) {
    for (final p in _particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha * 0.6);

      // Parçacık glow
      canvas.drawCircle(Offset(p.x, p.y), p.size * 2, Paint()
        ..color = p.color.withValues(alpha: p.alpha * 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2));

      // Parçacık body
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  void _renderVignette(Canvas canvas) {
    // Top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameWidth, gameHeight * 0.15),
      Paint()..shader = ui.Gradient.linear(
        Offset.zero, Offset(0, gameHeight * 0.15),
        [const Color(0x60000000), Colors.transparent],
      ),
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(0, gameHeight * 0.85, gameWidth, gameHeight * 0.15),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, gameHeight * 0.85), Offset(0, gameHeight),
        [Colors.transparent, const Color(0x50000000)],
      ),
    );
  }

  List<_AmbientParticle> _generateParticles() {
    final rng = Random(12);
    return List.generate(30, (i) {
      Color color;
      switch (biome.type) {
        case BiomeType.forest:
          color = const Color(0xFFAADD44); // Ateş böceği
          break;
        case BiomeType.desert:
          color = const Color(0xFFDDBB88); // Kum tozu
          break;
        case BiomeType.snow:
          color = const Color(0xFFDDEEFF); // Kar tanesi
          break;
        case BiomeType.volcano:
          color = const Color(0xFFFF6600); // Kıvılcım
          break;
        case BiomeType.dark:
          color = const Color(0xFF8844FF); // Mor enerji
          break;
      }
      return _AmbientParticle(
        x: rng.nextDouble() * gameWidth,
        y: rng.nextDouble() * gameHeight,
        vx: (rng.nextDouble() - 0.5) * 8,
        vy: biome.type == BiomeType.snow
          ? rng.nextDouble() * 15 + 5  // Kar aşağı yağar
          : (rng.nextDouble() - 0.5) * 6,
        size: rng.nextDouble() * 1.5 + 0.5,
        color: color,
        alpha: 0.5,
        freq: rng.nextDouble() * 2 + 0.5,
        phase: rng.nextDouble() * pi * 2,
      );
    });
  }

  Future<ui.Image> _generateFarLayer() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Uzak dağ siluetleri
    final mountainPaint = Paint()..color = Color.lerp(biome.skyBottom, Colors.black, 0.3)!;
    final path = Path();
    final rng = Random(7);
    path.moveTo(0, gameHeight);
    for (double x = 0; x <= gameWidth; x += 30) {
      final y = gameHeight * 0.55 + rng.nextDouble() * gameHeight * 0.15;
      path.lineTo(x, y);
    }
    path.lineTo(gameWidth, gameHeight);
    path.close();
    canvas.drawPath(path, mountainPaint);

    final picture = recorder.endRecording();
    return picture.toImage(gameWidth.toInt(), gameHeight.toInt());
  }

  Future<ui.Image> _generateMidLayer() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Orta plan ağaç/tepe siluetleri
    final silhouettePaint = Paint()..color = Color.lerp(biome.skyBottom, Colors.black, 0.5)!;
    final path = Path();
    final rng = Random(13);
    path.moveTo(0, gameHeight);
    for (double x = 0; x <= gameWidth; x += 20) {
      final baseY = gameHeight * 0.65;
      final variation = rng.nextDouble() * gameHeight * 0.1;
      // Ağaç siluetleri
      if (rng.nextDouble() > 0.7) {
        path.lineTo(x, baseY - variation - gameHeight * 0.08);
        path.lineTo(x + 10, baseY - variation);
      } else {
        path.lineTo(x, baseY + variation * 0.5);
      }
    }
    path.lineTo(gameWidth, gameHeight);
    path.close();
    canvas.drawPath(path, silhouettePaint);

    final picture = recorder.endRecording();
    return picture.toImage(gameWidth.toInt(), gameHeight.toInt());
  }

  Future<ui.Image> _generateNearLayer() async {
    // Ön plan detayları — şimdilik boş, biome dekorasyonları eklenebilir
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final picture = recorder.endRecording();
    return picture.toImage(gameWidth.toInt(), gameHeight.toInt());
  }
}

class _AmbientParticle {
  double x, y, vx, vy, size, alpha, freq, phase;
  Color color;
  _AmbientParticle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.size, required this.color, required this.alpha,
    required this.freq, required this.phase,
  });
}
```

- [ ] **Step 2: KaleGame'de background değişikliği**

Mevcut `Background` component'ını `ParallaxBackground` ile değiştir:

```dart
// Mevcut: add(Background(...));
// Yeni:
add(ParallaxBackground(
  biome: _difficulty.biome,
  gameWidth: _gameWidth,
  gameHeight: _gameHeight,
));
```

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/background/parallax_background.dart lib/game/components/background.dart lib/game/kale_game.dart
git commit -m "feat: add parallax background with biome-specific atmosphere and particles"
```

---

## Chunk 6: Efekt Sistemi Geliştirme

### Task 12: Screen shake sistemi

**Files:**
- Create: `lib/game/components/effects/screen_shake.dart`
- Modify: `lib/game/kale_game.dart` — shake entegrasyonu

- [ ] **Step 1: ScreenShake component'ı yaz**

```dart
import 'dart:math';
import 'package:flame/components.dart';

class ScreenShake extends Component {
  double _duration = 0;
  double _intensity = 0;
  double _timer = 0;
  final Random _rng = Random();

  Vector2 get offset {
    if (_timer <= 0) return Vector2.zero();
    final progress = _timer / _duration;
    final currentIntensity = _intensity * progress;
    return Vector2(
      (_rng.nextDouble() * 2 - 1) * currentIntensity,
      (_rng.nextDouble() * 2 - 1) * currentIntensity,
    );
  }

  void shake({double duration = 0.3, double intensity = 4.0}) {
    _duration = duration;
    _intensity = intensity;
    _timer = duration;
  }

  @override
  void update(double dt) {
    if (_timer > 0) {
      _timer -= dt;
      if (_timer < 0) _timer = 0;
    }
  }
}
```

- [ ] **Step 2: KaleGame'e screen shake entegre et**

```dart
// Field ekle
late ScreenShake screenShake;

// onLoad'da
screenShake = ScreenShake();
add(screenShake);

// update'de camera offset'e uygula
@override
void update(double dt) {
  super.update(dt);
  camera.viewfinder.position = screenShake.offset;
}

// Kale hasar aldığında
void onCastleDamage(int damage) {
  screenShake.shake(
    duration: 0.2 + (damage / castle.maxHp) * 0.3,
    intensity: 2.0 + damage * 0.5,
  );
}
```

- [ ] **Step 3: Settings'e screen shake toggle**

`settings_screen.dart` dosyasına "Ekran Sarsıntısı" toggle ekle.

- [ ] **Step 4: Commit**

```bash
git add lib/game/components/effects/screen_shake.dart lib/game/kale_game.dart lib/screens/settings_screen.dart
git commit -m "feat: add screen shake effect for boss damage and castle hits"
```

---

### Task 13: Gelişmiş mermi trail efekti

**Files:**
- Modify: `lib/game/components/towers/projectile.dart`

Mevcut projectile zaten trail + glow var. Geliştir: trail rengi kule tipine göre, daha uzun trail, afterglow.

- [ ] **Step 1: Projectile trail'ini geliştir**

Mevcut trail sistemini genişlet:
- `_maxTrailLength` 8 → 12
- Trail kalınlığı fade: ilk segment kalın → son segment ince
- Trail rengi glow: segment etrafında blur

```dart
// _renderTrail metodunu güncelle
void _renderTrail(Canvas canvas) {
  if (_trail.length < 2) return;
  for (int i = 0; i < _trail.length - 1; i++) {
    final progress = i / _trail.length;
    final alpha = (1.0 - progress) * 0.6;
    final width = (1.0 - progress) * 3.0 + 0.5;

    // Trail segment
    final p1 = _trail[i] - position;
    final p2 = _trail[i + 1] - position;

    // Glow
    canvas.drawLine(p1.toOffset(), p2.toOffset(), Paint()
      ..color = trailColor.withValues(alpha: alpha * 0.3)
      ..strokeWidth = width * 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 2));

    // Core
    canvas.drawLine(p1.toOffset(), p2.toOffset(), Paint()
      ..color = trailColor.withValues(alpha: alpha)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/game/components/towers/projectile.dart
git commit -m "feat: enhanced projectile trails with glow and fade"
```

---

### Task 14: Ölüm efekti ve floating damage text geliştirmesi

**Files:**
- Modify: `lib/game/components/effects/hit_effect.dart` — ölüm efektini zenginleştir
- Modify: `lib/game/components/floating_text.dart` — kritik vuruş stili

- [ ] **Step 1: Hit effect'e death burst geliştirmesi**

Ölüm anında parçacık sayısını artır (14 → 20), daha uzun ömür, daha büyük parçacıklar. Düşman tipine göre özel efekt:
- Undead ölümü: ghostly fade + split parçacıkları
- Boss ölümü: büyük patlama + screen shake tetikle + shockwave

- [ ] **Step 2: Floating text'e kritik vuruş stili**

Kritik vuruşlarda: büyük font (1.5x), farklı renk (#FFD700 altın), "!" suffix, daha uzun hover süresi.

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/effects/hit_effect.dart lib/game/components/floating_text.dart
git commit -m "feat: enhanced death effects and critical hit floating text"
```

---

## Chunk 7: UI/HUD Glassmorphism

### Task 15: Game HUD glassmorphism dönüşümü

**Files:**
- Modify: `lib/screens/game_hud.dart` (1084 lines)

Bu en büyük UI değişikliği. Mevcut düz renkli panelleri glassmorphism'e çevir.

- [ ] **Step 1: Glassmorphism helper widget oluştur**

`game_hud.dart` dosyasının içine veya ayrı dosyaya:

```dart
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color borderColor;

  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 12,
    this.borderColor = const Color(0x33D4A843),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xAA0D0D15),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Top bar'ı glassmorphism'e çevir**

Mevcut `_buildTopBar()` metodundaki `Container` arka planlarını `GlassPanel` ile değiştir. HP barına glow efekti ekle. Altın göstergesine parlama animasyonu ekle.

- [ ] **Step 3: Bottom tower panel'i glassmorphism'e çevir**

Kule seçim listesini `GlassPanel` içine al. Seçili kule scale animasyonu ekle (`AnimatedScale`).

- [ ] **Step 4: Wave button'u modernleştir**

Dalga başlatma butonuna pulsing glow border ekle. `AnimatedContainer` ile yumuşak geçişler.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_hud.dart
git commit -m "feat: glassmorphism UI for game HUD with blur, glow, and animations"
```

---

### Task 16: Wave break ekranını modernleştir

**Files:**
- Modify: `lib/screens/wave_break.dart`

- [ ] **Step 1: Blur arka plan + glassmorphism kart**

```dart
// Mevcut Container'ı değiştir:
BackdropFilter(
  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
  child: Center(
    child: GlassPanel(
      borderColor: const Color(0x44D4A843),
      borderRadius: 16,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mevcut içerik — dalga bilgisi, countdown, düşman preview
          // Düşman preview'da sprite görselleri kullan
        ],
      ),
    ),
  ),
)
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/wave_break.dart
git commit -m "feat: glassmorphism wave break screen with blur backdrop"
```

---

### Task 17: Diğer ekranları modernleştir

**Files:**
- Modify: `lib/screens/main_menu.dart`
- Modify: `lib/screens/death_screen.dart`
- Modify: `lib/screens/pause_overlay.dart`
- Modify: `lib/screens/meta_screen.dart`
- Modify: `lib/screens/run_setup.dart`
- Modify: `lib/screens/bestiary_screen.dart`
- Modify: `lib/screens/synergy_guide.dart`

- [ ] **Step 1: Main menu — parallax arka plan + glassmorphism butonlar**

Mevcut radial gradient arka planı daha derin atmosferik gradient ile değiştir. Butonlara glassmorphism uygula. Title'a daha güçlü glow.

- [ ] **Step 2: Death screen — blur + sonuç kartı**

Arka plana `BackdropFilter` blur ekle. Sonuçları `GlassPanel` içinde göster.

- [ ] **Step 3: Pause overlay — blur + glassmorphism menü**

Aynı pattern: blur arka plan + glassmorphism butonlar.

- [ ] **Step 4: Meta screen — neon node'lar**

Meta ağacı node'larına kule renkleriyle uyumlu glow ekle. Bağlantı çizgilerine neon efekt.

- [ ] **Step 5: Run setup — biome preview**

Seçilen zorluk seviyesine göre biome renk paleti preview'ı göster.

- [ ] **Step 6: Bestiary & Synergy guide — sprite görselleri**

Düşman ve kule ikonlarında sprite görselleri kullan (EnemySpriteGenerator, TowerSpriteGenerator'dan).

- [ ] **Step 7: Commit**

```bash
git add lib/screens/main_menu.dart lib/screens/death_screen.dart lib/screens/pause_overlay.dart lib/screens/meta_screen.dart lib/screens/run_setup.dart lib/screens/bestiary_screen.dart lib/screens/synergy_guide.dart
git commit -m "feat: glassmorphism UI across all screens with sprite integration"
```

---

## Chunk 8: Sinerji & Son Dokunuşlar

### Task 18: Sinerji parıltı efekti

**Files:**
- Create: `lib/game/components/effects/synergy_particles.dart`
- Modify: `lib/game/components/towers/tower.dart` — sinerji aktifken particle spawn

- [ ] **Step 1: SynergyParticles component'ı yaz**

Sinerji aktif olan kulelerin etrafında dönen altın parçacıklar:

```dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SynergyParticles extends Component {
  final double cellSize;
  final List<_OrbitalParticle> _particles = [];
  double _timer = 0;

  SynergyParticles({required this.cellSize}) {
    final rng = Random();
    for (int i = 0; i < 6; i++) {
      _particles.add(_OrbitalParticle(
        angle: i * pi / 3,
        radius: cellSize * 0.5 + rng.nextDouble() * cellSize * 0.15,
        speed: 1.5 + rng.nextDouble() * 0.5,
        size: 1.5 + rng.nextDouble(),
      ));
    }
  }

  @override
  void update(double dt) {
    _timer += dt;
    for (final p in _particles) {
      p.angle += p.speed * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    for (final p in _particles) {
      final pos = center + Offset(cos(p.angle) * p.radius, sin(p.angle) * p.radius);

      // Glow
      canvas.drawCircle(pos, p.size * 3, Paint()
        ..color = const Color(0x20FFD700)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2));

      // Body
      canvas.drawCircle(pos, p.size, Paint()
        ..color = const Color(0xCCFFD700));
    }
  }
}

class _OrbitalParticle {
  double angle;
  double radius;
  double speed;
  double size;
  _OrbitalParticle({required this.angle, required this.radius, required this.speed, required this.size});
}
```

- [ ] **Step 2: Tower'da sinerji parçacıkları yönet**

Sinerji aktif/pasif olduğunda SynergyParticles component'ını ekle/kaldır.

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/effects/synergy_particles.dart lib/game/components/towers/tower.dart
git commit -m "feat: orbital golden particles for active tower synergies"
```

---

### Task 19: Final entegrasyon ve test

**Files:**
- Modify: `lib/game/kale_game.dart` — tüm yeni sistemlerin initialize sırası
- Modify: `lib/main.dart` — gerekirse

- [ ] **Step 1: KaleGame.onLoad initialize sırasını düzenle**

```dart
@override
Future<void> onLoad() async {
  // 1. Biome belirle
  final biome = _difficulty.biome;

  // 2. Sprite generators initialize
  await TowerSpriteGenerator.instance.initialize();
  await EnemySpriteGenerator.instance.initialize();
  await CastleSpriteGenerator.instance.initialize();

  // 3. Map + tile cache (biome ile)
  await SpriteCache.instance.initialize(biome: biome);

  // 4. Parallax background
  add(ParallaxBackground(biome: biome, gameWidth: _gameWidth, gameHeight: _gameHeight));

  // 5. Screen shake
  screenShake = ScreenShake();
  add(screenShake);

  // 6. Mevcut game setup (map, castle, systems)
  // ... mevcut kod
}
```

- [ ] **Step 2: Flutter build test**

```bash
cd kale_kronikleri
flutter analyze
flutter build apk --debug
```

Tüm compile hatalarını düzelt.

- [ ] **Step 3: Emülatörde test**

```bash
flutter run
```

Her biome'u test et (farklı zorluk seviyeleri seç). Kontrol listesi:
- [ ] Kuleler sprite olarak render ediliyor
- [ ] Düşmanlar sprite olarak yürüyor
- [ ] Kale sprite olarak görünüyor, hasar aşamaları çalışıyor
- [ ] Biome renkleri doğru uygulanıyor
- [ ] Parallax arka plan çalışıyor
- [ ] UI glassmorphism blur efekti var
- [ ] Screen shake çalışıyor
- [ ] Sinerji parıltısı çalışıyor
- [ ] Mermi trail'leri geliştirilmiş
- [ ] Performans kabul edilebilir (60 FPS civarı)

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete 2026 modernization - sprites, biomes, glassmorphism, effects"
```
