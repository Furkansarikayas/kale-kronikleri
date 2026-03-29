# Kale Kronikleri - Sprite Generation Guide (AI Image Generators)

> **Target Tools:** Midjourney v6+ / Stable Diffusion XL (SDXL) / FLUX
> **Art Style:** Stylized 2D (Hades / Dead Cells inspired)
> **Color Palette:** Dark fantasy base + neon glow highlights
> **Perspective:** Top-down with ~30 degree angle (isometric-lite)
> **Game Engine:** Flutter / Flame (2D)

---

## Directory Structure

All generated sprites must be saved under `assets/images/` with this layout:

```
assets/images/
├── towers/
│   ├── arrow_t1.png
│   ├── arrow_t2.png
│   ├── arrow_t3.png
│   ├── arrow_t4.png
│   ├── fire_t1.png
│   ├── ... (12 types × 4 tiers = 48 files)
│
├── enemies/
│   ├── soldier.png
│   ├── cavalry.png
│   ├── goblin.png
│   ├── armored_giant.png
│   ├── undead.png
│   ├── shield_bearer.png
│   ├── healer.png
│   ├── burrower.png
│   ├── troll.png
│   ├── dark_knight.png
│   ├── shadow_lord.png
│   └── dragon_emperor.png
│
├── castle/
│   ├── castle_phase0.png
│   ├── castle_phase1.png
│   └── castle_phase2.png
│
├── effects/
│   ├── explosion.png
│   ├── ice_burst.png
│   ├── lightning_strike.png
│   ├── poison_cloud.png
│   ├── fire_trail.png
│   ├── holy_smite.png
│   ├── dark_curse.png
│   └── water_splash.png
│
└── ui/
    └── (icons, panels — separate guide)
```

---

## Global Art Direction

### Base Prompt Prefix (use for ALL sprites)

Add this to the beginning of every prompt to maintain style consistency:

```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, rich shadows with vibrant neon glow accents, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges, no anti-aliasing artifacts on borders --no background, floor, ground, shadow on ground
```

### Color Palette Reference

| Element          | Primary Hex | Glow/Accent Hex | Description |
|------------------|-------------|-----------------|-------------|
| Background       | `#050510`   | `#0a0e1a`       | Deep navy/black |
| Ground/Terrain   | `#0d1a0d`   | `#1a2a1a`       | Dark forest green |
| Path/Road        | `#1a1510`   | `#3a3025`       | Dark brown/stone |
| UI Gold          | `#d4a843`   | `#f0e6d0`       | Warm gold |
| UI Text          | `#f0e6d0`   | —               | Cream white |

### Tower Neon Colors

| Tower       | Primary Neon  | Glow Accent   |
|-------------|---------------|---------------|
| Arrow       | `#d4a843`     | `#f0e6d0`     |
| Fire        | `#e94560`     | `#ff6b81`     |
| Ice         | `#4ecdc4`     | `#a0e6ff`     |
| Lightning   | `#a78bfa`     | `#c4b5fd`     |
| Poison      | `#2ecc71`     | `#a0ffa0`     |
| Water       | `#3498db`     | `#74b9ff`     |
| Dark        | `#8b5cf6`     | `#a78bfa`     |
| Holy        | `#ffd700`     | `#fff5e0`     |
| Cannon      | `#e67e22`     | `#f39c12`     |
| Wizard      | `#9b59b6`     | `#c084fc`     |
| Support     | `#ffd700`     | `#fff8e0`     |
| Spike Wall  | `#7f8c8d`     | `#95a5a6`     |

---

## 1. Tower Sprites

**Total needed:** 12 types x 4 tiers = 48 sprites
**Priority:** Start with Tier 1 (12 sprites), then expand to higher tiers.
**Size:** 256 x 256 pixels, transparent background (PNG)
**View:** Top-down with slight ~30 degree angle

General tower design rules:
- Each tower sits on a small circular or hexagonal stone base
- Tier 1 = simple, Tier 2 = refined, Tier 3 = elaborate, Tier 4 = epic/legendary with heavy glow
- The neon color for each tower should glow from its core/emitter, not paint the whole structure
- Dark stone/metal body with neon energy highlights

---

### 1.1 Arrow Tower (Ok Kulesi)

**Neon Color:** Gold `#d4a843` / `#f0e6d0`
**Tier Names:** Ok Kulesi > Keskin Nisanci > Coklu Ok > Firtina Yagmuru
**Stats Context:** Fast fire rate (0.6s), medium range, basic damage. The quintessential starting tower.

#### Tier 1 — `towers/arrow_t1.png`

**Description:** A compact medieval watchtower made of dark grey stone, topped with a mounted crossbow mechanism. A single golden-glowing arrow rests in the firing slot. Simple, functional design.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a small medieval stone watchtower with a mounted crossbow on top, dark grey stone bricks, warm golden glow emanating from the arrow slot, single golden neon arrow loaded, simple and compact design, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/arrow_t2.png`

**Description:** Taller tower with reinforced walls. The crossbow is replaced by a sharpshooter's precision turret with an elongated golden-glowing scope/sight. Two golden arrows visible.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a refined medieval stone tower with a precision crossbow turret on top, dark stone with iron reinforcements, elongated golden-glowing scope on the turret, two luminous golden arrows visible, sharper more angular design than basic version, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/arrow_t3.png`

**Description:** Multi-barrel arrow launcher. Three crossbow arms arranged in a fan pattern, each loaded with golden-glowing arrows. Stone base has golden rune engravings that glow faintly.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a multi-barrel arrow tower with three crossbow arms arranged in a fan pattern, dark stone and iron construction, each arm loaded with glowing golden arrows, golden rune engravings on the stone base that emit faint light, ornate medieval mechanical design, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/arrow_t4.png`

**Description:** Legendary storm tower. A swirling golden energy vortex sits atop a tall dark spire. Dozens of spectral golden arrows orbit the vortex. Intense golden glow radiates outward. Epic, awe-inspiring design.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary arrow storm tower, tall dark stone spire with a swirling golden energy vortex at the top, dozens of spectral glowing golden arrows orbiting the vortex, intense golden neon glow radiating outward, golden lightning crackling from the vortex, epic and awe-inspiring dark fantasy design, hexagonal stone base with golden runes, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.2 Fire Tower (Ates Kulesi)

**Neon Color:** Crimson Red `#e94560` / `#ff6b81`
**Tier Names:** Ates Kulesi > Alev Topu > Yangin > Cehennem Atesi
**Stats Context:** AoE fire damage, moderate fire rate (1.5s). Burns enemies.

