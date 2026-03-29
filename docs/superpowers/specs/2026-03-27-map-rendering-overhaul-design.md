# Map Rendering Overhaul - Design Spec

## Problem
Current procedural sprites (128x128 Canvas primitives displayed at 40x40) look flat and "Atari-like". Each cell renders independently creating visible grid lines. No terrain transitions, no depth, no atmosphere.

## Goal
Professional tower defense quality map rendering with seamless terrain, smooth transitions, decorative objects, and atmosphere. Support Leonardo.ai tileable textures with procedural fallback.

## Architecture

### Rendering Pipeline (bottom to top)
1. **MapGroundLayer** - Single full-map canvas, replaces per-cell ground rendering
2. **MapDecorationLayer** - Trees, rocks, bushes as separate sprites on top
3. **MapAtmosphereLayer** - Vignette, edge shadows, fog effects
4. GridCell remains for tap detection + tower placement highlight only

### MapGroundLayer (new, replaces ground rendering in GridCell)
- Renders entire 768x448 map as one canvas pass
- **Texture mode**: Loads tileable PNGs from `assets/images/textures/{biome}/`
  - `grass.png` (512x512, seamless tileable)
  - `path.png` (512x512, seamless cobblestone)
  - `blocked.png` (512x512, seamless dark terrain)
  - `spawn.png` (256x256, portal effect)
- **Fallback mode**: Enhanced procedural generation (Perlin noise multi-octave)
- Tiling: Seamless repeat across map area (not stretch, not random crop)
- Terrain transitions: Alpha gradient masks at cell boundaries (8-12px feather)
- Path rendering: Clip path with rounded corners + edge shadows + debris

### MapDecorationLayer (new)
- Scatter decorative sprites on buildable and blocked cells
- Trees (pine, dead tree), rocks, bushes, flowers
- Procedurally placed with deterministic seed per map
- Rendered as individual Flame components with shadow underneath
- Does NOT render on path or spawn cells

### Texture Loading (SpriteCache extension)
- Check `assets/images/textures/{biome}/grass.png` etc.
- If exists: load and use for tiling
- If not: generate enhanced procedural texture (Perlin noise based, 512x512)
- Biome names: forest, desert, snow, volcano, dark

### GridCell Changes
- Remove ground rendering (delegated to MapGroundLayer)
- Keep: tap detection, placement highlight shader, tower anchor
- Keep: priority ordering for tower/enemy rendering

### Enhanced Procedural Textures (fallback)
- 512x512 generated textures (4x current resolution)
- Multi-octave Perlin noise for natural variation
- Grass: 4 noise octaves + color variation + subtle blade pattern
- Path: Irregular cobblestone grid + mortar lines + wear
- Blocked: Dark earth + rock deposits + moss patches
- All seamlessly tileable (wrap-around noise)

### Terrain Transitions
- Where grass meets path: 8px alpha gradient feathering
- Where grass meets blocked: 6px shadow + slight color shift
- Path edges: inner shadow (ambient occlusion feel)
- Implemented via gradient shaders in MapGroundLayer.render()

### Atmosphere
- Subtle vignette around map edges (darken corners)
- Path edge rubble/debris particles (existing, improved)
- Blocked cell raised appearance (shadow on south/east edges)

## File Structure
- `lib/game/components/map/map_ground_layer.dart` - Full-map ground renderer
- `lib/game/components/map/map_decoration_layer.dart` - Decorative objects
- `lib/game/rendering/sprite_cache.dart` - Add texture loading + enhanced procedural
- `lib/game/rendering/perlin_noise.dart` - Proper Perlin noise implementation
- `lib/game/components/map/grid_cell.dart` - Strip ground rendering
- `lib/game/components/map/game_map.dart` - Wire up new layers
- `assets/images/textures/forest/` - Leonardo texture directory (initially empty)

## Constraints
- Game viewport: 768x538 (768x448 map + 90px sky)
- Grid: 12x7, cell size 64px
- Must maintain tap detection on GridCell
- Must support all 5 biomes
- APK size: textures optional, procedural always available
- Performance: pre-render ground to cached image, redraw only on map change
