# KALE KRONİKLERİ — STYLE BIBLE v1.0

> **Bu belge kanundur.** Tüm varlıklar bu kurallara uymak ZORUNDADIR.
> Uyumsuz sprite → red. İstisna yok.

**Son Güncelleme:** 2026-03-29
**Kaynak:** Phase 1 Görsel Denetim Bulguları

---

## 1. KAMERA SİSTEMİ

### 1.1 Sabit Açı

| Parametre | Değer | Not |
|-----------|-------|-----|
| **Kamera açısı** | **45° (üstten)** | 3/4 izometrik görünüm |
| **Perspektif tipi** | **Ortografik** (paralel projeksiyon) | Perspektif deformasyon YOK |
| **Yatay dönüş** | **0°** (kuzey = ekranın üstü) | Sprite'lar kameraya hafif çapraz bakar |

### 1.2 Zoom / Çerçeveleme

| Öğe | Kaynak Boyut | Ekran Boyut | Oran |
|-----|-------------|-------------|------|
| Grid hücre | — | 64×64 px | Temel birim |
| Kule sprite | 256×256 px | 96×106 px | ~2.5:1 küçültme |
| Düşman sprite | 128×128 px | 45×45 px | ~2.8:1 küçültme |
| Boss sprite | 128×128 px | 96×96 px | ~1.3:1 küçültme |
| Kale | 256×256 px | 128×128 px | 2:1 küçültme |

### 1.3 Kamera Kuralları

```
KURAL 1: Tüm kuleler 45° yukarıdan görülür. Ön cephe/yan cephe YASAK.
KURAL 2: Tüm düşmanlar 45° yukarıdan görülür. Tam cepheden yürüyüş pozu YASAK.
KURAL 3: Boss'lar aynı açıda, sadece ölçek büyük.
KURAL 4: "Kameraya bakma" yok. Karakter dörtgen grid üzerinde yaşıyor.
```

### 1.4 Referans Açı Diyagramı

```
        Kamera Bakış Yönü
              ↓
         ╱‾‾‾‾‾‾‾╲   ← 45° açı
        ╱   Kule    ╲
       ╱  (üst yüz)  ╲
      ╱_______________╲
      │   ön yüz      │  ← Görünen ön cephe (~%40)
      │________________│
      ╲   taban        ╱  ← Taban platformu görünür
       ╲______________╱

    Oyuncu ekranda bunu görür:
    - Kulenin ÜSTÜ dominant
    - Kulenin ÖN YÜZÜ kısmen görünür
    - Kulenin YAN yüzleri çok az görünür
    - ARKA yüz görünmez
```

---

## 2. IŞIK SİSTEMİ

### 2.1 Ana Işık Kaynağı

| Parametre | Değer |
|-----------|-------|
| **Yön** | **Sol üst — saat 10:00** |
| **Açı (yatay)** | 315° (kuzeybatı) |
| **Açı (dikey)** | 45° yukarıdan |
| **Tip** | Sıcak güneş ışığı |
| **Renk** | `#FFF5E0` (sıcak beyaz) |

### 2.2 Gölge Kuralları

| Parametre | Değer |
|-----------|-------|
| **Gölge yönü** | Sağ alt (saat 4:00 yönüne düşer) |
| **Gölge yumuşaklığı** | Orta-yumuşak (hard edge yok, tam blur da yok) |
| **Gölge opaklığı** | %30–40 siyah |
| **Gölge rengi** | `#000000` @ alpha 0.30–0.40 |
| **Gölge boyutu** | Objenin yüksekliğinin ~%60'ı kadar uzar |

### 2.3 Zemin Gölgesi

```
ZORUNLU: Her sprite'ın altında zemin gölgesi OLMALI.
- Şekil: Oval/elips (45° projeksiyonda daire → elips olur)
- Renk: #000000 @ %25 alpha
- Boyut: Taban platformunun %120'si genişliğinde
- Pozisyon: Objenin hemen altında, hafif sağa kaydırılmış
- Sprite içinde mi?: HAYIR — gölge runtime'da render edilir
  (sprite'ta gölge olursa grid hizalama bozulur)
```

### 2.4 Aydınlatma Katmanları

Her sprite'ta 3 aydınlatma katmanı:

```
Katman 1 — ANA IŞIK (sol üst):
  Highlight: Sol üst kenarlarda
  Renk: Objenin base renginin açık tonu
  Yoğunluk: Güçlü ama yakıcı değil

Katman 2 — AMBİENT DOLGU (karşı taraf):
  Hafif dolgu: Sağ alt karanlık tarafta
  Renk: Objenin base renginin koyu tonu + mavi-gri (#2a3040)
  Yoğunluk: Çok yumuşak, gölgeler tamamen siyah olmasın

Katman 3 — ELEMENTİN KENDİ IŞIĞI (varsa):
  Ateş kulesi → turuncu self-glow
  Buz kulesi → cyan self-glow
  Dark kule → mor self-glow
  Bu ışık ana ışık kaynağını GEÇERSIZ KILMAZ, ek olarak eklenir.
```

### 2.5 Malzeme Bazlı Işık Tepkisi

| Malzeme | Highlight Tipi | Örnek |
|---------|---------------|-------|
| Taş | Geniş, mat difüz | Kule gövdesi |
| Metal | Dar, keskin speküler | Silah parçaları, zırh |
| Ahşap | Orta, sıcak difüz | Çit, yay mekanizması |
| Enerji/Sihir | Self-illuminated, glow | Rune'lar, büyü efektleri |
| Kumaş | Yumuşak, absorbe eden | Bayrak, pelerin |

---

## 3. ÖLÇEK SİSTEMİ

### 3.1 Temel Birim

```
1 grid hücresi = 64×64 piksel (ekranda)
Tüm ölçekler bu birime göre tanımlanır.
```

### 3.2 Kule Boyut Sistemi

Kaynak sprite: **256×256 px** (tümü aynı tuval)
Ekranda render: **96×106 px** (1.5×1.65 hücre)

**Sprite tuvalinde kule objesinin kapladığı alan:**

| Tier | Taban Genişliği | Yükseklik | Tuval Kullanımı | Not |
|------|----------------|-----------|-----------------|-----|
| T1 | 140–160 px | 160–180 px | %60–70 | Kompakt, basit |
| T2 | 150–170 px | 180–200 px | %70–78 | T1'den biraz büyük |
| T3 | 160–180 px | 200–220 px | %78–86 | Detaylı, süslü |
| T4 | 170–200 px | 220–245 px | %86–96 | Epik, glowing |

```
KRİTİK KURAL:
- Aynı kule tipinin T1→T4 arası "büyüme" hissi olmalı
- T4 asla tuvalin dışına taşmamalı (256px sınırı)
- Taban platformu her tier'de AYNI GENİŞLİKTE (±5px)
- Yükseklik artışı KADEMALI — T1'den T4'e max %50 artış
- T4'ün T1'e hiç benzememesi YASAK (aynı kule ailesi)
```

### 3.3 Düşman Boyut Sistemi

Kaynak sprite: **128×128 px** (tek kare) / **512×128 px** (4-frame spritesheet)
Ekranda render: **45×45 px** (0.7×hücre) | Boss: **96×96 px** (1.5×hücre)

**Sprite tuvalinde düşman objesinin kapladığı alan:**

| Kategori | Düşmanlar | Tuval Boyut | Not |
|----------|-----------|-------------|-----|
| **Küçük** | goblin, burrower | 70–85 px | Hücrede küçük görünür |
| **Normal** | soldier, undead, healer, shieldBearer | 85–100 px | Standart boyut |
| **Büyük** | cavalry, armoredGiant, troll, darkKnight | 100–120 px | Hücreye sıkı oturur |
| **Boss** | shadowLord, dragonEmperor | 110–125 px | 1.5x render ile büyük |

```
KRİTİK KURAL:
- Düşmanlar 45° açıda 3/4 yürüyüş pozunda
- Cepheden bakış YASAK (soldier hatası tekrarlanmayacak)
- Kuş bakışı YASAK (dragonEmperor hatası tekrarlanmayacak)
- Base plate/zemin YASAK (goblin hatası tekrarlanmayacak)
- 4-frame walk cycle: sağa yürüyüş, her frame'de bacak pozisyonu farklı
```

### 3.4 Kale Boyut Sistemi