#### Tier 1 — `towers/fire_t1.png`

**Description:** A squat stone brazier tower with an iron fire bowl on top. A crimson-red flame burns in the bowl, casting a red neon glow. Dark charred stone base.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a squat dark stone brazier tower with an iron fire bowl on top, a vibrant crimson-red flame burning in the bowl, red neon glow emanating from the fire, charred blackened stone base, embers floating upward, simple medieval fire tower design, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/fire_t2.png`

**Description:** Taller tower with a mounted catapult arm holding a flaming boulder. The stone is heat-cracked with red-orange glow seeping through the cracks.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a medieval fire tower with a mounted catapult arm holding a glowing crimson fireball, dark stone walls with heat cracks showing red-orange glow seeping through, iron fittings and chains, hot embers rising, more elaborate than a simple brazier, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/fire_t3.png`

**Description:** A dark volcanic tower with multiple fire vents. Molten lava veins run down its surface. A rotating fire ring crowns the top. Intense heat distortion around it.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a volcanic dark stone tower with multiple fire vents, molten lava veins running down its obsidian surface, a rotating ring of crimson fire crowning the top, intense red-orange neon glow, slag and ember particles, heat distortion effect around the tower, ornate volcanic design, circular obsidian base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/fire_t4.png`

**Description:** Hellfire spire. A demonic dark tower erupting with an inferno from its core. Crimson hellfire swirls around a dark iron crown. Runic chains glow red-hot. The entire tower is wreathed in flame.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary hellfire spire tower, demonic dark iron and obsidian construction, erupting crimson hellfire inferno from its core, a dark iron crown at the top wreathed in swirling crimson flames, red-hot glowing runic chains wrapped around the tower, intense neon crimson red glow, epic demonic dark fantasy design, hexagonal obsidian base with lava veins, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.3 Ice Tower (Buz Kulesi)

**Neon Color:** Cyan `#4ecdc4` / `#a0e6ff`
**Tier Names:** Buz Kulesi > Don Halkasi > Buzul > Mutlak Sifir
**Stats Context:** Low damage but slows enemies. Control-oriented tower.

#### Tier 1 — `towers/ice_t1.png`

**Description:** A short stone tower encrusted with ice crystals. A cyan-glowing ice crystal orb floats just above the top. Frost particles drift downward. Cool blue neon glow.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a short dark stone tower encrusted with ice crystals, a levitating cyan-glowing ice crystal orb above the tower top, frost particles drifting downward, cool cyan and light blue neon glow, frozen stone surface, simple ice tower design, circular frost-covered stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/ice_t2.png`

**Description:** A frozen ring structure sits atop the tower, spinning slowly. Ice shards orbit the ring. The tower's stone is heavily frosted with visible ice veins.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a dark stone tower with a spinning frozen ice ring at the top, ice shards orbiting the ring, heavily frosted stone walls with visible cyan ice veins, cold mist emanating from the structure, cyan and pale blue neon glow, refined ice tower design, circular frost-covered stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/ice_t3.png`

**Description:** A glacial spire of pure dark ice. Multiple large ice crystals jut from its surface. The top has a concentrated blizzard vortex. The whole structure pulses with pale blue energy.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a glacial spire made of dark translucent ice, multiple large ice crystals jutting outward from its surface, a concentrated blizzard vortex at the top, pale blue and cyan energy pulsing through the structure, frozen mist and snowflakes swirling around it, elaborate ice palace tower design, hexagonal frosted base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/ice_t4.png`

**Description:** Absolute Zero tower. A towering crystalline structure of impossible ice geometry. The core is a singularity of cold — a black void surrounded by intensely glowing cyan energy. Everything around it is frozen in mid-air.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary absolute zero tower, towering crystalline structure of impossible fractal ice geometry, a dark void singularity at its core surrounded by intensely glowing cyan neon energy, frozen particles suspended in mid-air around it, ice crystal formations radiating outward, overwhelming cold power aura, epic crystalline dark fantasy design, hexagonal base encased in permafrost, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.4 Lightning Tower (Yildirim Kulesi)

**Neon Color:** Purple `#a78bfa` / `#c4b5fd`
**Tier Names:** Yildirim > Kivilcim > Simsek > Tanri Ofkesi
**Stats Context:** High single-target damage (20), moderate fire rate. Chain lightning potential.

#### Tier 1 — `towers/lightning_t1.png`

**Description:** A dark stone pylon with a copper Tesla coil on top. Purple-violet electricity arcs between two metal rods. Simple industrial-medieval hybrid look.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a dark stone pylon tower with a copper Tesla coil on top, purple-violet electrical arcs crackling between two metal rods, industrial medieval hybrid design, purple neon glow from the electrical discharge, dark iron and stone construction, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/lightning_t2.png`

**Description:** A taller conductor tower with multiple spark nodes. Purple energy crackles between them in a web pattern. The metal has an oxidized purple-blue patina.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a tall conductor tower with multiple spark nodes at different heights, purple-violet energy crackling in a web pattern between nodes, oxidized purple-blue patina on the metal framework, more elaborate coil design, brighter purple neon glow, circular stone base with copper inlays, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/lightning_t3.png`

**Description:** A storm spire with a floating purple energy sphere at its peak. Constant lightning bolts discharge from the sphere. The tower hums with crackling energy, with arcs running down its surface.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a storm spire tower with a floating purple energy sphere at its peak, constant lightning bolts discharging from the sphere, purple electrical arcs running down the tower surface, metal and dark stone construction crackling with energy, intense violet neon glow, elaborate storm tower design, hexagonal stone base with lightning runes, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/lightning_t4.png`

**Description:** Wrath of God tower. A massive dark obelisk channeling a perpetual purple lightning storm. A divine eye symbol glows at its core. Multiple thick lightning bolts arc outward. Reality seems to distort around it.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary divine wrath lightning obelisk, massive dark stone monolith channeling a perpetual purple lightning storm above it, a glowing divine eye symbol at its core, multiple thick purple lightning bolts arcing outward, reality distortion effect around the tower, intense violet and lavender neon glow, epic godlike dark fantasy design, hexagonal base with electric rune circle, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.5 Poison Tower (Zehir Kulesi)

**Neon Color:** Green `#2ecc71` / `#a0ffa0`
**Tier Names:** Zehir Kulesi > Curutme > Veba > Nekroz
**Stats Context:** Very low damage but applies DoT (damage over time). Fast fire rate. Unlocks at wave 3.

