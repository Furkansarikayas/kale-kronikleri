# KALE KRONİKLERİ — ASSET PRODUCTION SYSTEM v1.0

> Bağımsız üretim için. Her asset bu sistemi takip eder. Claude gerekmez.

---

## 1. MASTER PROMPT TEMPLATES

### 1A. TOWER TEMPLATE

```
stylized dark fantasy game sprite, 45-degree isometric view showing
BOTH the top surface AND the front-facing side walls of the tower,
approximately 60% top and 40% front face visible, orthographic
perspective, hand-painted style inspired by Kingdom Rush and Darkest
Dungeon,

[TIER_DESCRIPTION] [TOWER_TYPE] tower, [POWER_LEVEL],

the tower sits on a CIRCULAR dark stone platform seen as an oval,
DARK NEUTRAL GREY stone, [PLATFORM_DETAIL],

dark grey stone body with visible stone blocks and hard mortar edges,
[BODY_DETAIL],

[TOP_MECHANISM],

[GLOW_DESCRIPTION],

STRICT top-left lighting from 10 o'clock: strong warm highlight on
left stone walls and left mechanism parts, deep cool shadow on right,
high contrast,

tower occupies approximately [OCCUPANCY]% of 256x256 canvas, same
base platform width across all tiers, centered, single isolated object,

FULLY TRANSPARENT BACKGROUND, small soft contact shadow at 20%
```

#### TOWER VARIABLES

| Variable | T1 | T2 | T3 | T4 |
|----------|----|----|----|----|
| `[TIER_DESCRIPTION]` | a compact basic | a refined upgraded | an advanced powerful | an EPIC legendary |
| `[POWER_LEVEL]` | simple functional Tier 1 | improved Tier 2 with visible upgrade | dangerous Tier 3 radiating strength | endgame Tier 4 radiating controlled power |
| `[PLATFORM_DETAIL]` | plain stone no decoration | thin carved edge line on rim | subtle abstract rune lines glowing faintly with [ACCENT_COLOR] | active glowing rune patterns in [ACCENT_COLOR] but MINIMAL and not competing with top |
| `[BODY_DETAIL]` | iron reinforcements, simple construction | iron reinforcements with improved masonry | iron and bronze fittings, refined masonry | bronze fittings, refined masonry, [ACCENT_COLOR] reflected on upper stones |
| `[TOP_MECHANISM]` | *per tower type* | *per tower type — upgraded* | *per tower type — powerful* | *per tower type — epic transformation* |
| `[GLOW_DESCRIPTION]` | SUBTLE [ACCENT_COLOR] glow on [GLOW_SOURCE] only, faint warm tint, barely visible | MODERATE [ACCENT_COLOR] glow on [GLOW_SOURCE], visible but controlled, no bloom | STRONG but CONTAINED [ACCENT_COLOR] glow, tight radius around [GLOW_SOURCE], does not spread into halo | STRONG but FOCUSED [ACCENT_COLOR] energy, illuminates top section, does NOT wash out entire tower, stone body below remains dark |
| `[OCCUPANCY]` | 65 | 72 | 80 | 88 |

#### TOWER TYPE VARIABLES

| Tower | `[TOWER_TYPE]` | `[ACCENT_COLOR]` | `[GLOW_SOURCE]` | T1 `[TOP_MECHANISM]` | T4 Epic Concept |
|-------|---------------|-------------------|-----------------|---------------------|-----------------|
| Arrow | crossbow watchtower | golden/warm gold | arrow tips and firing slot | single mounted crossbow with one golden arrow loaded | golden energy vortex ring with spectral arrows orbiting inside |
| Fire | flame brazier tower | red-orange fire | brazier flame and ember slots | iron brazier with contained flames on top | erupting volcanic core with orbiting fire rings |
| Ice | frost crystal tower | cyan-turquoise ice | crystal tip and frost veins | single cyan crystal mounted on iron frame | massive crystal cluster radiating frost energy field |
| Lightning | storm conductor tower | purple-violet electric | conductor rod tip and arc points | iron lightning rod with single spark at tip | Tesla coil array with orbiting electric arcs |
| Poison | venom distillery tower | toxic green | vial glow and drip points | glass vial apparatus dripping green liquid | bubbling cauldron core with toxic mist vortex |
| Water | tide caller tower | blue water | water orb and flow channels | small water orb floating in iron cradle | massive whirlpool sphere with orbiting water streams |
| Dark | shadow spire tower | dark purple | dark energy core and tendrils | dark crystal emitting faint purple wisps | void portal ring with shadow tendrils reaching outward |
| Holy | radiant shrine tower | bright gold-white | halo ring and light beams | small golden halo floating above stone shrine | blazing sun core with radiating holy light beams |
| Cannon | bombardment tower | orange explosion | cannon barrel glow and fuse | single bronze cannon barrel on rotating mount | triple cannon array with shared explosive energy core |
| Wizard | arcane focus tower | magenta-purple | crystal focus and magic circles | floating arcane crystal above stone pedestal | arcane orrery with orbiting spell spheres |
| Support | banner keep tower | warm gold-white | banner glow and aura base | tall banner pole with glowing golden flag | radiant banner array with pulsing golden aura field |
| Spike Wall | barricade tower | steel grey | blade edges and metal sheen | iron spike fence on stone wall segment | mechanized blade wall with rotating saw elements |