| Faz | Kaynak | Ekran | Durum |
|-----|--------|-------|-------|
| Phase 0 | 256×256 px | 128×128 px | Sağlam |
| Phase 1 | 256×256 px | 128×128 px | Hasarlı (%40–70 HP) |
| Phase 2 | 256×256 px | 128×128 px | Ağır hasar (<%40 HP) |

### 3.5 Görsel Ölçek Referansı

```
Bir grid hücresi içinde karşılaştırma:

  ┌─────────────────────────────┐
  │                             │
  │    ┌───────┐   ┌───┐       │
  │    │ KULE  │   │DÜŞ│       │
  │    │ (render│   │MAN│       │
  │    │  alanı)│   └───┘       │
  │    │  96px  │   45px        │
  │    │  geniş │               │
  │    └───────┘                │
  │      64px hücre             │
  └─────────────────────────────┘

  Kule > Hücre (taşar) > Düşman (hücre içinde)
```

---

## 4. TABAN PLATFORM STANDARDI

### 4.1 Şekil ve Boyut

```
Şekil: DAİRESEL (45° perspektifte → OVAL/ELİPS olarak görünür)
Çap:  130 px (256px tuval içinde — tuvalin %51'i)
Yükseklik: 20–25 px (platformun kalınlığı/derinliği)
```

### 4.2 Malzeme

| Katman | Açıklama | Renk |
|--------|----------|------|
| Üst yüzey | Düz, pürüzsüz taş | `#4A4A52` (koyu gri-taş) |
| Kenar | Kaba, oyulmuş taş | `#3A3A42` (daha koyu) |
| Alt kenar | Gölgeli | `#2A2A32` |
| Highlight | Sol üst kenar (ışık) | `#5A5A65` |

### 4.3 Tier'e Göre Platform Evrimi

```
T1: Düz taş platform
    - Sade, işlenmemiş taş
    - Renk: Gri (#4A4A52)
    - Süsleme: YOK

T2: İşlenmiş taş platform
    - Kenarları düzeltilmiş, hafif çizgi detayı
    - Renk: Hafif sıcak gri (#4D4A48)
    - Süsleme: İnce kenar çizgisi

T3: Rune'lu platform
    - Kule renginde hafif parlayan rune çizgileri
    - Renk: Gri + kule accent glow
    - Süsleme: 2–3 ince rune çizgisi, glow efekti

T4: Epik platform
    - Aktif parlayan rune desenleri
    - Renk: Koyu taş + yoğun kule accent glow
    - Süsleme: Tam rune deseni, kenarlardan enerji sızar
    - Platform hafif havada süzülüyor gibi alt gölge
```

### 4.4 Kurallar

```
KURAL 1: Tüm kuleler aynı oval platform üstünde durur.
KURAL 2: Platform boyutu tier'ler arası DEĞİŞMEZ (130px çap).
KURAL 3: Kare, altıgen, elmas taban YASAK.
KURAL 4: Platform kule sprite'ına dahildir (ayrı dosya değil).
KURAL 5: Platform rengi nötr — kule tipi rengi TAŞIMAZ.
         (rune glow'u hariç, o T3+ için kule renginde olabilir)
```

---

## 5. RENK SİSTEMİ

### 5.1 Temel Palet

#### Ortam Renkleri (Environment)

| İsim | HEX | Kullanım |
|------|-----|----------|
| Gece Siyahı | `#050510` | Ana arka plan |
| Derin Lacivert | `#0A0E1A` | Gökyüzü gradyan |
| Orman Koyu Yeşil | `#0D1A0D` | Zemin/çim base |
| Orman Yeşil | `#1A2A1A` | Zemin highlight |
| Yol Kahvesi | `#1A1510` | Path/yol base |
| Yol Açık | `#3A3025` | Path highlight |

#### UI Renkleri

| İsim | HEX | Kullanım |
|------|-----|----------|
| Altın | `#D4A843` | Altın, butonlar, başlıklar |
| Krem | `#F5EDD8` | Metin, soft highlight |
| Koyu Panel | `#1A150E` | Panel arka plan |
| Kırmızı Uyarı | `#FF4444` | HP düşük, tehlike |
| Yeşil Onay | `#44CC44` | İyileşme, başarı |