#### Tier 1 — `towers/poison_t1.png`

**Description:** A dark stone tower with a bubbling cauldron on top. Toxic green liquid overflows slightly. Green neon vapor rises from the cauldron. Mossy, decayed stone.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a dark stone tower with a bubbling cauldron on top filled with toxic green liquid, green neon vapor rising from the cauldron, overflowing green droplets, mossy decayed stone walls, alchemical pipes and tubes, green neon glow, circular mossy stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/poison_t2.png`

**Description:** A corroded tower with multiple poison nozzles. Green slime drips down the walls. A central tank of toxic green liquid glows within the structure.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a corroded dark stone tower with multiple poison spray nozzles, green toxic slime dripping down the walls, a central glass tank of glowing green toxic liquid visible within the structure, alchemical tubes and valves, brighter green neon glow, circular decayed stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/poison_t3.png`

**Description:** A plague tower — dark and menacing with a skull motif. A pestilent green cloud permanently surrounds the top. Multiple vents spew green gas. Bones and dead vegetation at the base.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a menacing plague tower with a skull motif carved into the dark stone, a permanent pestilent green cloud surrounding the top, multiple vents spewing green toxic gas, bones and dead vegetation at the base, intense toxic green neon glow, dark and sinister design, hexagonal corroded stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/poison_t4.png`

**Description:** Necrosis tower. A towering structure of bone and corrupted stone. The entire tower is alive with pulsating green necrotic energy. A massive green-glowing skull crowns the top, mouth agape spewing toxic miasma. Death incarnate.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary necrosis tower made of bone and corrupted dark stone, pulsating green necrotic energy running through its structure like veins, a massive glowing green skull crowning the top with mouth agape spewing toxic green miasma, death-themed ornaments and bone protrusions, intense neon green glow, epic necromantic dark fantasy design, hexagonal base of skulls and corrupted earth, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.6 Water Tower (Su Kulesi)

**Neon Color:** Blue `#3498db` / `#74b9ff`
**Tier Names:** Su Kulesi > Sel > Tsunami > Girdap
**Stats Context:** Medium damage, pushback/knockback effect. Unlocks wave 5.

#### Tier 1 — `towers/water_t1.png`

**Description:** A stone fountain tower. Water spirals upward from a central basin. Blue neon glow from the water. Wet, mossy stone with flowing water channels.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a dark stone fountain tower with water spiraling upward from a central basin, blue neon glow from the water, wet mossy stone walls with carved water channels, flowing water streams, mystical aquatic design, circular wet stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/water_t2.png`

**Description:** A flood tower with pressurized water cannons. Two water jets cross at the top. The structure looks like a dam/sluice gate hybrid.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a pressurized water tower with dual water cannon nozzles, two glowing blue water jets crossing at the top, dam and sluice gate hybrid design, dark stone with metal water pipes and valves, blue neon glow from pressurized water, circular wet stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/water_t3.png`

**Description:** A tsunami tower with a massive cresting wave frozen in time around the spire. Water energy spirals upward in a helix. Deep blue glow pulsates from within.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a tsunami tower with a massive cresting wave of blue energy frozen around the dark stone spire, water energy spiraling upward in a helix pattern, deep blue neon glow pulsating from within, sea foam and water droplets suspended in air, elaborate oceanic dark fantasy design, hexagonal wet stone base with wave carvings, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/water_t4.png`

**Description:** Maelstrom tower. A dark tower at the eye of a perpetual whirlpool vortex. Water spirals violently around it. A glowing blue orb of compressed ocean energy sits at its core. Immense power.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary maelstrom tower at the eye of a perpetual water whirlpool vortex, water spiraling violently around the dark spire, a glowing compressed blue energy orb at the tower core, sea creatures and debris caught in the vortex, intense blue neon glow, epic oceanic dark fantasy design, hexagonal base surrounded by whirlpool, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.7 Dark Tower (Karanlik Kule)

**Neon Color:** Deep Purple `#8b5cf6` / `#a78bfa`
**Tier Names:** Karanlik > Golge > Lanet > Ucurum
**Stats Context:** Debuffs enemies (armor reduction). Unlocks at wave 11.

#### Tier 1 — `towers/dark_t1.png`

**Description:** A crooked dark tower leaning slightly. A shadowy purple aura emanates from a cracked dark crystal at its peak. Shadowy wisps trail from the cracks in the stone.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a crooked dark tower leaning slightly, a cracked dark crystal at its peak emanating a shadowy deep purple aura, shadowy purple wisps trailing from cracks in the dark stone, ominous and unsettling design, deep purple neon glow, circular dark stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/dark_t2.png`

**Description:** A shadow tower with tendrils of dark energy reaching outward. A glowing purple eye motif on its face. The stone seems to absorb light around it.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a shadow tower with dark energy tendrils reaching outward from its body, a glowing purple eye motif on its front face, the ultra-dark stone seems to absorb light, deeper shadows than surrounding area, purple neon glow from the eye and tendrils, menacing design, circular dark stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/dark_t3.png`

**Description:** A curse tower wreathed in dark purple runes that orbit the structure. Chains of shadow connect it to the ground. A void orb hovers above, distorting space around it.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a curse tower wreathed in orbiting dark purple runic symbols, chains of shadow connecting the tower to the ground, a void orb hovering above the tower distorting space around it, deep purple and black neon glow, extremely dark and ominous design, hexagonal dark stone base with curse circles, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/dark_t4.png`

**Description:** The Abyss tower. A rift in reality itself, anchored by dark crystalline pillars. A tear in space reveals a swirling purple void dimension within. Dark energy pours outward. Eldritch and terrifying.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary abyss tower, a rift in reality anchored by dark crystalline pillars, a tear in space revealing a swirling purple void dimension within, dark energy pouring outward from the rift, eldritch tentacles of shadow reaching from the void, intense deep purple neon glow, terrifying eldritch dark fantasy design, hexagonal base with void cracks, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.8 Holy Tower (Kutsal Kule)

**Neon Color:** Gold `#ffd700` / `#fff5e0`
**Tier Names:** Kutsal > Rahip > Aziz > Isik Kalesi
**Stats Context:** Bonus damage vs undead/dark. Unlocks wave 13.

#### Tier 1 — `towers/holy_t1.png`