---

### 1B. ENEMY TEMPLATE

```
stylized dark fantasy game sprite, 45-degree top-down isometric view
looking DOWN at the character from above and slightly in front,
orthographic perspective, hand-painted style matching Kingdom Rush
and Darkest Dungeon aesthetic,

[ENEMY_DESCRIPTION] walking to the RIGHT, seen from ABOVE at 45
degrees, the viewer sees the TOP of the head and BOTH shoulders,
character body angled showing 3/4 front view with chest partially
visible, mid-stride walking pose,

IMPORTANT: this is NOT a side profile view, NOT a front view, it is
a 45-degree aerial view where we see the top of the head and both
shoulders from above,

[ARMOR_EQUIPMENT],

[COLOR_PALETTE],

SIMPLIFIED shapes for game readability: large clear silhouette forms,
NO fine detail NO intricate patterns, bold readable shapes,

STRICT directional lighting from top-left 10 o'clock: STRONG bright
highlight on top of head and left shoulder, DARK shadow on right side,
high contrast,

character is about [HEIGHT] pixels tall in 128x128 canvas, centered,
small SOFT OVAL contact shadow directly under feet at 20% opacity,
NO ground NO base plate NO floor NO pedestal,

FULLY TRANSPARENT BACKGROUND no vignette no gradient no grey
```

#### ENEMY VARIABLES

| Variable | Küçük | Normal | Büyük | Boss |
|----------|-------|--------|-------|------|
| `[HEIGHT]` | 70–85 | 85–100 | 100–120 | 110–125 |

| Enemy | Size | `[ENEMY_DESCRIPTION]` | `[ARMOR_EQUIPMENT]` | `[COLOR_PALETTE]` |
|-------|------|-----------------------|---------------------|-------------------|
| soldier | Normal | a medieval foot soldier | dark leather armor, iron chainmail patches, iron helmet with nose guard, short sword in right hand, round wooden shield on left arm, dark red tabard | desaturated earthy: dark brown leather, grey iron, muted dark red |
| goblin | Küçük | a small sneaky goblin | ragged leather scraps, no helmet, crude dagger in right hand, hunched posture, pointed ears | desaturated: olive green skin, brown leather, dirty grey |
| cavalry | Büyük | a mounted knight on armored horse | full iron plate on rider, horse with cloth barding, lance in right hand, kite shield | desaturated: dark steel grey, dark blue cloth, brown horse |
| armoredGiant | Büyük | a massive armored warrior | heavy iron full plate, great tower shield, huge mace, horned helmet | desaturated: dark iron grey, black underlayer, rust accents |
| undead | Normal | a shambling undead skeleton warrior | tattered remnants of armor, exposed bones, rusted sword, broken shield | desaturated: bone white, rotted brown, dark grey metal |
| shieldBearer | Normal | a defensive soldier with oversized shield | massive iron tower shield covering most of body, short spear, medium armor | desaturated: dark steel, brown leather, dull iron |
| healer | Normal | a robed battlefield medic | long dark robes, staff with faint white crystal tip, satchel bag, hood | desaturated: dark grey robes, off-white crystal hint, brown leather |
| burrower | Küçük | a low crouching burrowing creature | armored carapace on back, clawed hands, no weapons, close to ground | desaturated: earth brown, dark shell, sandy underbelly |
| troll | Büyük | a massive muscular troll | minimal leather straps, wooden club, thick skin, hunched forward | desaturated: dark green skin, brown leather, grey-brown club |
| darkKnight | Büyük | a dark-armored elite knight | full black plate armor, dark cape, greatsword, horned helmet with visor | desaturated dark: near-black armor, dark purple cape hint |
| shadowLord | Boss | a tall shadow lord with flowing dark robes | elaborate dark robes with purple trim, floating slightly, shadow tendrils from base, staff with dark orb | dark: black robes, deep purple accents, single violet glow point |
| dragonEmperor | Boss | a dragon emperor with partially spread wings | scaled body, partial wing spread seen from above, crown, clawed hands, tail visible | dark: deep red scales, gold crown accent, black wing membrane |