#### Kule Accent Renkleri

| Kule | Birincil (Core) | İkincil (Glow) | Kullanım |
|------|----------------|-----------------|----------|
| Arrow | `#D4A843` | `#F0E6D0` | Altın ok, sıcak enerji |
| Fire | `#E94560` | `#FF6B81` | Kırmızı-turuncu alev |
| Ice | `#4ECDC4` | `#A0E6FF` | Cyan-turkuaz buz |
| Lightning | `#A78BFA` | `#C4B5FD` | Mor-leylak elektrik |
| Poison | `#2ECC71` | `#A0FFA0` | Zehir yeşili |
| Water | `#3498DB` | `#74B9FF` | Mavi su |
| Dark | `#8B5CF6` | `#A78BFA` | Koyu mor karanlık |
| Holy | `#FFD700` | `#FFF5E0` | Kutsal altın |
| Cannon | `#E67E22` | `#F39C12` | Turuncu patlama |
| Wizard | `#9B59B6` | `#C084FC` | Büyücü moru |
| Support | `#FFD700` | `#FFF8E0` | Destek altını |
| Spike Wall | `#7F8C8D` | `#95A5A6` | Çelik grisi |

### 5.2 Renk Kullanım Kuralları

```
KURAL 1 — %70-20-10 Kuralı:
  %70: Nötr taş/metal gövde (gri tonları)
  %20: Kule tipi accent rengi (core + glow)
  %10: Highlight/shadow detaylar

KURAL 2 — Glow Kuralı:
  Enerji/sihir öğeleri kule accent renginde parlar.
  Glow YAYILIR ama gövdeyi BOYAMAZ.
  Core renk merkezde yoğun, glow renk çevrede yumuşak.

KURAL 3 — Karanlık Fantasy Tabanı:
  Gövde renkleri DAİMA koyu/desatüre olmalı.
  Parlak renkler SADECE enerji/sihir/glow için.
  Pastel, çizgi film renkleri YASAK.

KURAL 4 — Düşman Renk Dili:
  Normal düşmanlar: Desatüre, dünya tonları (kahverengi, gri, koyu yeşil)
  Boss düşmanlar: Tek yoğun accent renk (karanlık mor, kanlı kırmızı)
  Düşman renkleri kule renkleriyle ÇAKIŞMAMALI.
```

### 5.3 Yasaklı Renk Kombinasyonları