**Description:** A white marble and gold tower with a small golden cross or sun emblem at its peak. Warm golden holy light radiates from the emblem. Clean, pristine design contrasting the dark world.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a white marble and gold tower with a golden sun emblem at its peak, warm golden holy light radiating from the emblem, pristine clean design contrasting the dark world, white stone with gold trim, golden neon glow, sacred and noble design, circular marble base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/holy_t2.png`

**Description:** A priest's tower with stained-glass window elements. A hovering golden scripture circle orbits the top. The light is brighter and more divine.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a holy priest tower with stained-glass window elements in the white marble walls, a hovering golden scripture circle orbiting the top, brighter divine golden light, ornate religious architecture, gold and white color scheme with golden neon glow, circular marble base with golden inlays, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/holy_t3.png`

**Description:** A saint's tower with angelic wing motifs carved into the stone. Multiple golden halos stack above the tower. Beams of golden light shoot upward. Holy relics embedded in the walls.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a saint's tower with angelic wing motifs carved into white marble, multiple golden halos stacking above the tower, beams of golden light shooting upward, holy relics embedded in the walls, elaborate sacred architecture, intense golden neon glow, hexagonal marble base with holy symbols, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/holy_t4.png`

**Description:** Castle of Light. A magnificent white-gold cathedral tower. A blinding golden sun hovers above, casting divine rays in all directions. Angelic energy swirls around it. The ultimate bastion of light against darkness.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary castle of light, magnificent white-gold cathedral tower, a blinding golden sun hovering above casting divine rays in all directions, angelic energy swirling around the structure, intricate sacred gothic architecture, overwhelming golden neon glow, the ultimate bastion of light, epic divine dark fantasy design, hexagonal marble base with radiating holy runes, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.9 Cannon Tower (Topcu Kulesi)

**Neon Color:** Orange `#e67e22` / `#f39c12`
**Tier Names:** Topcu > Havan > Kusatma > Meteor
**Stats Context:** Highest single-hit damage (40), long range (5.0), very slow fire rate (2.5s). Unlocks wave 7.

#### Tier 1 — `towers/cannon_t1.png`

**Description:** A sturdy stone fortress tower with a heavy iron cannon barrel protruding from the top. Orange glow from the cannon's muzzle. Ammunition crates visible. Military, industrial design.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a sturdy dark stone fortress tower with a heavy iron cannon barrel protruding from the top, orange neon glow from the cannon muzzle, ammunition crates visible, military industrial medieval design, iron and stone construction, circular reinforced stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/cannon_t2.png`

**Description:** A mortar emplacement tower with an upward-angled barrel. Larger caliber, reinforced iron plating. Orange sparks and smoke from the barrel.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a mortar emplacement tower with an upward-angled heavy barrel, larger caliber than basic cannon, reinforced iron plating and rivets, orange sparks and smoke wisps from the barrel, heavy military design, orange neon glow from the heated barrel, circular reinforced stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/cannon_t3.png`

**Description:** A siege engine tower with dual massive barrels. Mechanical gears and chains visible. A glowing orange furnace feeds the weapons. Fortified with heavy armor plating.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a siege engine tower with dual massive cannon barrels, mechanical gears and chains visible in the mechanism, a glowing orange furnace feeding the weapons, heavy armor plating and fortification, steam and smoke effects, intense orange neon glow, elaborate military fortress design, hexagonal armored base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/cannon_t4.png`

**Description:** Meteor tower. A colossal dark iron launcher aimed at the sky. Instead of cannonballs, it fires meteors — a glowing orange-hot meteor is loaded and ready. The mechanism is part magic, part machine. Devastating.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary meteor launcher tower, colossal dark iron and stone construction, aimed skyward with a glowing orange-hot meteor loaded and ready to fire, magical runes and mechanical gears working together, molten orange energy coursing through the structure, fire and smoke effects, overwhelming orange neon glow, epic apocalyptic dark fantasy design, hexagonal reinforced base with blast marks, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.10 Wizard Tower (Buyucu Kulesi)

**Neon Color:** Purple/Magenta `#9b59b6` / `#c084fc`
**Tier Names:** Buyucu > Cirak > Usta > Ars Buyucu
**Stats Context:** Moderate damage, magical attacks. Unlocks wave 9.

#### Tier 1 — `towers/wizard_t1.png`

**Description:** A classic wizard's tower with a conical roof. A floating purple arcane orb at the window. Books and scrolls visible through an arched opening. Mystical, scholarly atmosphere.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a classic wizard tower with a conical slate roof, a floating purple-magenta arcane orb visible through an arched window, books and scrolls inside, mystical scholarly atmosphere, dark stone with purple magical rune accents, purple-magenta neon glow from the orb, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/wizard_t2.png`

**Description:** An apprentice's improved tower. Multiple arcane orbs orbit the structure. Magical glyphs glow on the walls. A crystal ball sits at the top emitting purple energy beams.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
an apprentice wizard tower with multiple purple arcane orbs orbiting the structure, magical glyphs glowing on the dark stone walls, a crystal ball at the top emitting purple-magenta energy beams, more refined arcane architecture, purple and magenta neon glow, circular stone base with glyph circle, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/wizard_t3.png`

**Description:** A master wizard's tower. Floating stone segments held together by purple arcane energy. A massive spell circle hovers above. Arcane lightning connects the floating pieces.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a master wizard tower with floating stone segments held together by purple arcane energy, a massive spell circle hovering above the tower, arcane purple lightning connecting the floating pieces, magical particles and runes swirling, intense purple-magenta neon glow, elaborate arcane architecture, hexagonal base with arcane circle, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/wizard_t4.png`

**Description:** Archmage's Tower. A gravity-defying structure of floating obsidian slabs arranged in a spiral. At the center, a tear in the fabric of magic reveals pure arcane energy — a miniature galaxy of purple and magenta light. Overwhelming magical power.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary archmage tower, gravity-defying structure of floating obsidian slabs spiraling upward, at the center a tear in magical fabric revealing pure arcane energy like a miniature galaxy of purple and magenta light, overwhelming magical power radiating outward, arcane symbols orbiting the structure, intense purple and magenta neon glow, epic arcane dark fantasy design, hexagonal base with grand arcane circle, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.11 Support Tower (Destek Kulesi)

**Neon Color:** Gold `#ffd700` / `#fff8e0`
**Tier Names:** Destek > Destek II > Destek III > Destek IV
**Stats Context:** No damage, buffs nearby towers. Short range (1.0). Available from the start.

#### Tier 1 — `towers/support_t1.png`