---

## 2. NEGATIVE PROMPT SYSTEM

### 2A. UNIVERSAL NEGATIVE (tüm asset'ler)

```
--no background, grey background, vignette, gradient background,
floor, ground, ground plane, text, watermark, logo, signature,
brand name, chibi, anime, pixel art, realistic photo, 3D render,
cartoon, pastel, bright pastel colors, white background, gradient
rainbow, multiple objects, scene, environment, UI elements, frame,
border
```

### 2B. TOWER ADDITIONAL NEGATIVE

```
square base, rectangular base, hexagonal base, diamond base,
pedestal, base plate, text on base, letters, words, readable text,
writing, inscriptions, brown base, gold base, warm tinted base,
busy lower section, ornate bottom, bird eye view, 90 degree view,
directly above view, front facing, pure side view
```

### 2C. ENEMY ADDITIONAL NEGATIVE

```
base plate, pedestal, stone base, polygon under character,
side profile view, looking at camera, front facing pose, bird eye
top down view, big head, chibi proportions, fine chainmail detail,
intricate texture patterns, bright colors, neon glow
```

### 2D. GLOW CONTROL NEGATIVE (T1–T3)

```
strong glow, bright bloom, neon glow, intense light, glowing stone,
scattered particles, small shards, debris, sparks, chaotic energy
```

### 2E. GLOW CONTROL NEGATIVE (T4 only)

```
overwhelming glow, washed out, bright everywhere, chaotic energy,
scattered particles, small shards, debris, messy glow
```

**Birleştirme:** `[UNIVERSAL] + [TOWER veya ENEMY] + [GLOW TIER]`

---

## 3. STYLE LOCK RULES

Üretim sırasında kontrol. Herhangi biri HAYIR → ÜRETME.

```
□ Aynı Leonardo modeli mi? (Phoenix 1.0)
□ Aynı boyut mu? (256×256 kule / 128×128 düşman)
□ Master prefix kullanıldı mı?
□ Negative prompt birleştirildi mi?
□ Referans asset'lerle aynı oturumda mı? (seed tutarlılığı)
```

---

## 4. GENERATION SETTINGS

### 4A. STANDART AYARLAR

| Parametre | Kule | Düşman |
|-----------|------|--------|
| **Model** | Leonardo Phoenix 1.0 | Leonardo Phoenix 1.0 |
| **Boyut** | 256 × 256 | 128 × 128 |
| **Guidance Scale** | 10 | 10–11 |
| **Steps** | 40 (T1–T3) / 45 (T4) | 40 |
| **Alchemy** | AÇIK | AÇIK |
| **PhotoReal** | KAPALI | KAPALI |
| **Tiling** | KAPALI | KAPALI |
| **Üretim sayısı** | 4 | 4 |

### 4B. SEED STRATEJİSİ

```
KULE AİLELERİ:
- Aynı kule tipinin T1→T4 arası: AYNI SEED kullan
- Farklı kule tipleri: farklı seed (ama aynı oturumda üret)
- Seed bulunamazsa: 4 üret, referansa en yakın olanı seç

DÜŞMANLAR:
- Her düşman bağımsız seed
- Soldier seed'ini referans olarak sakla
- Yeni düşman soldier'a yakın çıkmıyorsa: serbest üret

KAYIT:
- Her geçen asset'in seed'ini not et
- Format: [asset_adı] → seed: [numara] → tarih: [YYYY-MM-DD]
```

---

## 5. QA CHECKLIST

### 5A. HIZLI PASS/FAIL (30 saniye)

Her üretimde ilk bakış — herhangi biri FAIL → anında red.