| Yasaklı | Neden |
|---------|-------|
| Parlak pembe + parlak yeşil | Chibi/çocuk oyunu hissi |
| Tam beyaz (#FFFFFF) gövde | Düz, derinlik yok |
| Tam siyah (#000000) gövde | Gölge ile karışır |
| Neon kule rengi tüm gövdeye | Glow yerine boya gibi durur |
| Pastel tonlar (>70% satürasyon < 40% değer) | Dark fantasy değil |
| Gradient rainbow efekt | Ucuz mobil oyun hissi |

---

## 6. MALZEME DİLİ

### 6.1 İzin Verilen Malzemeler

| Malzeme | Yüzey | Işık Tepkisi | Kullanım Alanı |
|---------|-------|-------------|----------------|
| **Koyu Taş** | Pürüzlü, mat | Geniş difüz highlight | Kule gövdesi, platform, duvar |
| **Demir/Çelik** | Pürüzsüz, parlak | Dar speküler yansıma | Silah mekanizmaları, zırh parçaları |
| **Bronz** | Yarı-pürüzsüz | Sıcak speküler | Dekoratif aksesuar, top namlusu |
| **Ahşap** | Lifli, mat | Sıcak difüz | Yay, ok, destek yapıları |
| **Enerji/Büyü** | Işık yayan | Self-illuminated + glow | Rune, büyü efekti, mermiler |
| **Kristal** | Yarı-saydam | İç ışık + yüzey kırılma | Buz, holy enerji |
| **Kumaş** | Yumuşak, mat | Absorbe eden difüz | Bayrak, pelerin, çadır |
| **Kemik** | Mat, kırılgan | Soğuk difüz | Undead düşmanlar |
| **Deri** | Yarı-pürüzsüz | Sıcak difüz | Düşman zırhı, kayış |

### 6.2 Yasaklı Malzemeler

| Yasaklı | Neden |
|---------|-------|
| Plastik/PVC | Modern, fantezi kırmaz |
| Cam (saydam duvar) | Render'da okunamaz, grid bozar |
| Krom/ayna yüzey | Çevre yansıması yok, sahte durur |
| Kağıt/karton | Çok kırılgan, oyun dünyasıyla uyumsuz |
| Beton (modern) | Ortaçağ temasını kırar |

### 6.3 Malzeme Katmanlama Kuralı

```
Her kule sprite EN AZ 2, EN FAZLA 4 malzeme içerir:

ZORUNLu:
  1. Koyu taş (gövde/platform)
  2. Bir metal türü (mekanizma/detay)

OPSİYONEL:
  3. Enerji/büyü (kule tipi efekti)
  4. Bir yumuşak malzeme (ahşap, kumaş, kristal)

YASAK: 5+ malzeme — karmaşıklık küçük sprite'ta okunmaz.
```

---

## 7. STİL TANIMLAMA

### 7.1 Stil Adı

**"Dark Fantasy Stylized"**

Referanslar: Kingdom Rush: Vengeance × Darkest Dungeon × Hades

### 7.2 Stil Parametreleri

| Parametre | Değer | Açıklama |
|-----------|-------|----------|
| Gerçekçilik | %40 | Ne çizgi film ne foto-gerçekçi |
| Detay seviyesi | Orta | 45px'de okunamayan detay KOYMAYINIZ |
| Kontur/outline | YOK | Hades tarzı — renk/ışık ile form, siyah kontur yok |
| Doku (texture) | Var ama subtle | Hand-painted hissi, ama noise yok |
| Abartma (exaggeration) | Hafif | Silahlar/özellikler %10–20 büyütülür okunabilirlik için |

### 7.3 Kesinlikle OLMAMASI Gerekenler

| Anti-Pattern | Açıklama |
|-------------|----------|
| Chibi | Büyük kafa, küçük gövde — goblin hatası |
| Anime | Büyük gözler, sivri çene |
| Pixel art | Kasıtlı piksel blokları |
| Realistic portrait | Foto-gerçekçi yüz detayı |
| MOBA splash art | Aksiyon pozu, zoom-in, efekt patlaması — troll hatası |
| Clip art | Düz renkler, gölgesiz |
| Sticker/emoji | Kalın kontur, 2D flat |

### 7.4 Silüet Testi

```
HER SPRİTE ŞU TESTİ GEÇMELİ:

1. Sprite'ı tamamen siyaha çevir (silüet)
2. 45×45 px'e küçült
3. Hâlâ ne olduğu anlaşılıyor mu?

Arrow kule → Üstünde ok/crossbow mekanizması olan kısa kule silüeti
Fire kule → Üstünde alev formu olan kule silüeti
Soldier → Kalkan + kılıç tutan figür
Cavalry → At üstünde binici

Silüet okunamıyorsa → ABARTMAYI ARTIR veya DETAYı AZALT.
```

---

## 8. DÜŞMAN ÖZEL KURALLARI

### 8.1 Poz Standardı

```
TÜM düşmanlar: 3/4 üstten, SAĞA YÜRÜYÜŞ pozu
(Kod çalışma zamanında sola yürürken flip yapar)

Poz detayı:
- Vücut hafif sağa dönük (3/4 açı)
- Ön bacak ileri, arka bacak geri (yürüyüş ortası)
- Silah/kalkan görünür tarafta
- Yüz aşağı-sağa bakıyor (45° kamera ile tutarlı)
```

### 8.2 Walk Cycle Frame'leri

```
128×128 px tuval × 4 frame = 512×128 spritesheet

Frame 1: Sağ bacak ileri, sol bacak geri
Frame 2: Bacaklar orta — geçiş pozisyonu
Frame 3: Sol bacak ileri, sağ bacak geri
Frame 4: Bacaklar orta — geçiş pozisyonu (ters)

VEYA daha basit alternatif (mevcut sistem):
Tek frame + runtime bob animasyonu (sin wave)
→ Bu durumda: yürüyüş ortası pozunda tek frame yeterli.
```

### 8.3 Düşman Boyut Karşılaştırma

```
128px tuval içinde düşman boyutları (piksel yükseklik):

Goblin        ████░░░░░░  70px   (küçük, kurnaz)
Soldier       ██████░░░░  90px   (standart)
Undead        ██████░░░░  88px   (standart, biraz eğik)
Healer        ██████░░░░  85px   (standart, ince)
Shield Bearer ██████░░░░  95px   (standart, geniş)
Cavalry       ████████░░ 110px   (at + binici)
Armored Giant ████████░░ 115px   (büyük, geniş)
Troll         █████████░ 118px   (çok büyük, kaslı)
Dark Knight   ████████░░ 105px   (büyük, zırhlanmış)
Burrower      █████░░░░░  75px   (küçük, yere yakın)
Shadow Lord   █████████░ 120px   (boss, uzun pelerin)
Dragon Emp.   ██████████ 125px   (boss, kanat açık)
```

---

## 9. LEONARDO.AI PROMPT SİSTEMİ

### 9.1 Master Prefix (TÜM sprite'lar için)

```
stylized dark fantasy game sprite, 45-degree top-down isometric view,
orthographic perspective, hand-painted style inspired by Kingdom Rush
and Darkest Dungeon, top-left lighting (10 o'clock direction),
warm highlight on upper-left edges, cool shadow on lower-right,
rich deep shadows, transparent background, clean alpha edges,
single isolated object centered on canvas
```

### 9.2 Kule Prompt Şablonu

```
[MASTER PREFIX],
a [TIER_DESCRIPTION] [TOWER_TYPE] tower sitting on a circular dark
stone platform, dark grey stone body with [METAL_TYPE] mechanical
details, [ACCENT_COLOR] energy glow emanating from [GLOW_SOURCE],
[TIER_SPECIFIC_DETAILS], compact proportions fitting 256x256 canvas
with tower occupying [OCCUPANCY]% of frame,
--no background, floor, ground plane, shadow on ground, base plate,
hexagonal base, square base, diamond base
```

### 9.3 Düşman Prompt Şablonu

```
[MASTER PREFIX],
a [SIZE_CATEGORY] [ENEMY_TYPE] character in 3/4 walking pose facing
right, [BODY_DESCRIPTION], [ARMOR_EQUIPMENT], desaturated earthy
color palette with [ACCENT_IF_ANY], centered in 128x128 canvas
occupying [OCCUPANCY]% of frame,
--no background, floor, ground plane, base plate, shadow on ground,
front-facing pose, top-down view, chibi proportions, anime style
```

### 9.4 Negative Prompt (TÜM üretimler)

```
background, floor, ground, ground shadow, base plate, pedestal,
modern elements, plastic, chrome, glass, neon sign, text, watermark,
logo, signature, brand name, UI elements, frame, border,
front-facing camera angle, bird's eye view, side view,
chibi, anime, pixel art, realistic photo, 3D render, cartoon,
gradient rainbow, bright pastel colors, white background
```

### 9.5 Leonardo.ai Spesifik Ayarlar

| Parametre | Önerilen Değer |
|-----------|---------------|
| Model | Leonardo Phoenix veya SDXL |
| Boyut | 256×256 (kule) / 512×128 (düşman sheet) / 128×128 (düşman tek) |
| Guidance Scale | 7–9 |
| Steps | 30–40 |
| Alchemy | Açık |
| PhotoReal | KAPALI |
| Tiling | KAPALI |

---

## 10. KALİTE KONTROL CHECKLIST

Her sprite üretildikten sonra bu kontrol uygulanır. Tek FAIL = RED.

### 10.1 Zorunlu Kontroller

```
□ Kamera açısı 45° izometrik mi?
□ Işık sol üstten (10:00) mi?
□ Arka plan tamamen şeffaf mı?
□ Watermark/logo/imza VAR MI? (varsa → ANINDA RED)
□ Tuval boyutu doğru mu? (256×256 kule / 128×128 düşman)
□ Obje tuvalda ortalanmış mı?
□ Silüet testi geçiyor mu? (45px'de okunabiliyor mu?)
```

### 10.2 Kule Özel Kontroller

```
□ Dairesel/oval taş platform üstünde mi?
□ Platform boyutu ~130px mi?
□ Kule tipi accent rengi doğru mu?
□ %70-20-10 renk oranı sağlanıyor mu?
□ Aynı tier'daki diğer kulelerle boyut tutarlı mı?
□ T1→T4 arası büyüme kademeli mi?
□ T4, T1'e hâlâ benziyor mu?
```

### 10.3 Düşman Özel Kontroller

```
□ 3/4 poz, sağa yürüyüş mü?
□ Base plate/zemin parçası YOK mu?
□ Düşman boyut kategorisine uygun mu?
□ Desatüre renk paleti mi? (boss hariç)
□ Chibi oran YOK mu? (büyük kafa/küçük gövde)
```

### 10.4 Tutarlılık Kontrolleri (Batch)

```
Aynı batch'teki tüm sprite'lar:
□ Aynı ışık yönünden mi aydınlatılmış?
□ Aynı kamera açısından mı çizilmiş?
□ Boyut oranları tutarlı mı?
□ Aynı stil dilinde mi? (dark fantasy stylized)
□ Platform şekli ve boyutu aynı mı? (kuleler)
```

---

## 11. ADLANDIRMA KURALLARI

### 11.1 Dosya İsimleri

```
Kuleler:  towers/{type}_t{tier}.webp      → towers/arrow_t1.webp
          towers/{type}_t4a.webp           → towers/arrow_t4a.webp (T4 dal A)
          towers/{type}_t4b.webp           → towers/arrow_t4b.webp (T4 dal B)

Düşmanlar: enemies/{camelCase}.webp        → enemies/armoredGiant.webp

Kale:     castle/castle_phase{0-2}.webp    → castle/castle_phase0.webp

Efektler: effects/{snake_case}.webp        → effects/fire_rain.webp

UI:       ui/{snake_case}.webp             → ui/btn_basla.webp

Tile:     tiles/{name}.webp                → tiles/grass.webp
          textures/{biome}/{name}.webp     → textures/forest/grass.webp

Arka plan: backgrounds/{biome}_bg.webp     → backgrounds/forest_bg.webp
```

### 11.2 Commit Etiketleme

```
git commit -m "art: [ASSET_TYPE] — [AÇIKLAMA]"

Örnekler:
  art: towers — arrow_t1 through arrow_t4 regenerated per style bible
  art: enemies — soldier walk pose fixed to 45° isometric
  art: fix — removed watermark from shadowLord
```

---

## 12. ÖNCELİK SIRASI — YENİDEN ÜRETİM

Phase 3'te yeniden üretilecek varlıklar, aciliyete göre:

### Acil (Yayın Engelleyici)

| # | Varlık | Sorun |
|---|--------|-------|
| 1 | `enemies/shadowLord.webp` | DEADOMART watermark |
| 2 | `enemies/troll.webp` | Beyaz artifact/bozuk şeffaflık |
| 3 | `enemies/goblin.webp` | Chibi stil + base plate |
| 4 | `enemies/soldier.webp` | Tam cepheden poz |
| 5 | `enemies/dragonEmperor.webp` | Kuş bakışı açı |

### Yüksek (Stil Tutarsızlığı)

| # | Varlık | Sorun |
|---|--------|-------|
| 6 | `enemies/cavalry.webp` | Açı tutarsız (3/4 ama 60°) |
| 7 | `towers/arrow_t4.webp` | T1'e hiç benzemiyor |
| 8 | `towers/dark_t1.webp` | Elmas/diamond taban |
| 9 | `towers/cannon_t1.webp` | Kare taban, cepheden bakış |
| 10 | `towers/fire_t1.webp` | Kare taban |

### Orta (Tutarlılık)

Tüm kalan tower sprite'ları (taban standardizasyonu + ışık düzeltme).
Tüm kalan enemy sprite'ları (açı + stil düzeltme).

---

> **Bu Style Bible Phase 3 (yeniden üretim) ve sonraki tüm sanat çalışmaları için tek referanstır.**
> Yeni sprite üretirken bu belgedeki Master Prefix + Kalite Kontrol Checklist kullanılacak.
> Onayın gelirse Phase 3'e geçiyorum — öncelik sırasına göre sprite yeniden üretim.