**Description:** A small stone obelisk with a golden crystal at the top. Faint golden aura radiates outward in a small circle. Warm, supportive presence. Banner or flag with a golden emblem.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a small dark stone obelisk tower with a golden crystal at the top, faint golden aura radiating outward in a circle, a small banner with a golden emblem, warm supportive presence, gold neon glow, simple but noble design, circular stone base, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/support_t2.png`

**Description:** A taller beacon tower with a brighter golden crystal. Golden energy pulses outward in visible rings. Multiple small banners flutter.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a taller beacon tower with a brighter golden crystal at the top, golden energy pulses radiating outward in visible rings, multiple small banners fluttering, dark stone with golden trim, stronger golden neon glow, circular stone base with golden ring, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/support_t3.png`

**Description:** An ornate golden shrine tower. Multiple golden crystals orbit the central spire. A continuous golden aura field is visible. Angelic/holy military aesthetic.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
an ornate golden shrine tower with multiple golden crystals orbiting the central spire, a continuous golden aura field visible around it, angelic military aesthetic, white marble and gold construction, intense golden neon glow, elaborate support tower design, hexagonal marble base with golden runes, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/support_t4.png`

**Description:** A grand golden war standard — a magnificent pillar of light. The central crystal is massive and pulsates with golden energy that empowers everything nearby. Golden light beams reach outward. Inspiring and majestic.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary golden war standard tower, magnificent pillar of golden light, a massive pulsating golden crystal core that empowers everything nearby, golden light beams reaching outward in all directions, multiple golden banners and holy symbols, overwhelming golden neon glow, epic inspiring and majestic design, hexagonal marble base with radiating golden energy, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

### 1.12 Spike Wall (Dikenli Duvar)

**Neon Color:** Grey `#7f8c8d` / `#95a5a6`
**Tier Names:** Dikenli Duvar > Cit > Barikat > Kara Orman
**Stats Context:** No range, no fire rate — it's a passive obstacle that damages enemies passing through. Cheapest tower (40 gold).

#### Tier 1 — `towers/spike_wall_t1.png`

**Description:** A low dark stone wall segment with iron spikes protruding upward and outward. Simple, brutal, functional. Faint grey metallic sheen on the spikes.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a low dark stone wall segment with iron spikes protruding upward and outward, simple brutal and functional design, faint grey metallic sheen on the sharp spikes, blood stains on some spikes, dark stone and iron construction, subtle grey neon highlight on spike tips, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 2 — `towers/spike_wall_t2.png`

**Description:** A taller barbed fence with razor wire and longer spikes. Wooden and iron reinforcements. More menacing and fortified.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a tall barbed fence with razor wire and long iron spikes, wooden and iron reinforcement posts, more menacing and fortified than a basic wall, scattered bone fragments caught in the wire, grey metallic neon sheen on the blades, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 3 — `towers/spike_wall_t3.png`

**Description:** A heavy barricade of dark iron and stone, bristling with massive spikes. Skull trophies mounted on some spikes. The fortification looks nearly impenetrable.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a heavy barricade of dark iron and reinforced stone bristling with massive spikes, skull trophies mounted on some spikes, nearly impenetrable fortification appearance, heavy chains and iron bands, grey and silver neon sheen, menacing fortress barricade design, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

#### Tier 4 — `towers/spike_wall_t4.png`

**Description:** The Dark Forest. Living thorny vines of dark enchanted wood have grown into a wall of death. Sharp black thorns everywhere, some dripping with venom. Faintly glowing grey-green energy pulsates through the vines. Nature corrupted into a weapon.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style, hand-painted look inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a legendary dark forest wall, living thorny vines of dark enchanted wood grown into an impassable wall of death, sharp black thorns everywhere some dripping with venom, faintly glowing grey-green energy pulsating through the vines, corrupted nature as a weapon, skulls and armor fragments entangled in the thorns, grey and dark green neon glow, epic dark nature fantasy design, 256x256 pixels
--no background, floor, ground, shadow on ground
--ar 1:1
```

---

## 2. Enemy Sprites

**Total needed:** 12 enemy types
**Size:** 512 x 128 pixels (4 frames of 128x128 arranged horizontally — walking animation sprite sheet)
**View:** Top-down with slight ~30 degree angle
**Format:** PNG with transparent background

Design rules:
- Each enemy must have a unique, instantly recognizable silhouette
- Colors should contrast well against dark ground tiles
- Bosses should be larger/more detailed
- Easy enemies = simpler design, Hard/Boss = elaborate design
- The 4 frames should show a walking cycle: left foot forward, neutral, right foot forward, neutral (or a similar simple walk loop)

---

### 2.1 Soldier (Siradan Asker) — `enemies/soldier.png`

**Difficulty:** Easy | **HP:** 30 | **Speed:** Normal (1.0)

**Description:** A basic foot soldier in worn leather armor with a simple sword. Brownish-grey color scheme. Nothing special — the baseline enemy. Walking animation with sword swinging slightly.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a basic foot soldier in worn leather armor carrying a simple sword, brownish-grey color scheme, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, simple walk cycle, dark fantasy medieval soldier
--no background, floor, ground
--ar 4:1
```

---

### 2.2 Cavalry (Hizli Suvari) — `enemies/cavalry.png`

**Difficulty:** Easy | **HP:** 20 | **Speed:** Fast (2.0)

**Description:** A light cavalry rider on a dark horse. Streamlined armor for speed. Red cape flowing behind. The horse's legs show a galloping motion across the 4 frames.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame galloping animation sprite sheet of a light cavalry rider on a dark horse, streamlined dark armor for speed, red cape flowing behind, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, gallop cycle, dark fantasy mounted warrior
--no background, floor, ground
--ar 4:1
```

---

### 2.3 Goblin (Goblin Hirsiz) — `enemies/goblin.png`

**Difficulty:** Easy | **HP:** 25 | **Speed:** Moderate-Fast (1.3)

**Description:** A small hunched green goblin carrying a sack of stolen loot. Big ears, sharp teeth, sneaky posture. Yellow glowing eyes. Walking with a skulking gait.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a small hunched green goblin thief carrying a sack of loot, big pointed ears, sharp teeth, yellow glowing eyes, sneaky skulking gait, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, skulking walk cycle, dark fantasy goblin
--no background, floor, ground
--ar 4:1
```

---

### 2.4 Armored Giant (Zirhli Dev) — `enemies/armored_giant.png`

**Difficulty:** Medium | **HP:** 120 | **Armor:** 15 | **Speed:** Slow (0.5)

