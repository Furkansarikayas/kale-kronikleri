# Map Rendering Overhaul Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flat per-cell procedural sprites with a professional full-map rendering system featuring seamless tiling, terrain transitions, decorative objects, and Leonardo.ai texture support.

**Architecture:** MapGroundLayer renders the entire 768x448 map as one canvas pass with seamless texture tiling and alpha-blended terrain transitions. GridCell is stripped to tap detection + highlight only. SpriteCache gains texture loading from assets with procedural fallback.

**Tech Stack:** Flutter/Flame, dart:ui Canvas, Perlin noise, asset-based texture loading

---

## Chunk 1: Core Rendering Infrastructure

### Task 1: Perlin Noise Module

**Files:**
- Create: `lib/game/rendering/perlin_noise.dart`

- [ ] **Step 1: Create Perlin noise implementation**

```dart
import 'dart:math' as math;

/// Classic 2D Perlin noise - tileable, smooth, natural-looking.
class PerlinNoise {
  final List<int> _perm;

  PerlinNoise({int seed = 0}) : _perm = _buildPermutation(seed);

  static List<int> _buildPermutation(int seed) {
    final rng = math.Random(seed);
    final p = List<int>.generate(256, (i) => i);
    p.shuffle(rng);
    return [...p, ...p]; // Double for wrapping
  }

  double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  double _lerp(double a, double b, double t) => a + t * (b - a);

  double _grad(int hash, double x, double y) {
    final h = hash & 3;
    final u = h < 2 ? x : y;
    final v = h < 2 ? y : x;
    return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
  }

  /// Returns noise value in range [-1, 1] for given (x, y).
  double noise2D(double x, double y) {
    final xi = x.floor() & 255;
    final yi = y.floor() & 255;
    final xf = x - x.floor();
    final yf = y - y.floor();
    final u = _fade(xf);
    final v = _fade(yf);

    final aa = _perm[_perm[xi] + yi];
    final ab = _perm[_perm[xi] + yi + 1];
    final ba = _perm[_perm[xi + 1] + yi];
    final bb = _perm[_perm[xi + 1] + yi + 1];

    return _lerp(
      _lerp(_grad(aa, xf, yf), _grad(ba, xf - 1, yf), u),
      _lerp(_grad(ab, xf, yf - 1), _grad(bb, xf - 1, yf - 1), u),
      v,
    );
  }

  /// Multi-octave fractal noise (fBm). Returns [0, 1].
  double fbm(double x, double y, {int octaves = 4, double lacunarity = 2.0, double gain = 0.5}) {
    double sum = 0, amp = 1, freq = 1, maxAmp = 0;
    for (int i = 0; i < octaves; i++) {
      sum += noise2D(x * freq, y * freq) * amp;
      maxAmp += amp;
      amp *= gain;
      freq *= lacunarity;
    }
    return (sum / maxAmp + 1) * 0.5; // Normalize to [0, 1]
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `dart analyze lib/game/rendering/perlin_noise.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/game/rendering/perlin_noise.dart
git commit -m "feat: add Perlin noise module for realistic terrain generation"
```

---

### Task 2: Enhanced SpriteCache with Texture Loading

**Files:**
- Modify: `lib/game/rendering/sprite_cache.dart`

- [ ] **Step 1: Add texture loading capability and enhanced procedural generation**

Key changes to SpriteCache:
1. Add `loadTexture(String assetPath)` method that loads PNG from assets
2. Add `_generateTerrainTexture(CellType, biome)` for 512x512 enhanced procedural
3. Add public getters: `grassTexture`, `pathTexture`, `blockedTexture`, `spawnTexture`
4. Use Perlin noise instead of value noise for organic look
5. Increase sprite size from 128 to 512 for detail
6. Keep existing per-cell tile generation for backward compat

The texture loading checks `assets/images/textures/{biome}/grass.png` etc. If not found, generates enhanced procedural 512x512 textures using PerlinNoise.

- [ ] **Step 2: Create asset directories**

```bash
mkdir -p assets/images/textures/forest
```

- [ ] **Step 3: Update pubspec.yaml to include texture assets**

Add to pubspec.yaml flutter.assets:
```yaml
    - assets/images/textures/
    - assets/images/textures/forest/
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze`

- [ ] **Step 5: Commit**

```bash
git add lib/game/rendering/sprite_cache.dart pubspec.yaml assets/
git commit -m "feat: add texture loading + enhanced procedural generation to SpriteCache"
```

---

### Task 3: MapGroundLayer - Full Map Renderer

**Files:**
- Rewrite: `lib/game/components/map/map_ground_layer.dart`

- [ ] **Step 1: Implement MapGroundLayer**

This is the core component. It replaces per-cell ground rendering with a single full-map canvas pass:

1. **Base terrain**: Tile grass texture seamlessly across entire map (no stretch!)
2. **Path rendering**: Build a Path from all path/pathBuildable cells with rounded corners, clip canvas, tile path texture inside
3. **Blocked terrain**: Tile blocked texture on blocked cells with darkening overlay
4. **Spawn cells**: Draw spawn texture with glow effect
5. **Castle cells**: Draw castle ground with golden tint
6. **Terrain transitions**: Alpha gradient feathering at grass↔path and grass↔blocked borders (8px soft edge)
7. **Path edge shadows**: Inner shadow gradients on path edges for depth
8. **Path debris**: Small rubble particles at path-grass borders

Key rendering approach for tiling (NOT stretch):
```dart
// Tile texture across area using drawImageRect with modular src coords
void _tileTexture(Canvas canvas, ui.Image tex, Rect area) {
  final tw = tex.width.toDouble();
  final th = tex.height.toDouble();
  for (double y = area.top; y < area.bottom; y += th) {
    for (double x = area.left; x < area.right; x += tw) {
      final dstW = math.min(tw, area.right - x);
      final dstH = math.min(th, area.bottom - y);
      canvas.drawImageRect(
        tex,
        Rect.fromLTWH(0, 0, dstW, dstH),
        Rect.fromLTWH(x, y, dstW, dstH),
        _texPaint,
      );
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/map/map_ground_layer.dart
git commit -m "feat: implement MapGroundLayer full-map renderer with tiling + transitions"
```

---

### Task 4: Strip GridCell Ground Rendering

**Files:**
- Modify: `lib/game/components/map/grid_cell.dart`

- [ ] **Step 1: Remove ground rendering from GridCell**

GridCell should only handle:
- Tap detection (position, size remain)
- Placement highlight (green glow when tower selected)
- No more sprite rendering, no terrain edges

Remove: `_renderSprite`, `_drawBuildable`, `_drawPath`, `_drawPathBuildable`, `_drawBlocked`, `_drawSpawn`, `_drawCastleGround`, `_drawPathEdges`, `_drawTerrainEdgeShadows`, `_renderFallback`, `_blitImage`, `_fillColor`, neighbor fields.

Keep: `render()` with only highlight, `_renderHighlight()`, `col`, `row`, `cellType`, `highlighted`.

- [ ] **Step 2: Verify it compiles**

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/map/grid_cell.dart
git commit -m "refactor: strip GridCell to tap detection + highlight only"
```

---

### Task 5: Wire Up GameMap with New Layers

**Files:**
- Modify: `lib/game/components/map/game_map.dart`

- [ ] **Step 1: Add MapGroundLayer to GameMap**

In `generate()` method:
1. Create and add `MapGroundLayer(grid: grid, cellSize: cellSize)` with priority -1
2. GridCells still added for tap detection (priority 0)
3. Remove neighbor setup code (no longer needed)

```dart
void generate({required int seed, int spawnCount = 1}) {
  final result = MapGenerator.generate(seed: seed, spawnCount: spawnCount);
  grid = result.grid;
  // ... existing path computation ...

  // Ground layer renders entire map seamlessly
  add(MapGroundLayer(grid: grid, cellSize: cellSize));

  // GridCells for tap detection only
  for (int r = 0; r < GameConfig.gridRows; r++) {
    for (int c = 0; c < GameConfig.gridColumns; c++) {
      add(GridCell(col: c, row: r, cellType: grid[r][c], cellSize: cellSize));
    }
  }
}
```

- [ ] **Step 2: Verify full app compiles**

Run: `flutter build apk --debug`

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/map/game_map.dart
git commit -m "feat: wire MapGroundLayer into GameMap, GridCell for tap only"
```

---

## Chunk 2: Decorations & Polish

### Task 6: MapDecorationLayer

**Files:**
- Create: `lib/game/components/map/map_decoration_layer.dart`

- [ ] **Step 1: Implement decoration layer**

Scatter decorative elements on buildable and blocked cells:
- Pine trees on blocked cells (procedural: triangle canopy + trunk)
- Rock clusters on blocked cells
- Small flowers/mushrooms on buildable cells (subtle)
- Shadow underneath each decoration (ellipse, alpha 0x20)
- Deterministic placement using `Random(col * 7 + row * 13)`
- No decorations on path, spawn, or castle cells

- [ ] **Step 2: Add to GameMap**

Add MapDecorationLayer after GridCells with priority 1.

- [ ] **Step 3: Verify and commit**

```bash
git add lib/game/components/map/map_decoration_layer.dart lib/game/components/map/game_map.dart
git commit -m "feat: add decorative trees, rocks, flowers layer"
```

---

### Task 7: Visual Polish Pass

**Files:**
- Modify: `lib/game/components/map/map_ground_layer.dart`

- [ ] **Step 1: Add atmosphere effects**

1. Vignette: darken map edges with radial gradient overlay
2. PathBuildable: subtle green shimmer overlay
3. Castle area: golden ambient glow
4. Spawn: pulsing red glow (animated)

- [ ] **Step 2: Build, install, screenshot test on emulator**

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

- [ ] **Step 3: Commit**

```bash
git add lib/game/components/map/map_ground_layer.dart
git commit -m "feat: add atmosphere effects - vignette, glow, polish"
```

---

### Task 8: Cleanup & Integration Test

- [ ] **Step 1: Delete unused map_ground_layer.dart backup if exists**
- [ ] **Step 2: Remove unused imports from sprite_cache.dart**
- [ ] **Step 3: Full build + emulator test**
- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: cleanup unused code after map rendering overhaul"
```