```
[F1] Arka plan şeffaf mı?          → FAIL: gri/renkli arka plan
[F2] Watermark/logo var mı?         → FAIL: herhangi bir yazı/marka
[F3] Doğru boyut mu?                → FAIL: 256×256 veya 128×128 değilse
[F4] Kamera 45° izometrik mi?       → FAIL: yan/ön/kuş bakışı
[F5] Işık sol üstten mi?            → FAIL: yanlış yönde gölge
```

### 5B. STİL KONTROL (1 dakika)

Hızlı testi geçtiyse:

```
[S1] Dark fantasy stylized hissi var mı?
[S2] Chibi/anime/cartoon/pixel art değil mi?
[S3] Referans asset'lerle aynı dünyadan mı?
[S4] Renk paleti doğru mu? (koyu gövde + accent glow)
[S5] Malzeme dili doğru mu? (taş + metal + enerji)
```

### 5C. ASSET-SPESİFİK KONTROL (1 dakika)

**Kule ise:**

```
[T1] Dairesel/oval platform mı?
[T2] Platform rengi nötr gri mi?
[T3] Tier seviyesine uygun glow mü?
[T4] Aynı kule ailesinin önceki tier'ine benziyor mu?
[T5] Silüet 45px'de okunuyor mu?
```

**Düşman ise:**

```
[E1] 3/4 sağa yürüyüş pozunda mı?
[E2] Base plate/zemin YOK mu?
[E3] Boyut kategorisine uygun mu?
[E4] Desatüre renk paleti mi?
[E5] Silüet 45px'de okunuyor mu?
```

### 5D. KARAR

```
5A tamamı PASS + 5B tamamı PASS + 5C tamamı PASS → KABUL
Herhangi bir FAIL → RED + sorunu not et + prompt'u düzelt + tekrar üret
```

---

## 6. ÜRETİM SIRASI ÖNERİSİ

### Aşama 1: Kalan Kule Aileleri (her biri T1→T4)

```
Sıra  Kule          Öncelik   Neden
1     Fire          Yüksek    En popüler kule tipi
2     Ice           Yüksek    Görsel kontrast (soğuk vs sıcak)
3     Cannon        Yüksek    Mekanik odaklı, iyi test
4     Lightning     Orta      Enerji efekt testi
5     Dark          Orta      Koyu palette zorluğu
6     Holy          Orta      Parlak palette zorluğu
7     Poison        Orta      Yeşil accent testi
8     Water         Orta      Mavi accent testi
9     Wizard        Düşük     Karmaşık konsept
10    Support       Düşük     Pasif kule
11    Spike Wall    Düşük     Farklı form faktörü
```

### Aşama 2: Kalan Düşmanlar

```
Sıra  Düşman         Öncelik   Neden
1     goblin         Acil      Mevcut chibi — yeniden üretilmeli
2     cavalry        Yüksek    Büyük + at — ölçek testi
3     armoredGiant   Yüksek    En büyük normal düşman
4     undead         Orta      Farklı malzeme (kemik)
5     shieldBearer   Orta      Büyük kalkan silüeti
6     troll          Orta      Mevcut artifact'li
7     healer         Orta      İnce figür
8     burrower       Orta      Küçük + yere yakın
9     darkKnight     Yüksek    Karanlık zırh zorluğu
10    shadowLord     Acil      Mevcut watermark'lı
11    dragonEmperor  Yüksek    Boss ölçeği
```

### Aşama 3: Ortam ve UI

```
- Kale (3 faz)
- Tile/texture seti
- Arka planlar (5 biome)
- UI öğeleri
```

---

## 7. DOSYA TESLİM KURALLARI

```
Format:    WebP (kalite 85)
Boyut:     256×256 (kule) / 128×128 (düşman tek) / 512×128 (düşman sheet)
Arka plan: Tamamen şeffaf (alpha channel)
İsim:      style-bible.md §11 adlandırma kurallarına göre
Konum:     assets/images/[kategori]/[dosya_adı].webp
```

PNG olarak üretilirse → WebP'ye dönüştür (Pillow veya online araç).

---

> **Bu sistem tüm kalan varlıkların bağımsız üretimi için yeterlidir.**
> Her asset bu template + QA checklist ile üretilir.
> Tutarsızlık tespit edilirse → style-bible.md'ye başvur.