**Description:** A massive hulking humanoid in full plate armor. Twice the visual size of a regular soldier within the frame. Carries a huge mace. Slow, heavy, stomping walk. Dark iron armor with red glowing eye slits.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a massive hulking armored giant in full dark iron plate armor, carrying a huge mace, red glowing eye slits in the helmet, slow heavy stomping walk, twice the size of a normal soldier, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, heavy stomp walk cycle, dark fantasy armored behemoth
--no background, floor, ground
--ar 4:1
```

---

### 2.5 Undead (Canlanir Olu) — `enemies/undead.png`

**Difficulty:** Medium | **HP:** 60 | **Speed:** Slow-Moderate (0.8) | **Special:** Splits into 3 on death

**Description:** A shambling undead warrior — half-decomposed, wearing tattered armor. Sickly green-grey skin, exposed bones visible. Ghostly green glow in the eye sockets. Lurching, unsteady walk animation.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a shambling undead warrior, half-decomposed with tattered armor, sickly green-grey rotting skin, exposed bones visible, ghostly green glow in empty eye sockets, lurching unsteady walk, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, shambling walk cycle, dark fantasy zombie warrior
--no background, floor, ground
--ar 4:1
```

---

### 2.6 Shield Bearer (Kalkan Tasiyici) — `enemies/shield_bearer.png`

**Difficulty:** Medium | **HP:** 50 | **Armor:** 25 | **Speed:** Slow (0.7)

**Description:** A heavily armored soldier carrying an enormous tower shield that covers most of their body. Only the legs and eyes are visible behind the shield. The shield has a menacing face embossed on it. Slow, deliberate advance.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a heavily armored soldier carrying an enormous dark iron tower shield, shield covers most of the body with a menacing face embossed on it, only legs and glowing eyes visible behind the shield, slow deliberate advance, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, heavy march cycle, dark fantasy shield wall soldier
--no background, floor, ground
--ar 4:1
```

---

### 2.7 Healer (Sifaci) — `enemies/healer.png`

**Difficulty:** Medium | **HP:** 40 | **Speed:** Moderate (0.9) | **Special:** Heals nearby enemies

**Description:** A hooded dark priest/shaman carrying a gnarled staff with a sickly green-yellow crystal. Dark robes with glowing rune symbols. A healing aura circle around it. More of a caster than a fighter.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a hooded dark priest shaman carrying a gnarled staff with a sickly green-yellow crystal on top, dark robes with glowing rune symbols, healing aura particles around the character, sinister healer design, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, gliding walk cycle, dark fantasy evil healer
--no background, floor, ground
--ar 4:1
```

---

### 2.8 Burrower (Yeralti Solucani) — `enemies/burrower.png`

**Difficulty:** Hard | **HP:** 70 | **Armor:** 10 | **Speed:** Normal (1.0) | **Special:** Goes underground (untargetable)

**Description:** A massive segmented worm creature that burrows through earth. Visible portion shows its head/segments emerging from a dirt mound. Rock-hard carapace with orange-brown coloring. Mandibles and glowing orange eyes.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame animation sprite sheet of a massive segmented burrowing worm creature emerging from earth, rock-hard brown carapace segments, large mandibles and glowing orange eyes, dirt and debris particles around it, worm undulating through the ground, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, burrowing movement cycle, dark fantasy giant worm monster
--no background, floor, ground
--ar 4:1
```

---

### 2.9 Troll (Trol) — `enemies/troll.png`

**Difficulty:** Hard | **HP:** 150 | **Armor:** 5 | **Speed:** Slow (0.6)

**Description:** A large, muscular troll with mottled green-grey skin. Carries a massive tree trunk as a club. Tusks protruding from its lower jaw. Thick hide, hunched posture. Regeneration — faint green glow on wounds.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a large muscular troll with mottled green-grey skin, carrying a massive tree trunk as a club, tusks protruding from lower jaw, thick hide and hunched posture, faint green regeneration glow on its body, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, heavy lumbering walk cycle, dark fantasy troll brute
--no background, floor, ground
--ar 4:1
```

---

### 2.10 Dark Knight (Karanlik Sovalye) — `enemies/dark_knight.png`

**Difficulty:** Hard | **HP:** 100 | **Armor:** 20 | **Speed:** Fast (1.2)

**Description:** An elite warrior in full black plate armor with purple glowing rune engravings. Carries a dark greatsword wreathed in purple energy. A tattered purple cape. Fast and deadly — the opposite of the slow armored giant.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of an elite dark knight in full black plate armor with purple glowing rune engravings, carrying a dark greatsword wreathed in purple energy, tattered purple cape flowing behind, fast aggressive stride, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, aggressive march cycle, dark fantasy elite black knight
--no background, floor, ground
--ar 4:1
```

---

### 2.11 Shadow Lord (Golge Lord) — BOSS — `enemies/shadow_lord.png`

**Difficulty:** Boss | **HP:** 500 | **Speed:** Very Slow (0.4) | **Special:** Boss enemy

**Description:** A towering spectral figure made of living shadow. No solid physical form — shifting, amorphous dark mass with a vaguely humanoid shape. A crown of purple shadow flames on its head. Glowing purple eyes. Shadow tendrils trail behind it. Should fill more of the 128x128 frame than regular enemies.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a towering shadow lord boss, spectral figure made of living shadow and dark mist, vaguely humanoid amorphous form, a crown of purple shadow flames on its head, glowing purple eyes, shadow tendrils trailing behind, larger than normal enemies filling more of the frame, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, ominous gliding movement cycle, dark fantasy shadow boss monster
--no background, floor, ground
--ar 4:1
```

---

### 2.12 Dragon Emperor (Ejderha Imparatoru) — BOSS — `enemies/dragon_emperor.png`

**Difficulty:** Boss | **HP:** 800 | **Speed:** Very Slow (0.3) | **Special:** Final boss

**Description:** A massive dragon seen from top-down. Dark scales with glowing red-orange veins of fire visible between the scales. Enormous wings partially folded. Crown/horns that glow like molten metal. Fire breath visible. The ultimate threat. Should fill the entire 128x128 frame in each cell.

**Prompt:**
```
stylized 2D game sprite sheet, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight angle, transparent background, PNG with alpha,
4-frame walking animation sprite sheet of a massive dragon emperor boss seen from above, dark scales with glowing red-orange fire veins between the scales, enormous wings partially folded, crown-like horns glowing like molten metal, fire breath wisps, fills the entire frame as the ultimate threat, arranged horizontally 4 frames side by side, each frame 128x128 pixels, total 512x128 pixels, powerful stomping walk cycle, dark fantasy dragon emperor final boss
--no background, floor, ground
--ar 4:1
```

---

## 3. Castle Sprites

**Size:** 512 x 512 pixels, transparent background (PNG)
**View:** Top-down with slight ~30 degree angle
**Count:** 3 damage phases

The castle is the player's base that enemies are trying to destroy. It should look like a fortified medieval castle appropriate for a dark fantasy setting.

---

### 3.1 Phase 0 — Intact — `castle/castle_phase0.png`

**Description:** A magnificent dark stone castle in perfect condition. Multiple towers with pointed roofs. Warm golden light glowing from windows. A large central keep. Banners flying. Thick walls with battlements. The golden glow suggests life and safety within.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a magnificent dark stone medieval castle in perfect condition seen from above, multiple towers with pointed slate roofs, warm golden light glowing from every window, a large central keep, golden banners flying from the towers, thick walls with battlements and crenellations, the golden glow suggests warmth and safety within, pristine and strong, 512x512 pixels
--no background, ground, terrain
--ar 1:1
```

---

### 3.2 Phase 1 — Damaged — `castle/castle_phase1.png`

**Description:** The same castle but visibly damaged. One tower has collapsed partially. Cracks in the walls. Some windows are dark (broken). Smoke rising from a damaged section. The golden window glow is dimmer and only from surviving windows. Rubble at the base.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a dark stone medieval castle that has taken significant battle damage seen from above, one tower partially collapsed, large cracks in the walls, some windows dark and broken, smoke rising from damaged sections, golden window glow is dimmer and only from surviving windows, rubble and debris at the base, banners torn, damaged but still standing, 512x512 pixels
--no background, ground, terrain
--ar 1:1
```

---

### 3.3 Phase 2 — Ruined — `castle/castle_phase2.png`

**Description:** The castle is nearly destroyed. Most towers collapsed. Walls have huge breaches. Fire burns in sections. Almost no golden window glow — replaced by red fire glow. Heavy smoke. The keep barely stands. Desperate last stand feeling.

**Prompt:**
```
stylized 2D game sprite, dark fantasy art style inspired by Hades and Dead Cells, top-down view with slight 30-degree angle, transparent background, PNG with alpha channel, clean edges,
a dark stone medieval castle nearly destroyed seen from above, most towers collapsed into rubble, walls with huge breaches, fire burning in multiple sections casting red glow, almost no golden window light remaining replaced by fire glow, heavy smoke rising, the central keep barely standing, desperate last stand atmosphere, crumbling and ruined, 512x512 pixels
--no background, ground, terrain
--ar 1:1
```

---

## 4. Effect Sprites

**Format:** PNG with transparent background
**View:** Top-down

All effects should be bright and vivid against the dark game background. They are short-lived visual feedback elements.

---

### 4.1 Explosion — `effects/explosion.png`

**Size:** 256 x 64 pixels (4 frames of 64x64 arranged horizontally)

**Description:** A fiery explosion sequence. Frame 1: initial flash (bright orange-white center). Frame 2: expanding fireball. Frame 3: debris and smoke ring. Frame 4: fading smoke and embers.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame explosion animation sequence, bright orange-white initial flash expanding into a fireball then debris ring then fading smoke and embers, vibrant warm colors against transparency, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

### 4.2 Ice Burst — `effects/ice_burst.png`

**Size:** 256 x 64 pixels (4 frames of 64x64)

**Description:** An ice freezing effect. Frame 1: cyan flash. Frame 2: ice crystals forming in a ring. Frame 3: frozen burst with shards. Frame 4: frost particles dissipating.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame ice burst animation sequence, cyan flash expanding into ice crystal ring formation then frozen burst with ice shards then frost particles dissipating, cool cyan and pale blue colors, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

### 4.3 Lightning Strike — `effects/lightning_strike.png`

**Size:** 256 x 64 pixels (4 frames of 64x64)

**Description:** A lightning bolt strike effect. Frame 1: bright purple-white flash point. Frame 2: branching lightning bolt. Frame 3: electrical discharge ring. Frame 4: sparks fading.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame lightning strike animation sequence, bright purple-white flash point then branching lightning bolt then electrical discharge ring then sparks fading, vivid purple and white colors, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

### 4.4 Poison Cloud — `effects/poison_cloud.png`

**Size:** 256 x 64 pixels (4 frames of 64x64)

**Description:** A poison gas cloud effect. Frame 1: green gas eruption from a point. Frame 2: expanding toxic green cloud. Frame 3: cloud at maximum size with bubbles. Frame 4: dissipating thin green mist.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame poison cloud animation sequence, green gas eruption from a point then expanding toxic green cloud then cloud at maximum size with toxic bubbles then dissipating thin green mist, vivid green and yellow-green colors, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

### 4.5 Fire Trail — `effects/fire_trail.png`

**Size:** 256 x 64 pixels (4 frames of 64x64)

**Description:** A fire/burn trail effect for fire tower projectiles. Frame 1: bright flame. Frame 2: trailing fire. Frame 3: orange embers. Frame 4: fading smoke.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame fire trail animation sequence, bright crimson-orange flame then trailing fire particles then orange glowing embers then fading dark smoke wisps, warm red-orange colors, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

### 4.6 Holy Smite — `effects/holy_smite.png`

**Size:** 256 x 64 pixels (4 frames of 64x64)

**Description:** A holy light smite effect. Frame 1: golden beam of light from above. Frame 2: golden impact ring. Frame 3: radiating golden light rays. Frame 4: fading golden sparkles.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame holy smite animation sequence, golden beam of divine light from above then golden impact ring on the ground then radiating golden light rays then fading golden sparkles, warm golden-white colors, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

### 4.7 Dark Curse — `effects/dark_curse.png`

**Size:** 256 x 64 pixels (4 frames of 64x64)

**Description:** A dark curse/debuff effect. Frame 1: purple-black vortex forming. Frame 2: dark runes appear in a circle. Frame 3: shadow tendrils reaching inward. Frame 4: fading purple mist.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame dark curse animation sequence, purple-black vortex forming then dark runes appearing in a circle then shadow tendrils reaching inward then fading purple mist, deep purple and black colors, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

### 4.8 Water Splash — `effects/water_splash.png`

**Size:** 256 x 64 pixels (4 frames of 64x64)

**Description:** A water splash/wave impact effect. Frame 1: blue water jet impact. Frame 2: splash ring of droplets. Frame 3: wave ripples expanding. Frame 4: settling water droplets.

**Prompt:**
```
stylized 2D game effect sprite sheet, dark fantasy art style, transparent background, PNG with alpha,
4-frame water splash animation sequence, blue water jet impact then splash ring of water droplets then wave ripples expanding outward then settling water droplets, cool blue colors, each frame 64x64 pixels arranged horizontally, total 256x64 pixels
--no background
--ar 4:1
```

---

## 5. General Notes and Tips

### Workflow Recommendations

1. **Start with Tier 1 towers** — Generate the 12 tier-1 tower sprites first. This gives you a playable visual baseline. Iterate on the art style until you are happy, then scale to tiers 2-4.

2. **Batch by category** — Generate all towers, then all enemies, then castle, then effects. This keeps your style consistent within each category.

3. **Use the same seed (Midjourney)** — Once you get a tower style you like, note the seed number and use `--seed XXXX` for subsequent towers to maintain visual consistency.

4. **SDXL/FLUX tip** — Use ControlNet with a simple geometric sketch input to guide the composition. This is especially useful for sprite sheets where you need consistent frame placement.

### Post-Processing Checklist

After generating each sprite with AI, you will likely need to:

- [ ] **Remove background** — Even with "transparent background" in the prompt, AI generators often produce a colored background. Use remove.bg, Photoshop, or GIMP to clean the alpha channel.
- [ ] **Resize to exact dimensions** — AI generators may not output exact pixel sizes. Resize to the specified dimensions (256x256 for towers, 512x128 for enemies, etc.) using nearest-neighbor scaling to preserve the pixel art feel, or bilinear for smoother look.
- [ ] **Center the sprite** — Make sure the tower/enemy is centered in its frame. This matters for in-game placement.
- [ ] **Verify transparency** — Open in an image editor and confirm the background is fully transparent (alpha = 0), not white or near-white.
- [ ] **Check contrast** — View the sprite against a dark background (`#050510` to `#0a0e1a`) to make sure it reads well. The neon highlights should pop.
- [ ] **Split sprite sheets** — If the AI generates the 4 animation frames as a single image, make sure they are evenly spaced. The game engine will slice them into equal-width frames.
- [ ] **Consistent scale** — Compare sprites side by side. A goblin should be smaller than a troll. Bosses should be notably larger.

### Midjourney-Specific Settings

```
--v 6.1          (or latest version)
--ar 1:1         (for towers/castle) or --ar 4:1 (for sprite sheets/effects)
--style raw      (reduces Midjourney's "beautification", gives more control)
--no background, floor, ground, shadow on ground
--s 50           (lower stylization = more prompt-faithful)
--q 2            (higher quality)
```

### Stable Diffusion (SDXL/FLUX) Specific Settings

```
Negative prompt: background, floor, ground, shadow, 3D render, photorealistic, blurry, watermark, text, signature, frame, border
Steps: 30-50
CFG Scale: 7-9
Sampler: DPM++ 2M Karras or Euler a
Size: Match target dimensions or 2x for downscaling
```

### File Naming Convention Summary

| Category | Pattern | Example |
|----------|---------|---------|
| Tower Tier 1 | `towers/{type}_t1.png` | `towers/arrow_t1.png` |
| Tower Tier 2 | `towers/{type}_t2.png` | `towers/fire_t2.png` |
| Tower Tier 3 | `towers/{type}_t3.png` | `towers/ice_t3.png` |
| Tower Tier 4 | `towers/{type}_t4.png` | `towers/lightning_t4.png` |
| Enemy | `enemies/{type}.png` | `enemies/soldier.png` |
| Castle | `castle/castle_phase{0-2}.png` | `castle/castle_phase1.png` |
| Effect | `effects/{name}.png` | `effects/explosion.png` |

### Complete File List (Priority Order)

**Phase 1 — Minimum Viable Sprites (23 files):**
```
assets/images/towers/arrow_t1.png
assets/images/towers/fire_t1.png
assets/images/towers/ice_t1.png
assets/images/towers/lightning_t1.png
assets/images/towers/poison_t1.png
assets/images/towers/water_t1.png
assets/images/towers/dark_t1.png
assets/images/towers/holy_t1.png
assets/images/towers/cannon_t1.png
assets/images/towers/wizard_t1.png
assets/images/towers/support_t1.png
assets/images/towers/spike_wall_t1.png
assets/images/enemies/soldier.png
assets/images/enemies/cavalry.png
assets/images/enemies/goblin.png
assets/images/enemies/armored_giant.png
assets/images/enemies/undead.png
assets/images/castle/castle_phase0.png
assets/images/castle/castle_phase1.png
assets/images/castle/castle_phase2.png
assets/images/effects/explosion.png
assets/images/effects/ice_burst.png
assets/images/effects/lightning_strike.png
```

**Phase 2 — Full Enemy Set (add 7 files):**
```
assets/images/enemies/shield_bearer.png
assets/images/enemies/healer.png
assets/images/enemies/burrower.png
assets/images/enemies/troll.png
assets/images/enemies/dark_knight.png
assets/images/enemies/shadow_lord.png
assets/images/enemies/dragon_emperor.png
```

**Phase 3 — Full Effects (add 5 files):**
```
assets/images/effects/poison_cloud.png
assets/images/effects/fire_trail.png
assets/images/effects/holy_smite.png
assets/images/effects/dark_curse.png
assets/images/effects/water_splash.png
```

**Phase 4 — Tower Tiers 2-4 (add 36 files):**
```
assets/images/towers/{all_types}_t2.png   (12 files)
assets/images/towers/{all_types}_t3.png   (12 files)
assets/images/towers/{all_types}_t4.png   (12 files)
```

**Grand Total: 71 sprite files**

---

## Quick Reference Card

| What | Count | Size (px) | Frames | Priority |
|------|-------|-----------|--------|----------|
| Tower T1 | 12 | 256x256 | 1 | Phase 1 |
| Tower T2 | 12 | 256x256 | 1 | Phase 4 |
| Tower T3 | 12 | 256x256 | 1 | Phase 4 |
| Tower T4 | 12 | 256x256 | 1 | Phase 4 |
| Enemy (Easy) | 3 | 512x128 | 4 | Phase 1 |
| Enemy (Medium) | 4 | 512x128 | 4 | Phase 2 |
| Enemy (Hard) | 3 | 512x128 | 4 | Phase 2 |
| Enemy (Boss) | 2 | 512x128 | 4 | Phase 2 |
| Castle | 3 | 512x512 | 1 | Phase 1 |
| Effects | 8 | 256x64 | 4 | Phase 1/3 |
| **Total** | **71** | — | — | — |
