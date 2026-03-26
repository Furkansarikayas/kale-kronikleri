# Kale Kronikleri — 2026 Modernizasyon Tasarım Dokümanı

## Özet

Kale Kronikleri'ni "30 yıl önceki oyun" görünümünden modern, profesyonel bir 2026 mobil oyununa dönüştürme tasarımı. Tüm değişiklikler tek seferde (big bang) uygulanacak.

## Kararlar

| Alan | Mevcut | Yeni |
|------|--------|------|
| Sanat yönü | Canvas geometrik çizimler | Stylized 2D sprite'lar |
| Renk paleti | Düz yeşil/kahve | Koyu fantazi + neon vurgular |
| Asset yöntemi | %100 programatik Canvas | Hibrit: sprite sheet + Canvas particle |
| UI/HUD | Düz renkli opak paneller | Glassmorphism (blur + saydam + neon) |
| Harita | Tek stil düz yeşil grid | 5 biome (zorluk seviyesine göre) |
| Animasyonlar | Yok | Tam set (ateş, yürüme, darbe, ölüm, sinerji, parallax, screen shake) |
| Uygulama stratejisi | — | Big bang (tek seferde) |

## 1. Sprite & Asset Sistemi

### Dizin Yapısı
```
assets/images/
├── towers/          # 12 kule tipi × 4 tier = 48 sprite + ateş animasyonları
├── enemies/         # 12 düşman tipi × yürüme animasyonu (4-8 frame)
├── castle/          # Kale sprite + hasar varyasyonları (3 aşama)
├── maps/            # 5 biome tile set (orman, çöl, kar, volkan, karanlık)
│   ├── forest/
│   ├── desert/
│   ├── snow/
│   ├── volcano/
│   └── dark/
├── effects/         # Patlama, buz, yıldırım sprite animasyonları
└── ui/              # Panel texture, ikon seti
```

### Teknik Değişiklikler
- Tüm custom `render()` metodları → Flame `SpriteComponent` / `SpriteAnimationComponent`
- Mevcut `sprite_cache.dart` → gerçek asset cache sistemi
- Asset kaynak: itch.io / kenney.nl ücretsiz paketler + AI ile tamamlama
- Eksik sprite'lar AI (Midjourney/Stable Diffusion) ile üretilecek

## 2. Harita & Biome Sistemi

### Biome Eşleştirme
| Zorluk | Biome | Zemin | Dekorasyon |
|--------|-------|-------|------------|
| Çırak | Orman | Yeşil çimen | Ağaç, çiçek, mantar |
| Şövalye | Çöl | Kum | Kaktüs, kaya, kemik |
| Lord | Kar | Buz/kar | Çam, buz sarkıtı, kar yığını |
| Kral | Volkan | Kırık kaya/kül | Lav akıntısı, duman, kristal |
| Efsane | Karanlık Diyar | Mor/siyah | Mor kristal, kemik, sis |

### Grid Davranışı
- Normal durumda grid gizli
- Kule yerleştirme modunda hafif ızgara gösterilir (yarı saydam)
- Buildable hücreler hafif yeşil glow, yol hücreleri gösterilmez
- Dekoratif objeler rastgele serpilir (map_generator.dart güncellenir)

## 3. UI/HUD — Glassmorphism

### Üst HUD Bar
- Yarı saydam panel (`BackdropFilter` + gaussian blur)
- HP barı: gradient dolgu (yeşil→kırmızı) + glow efekti
- Düşük HP'de pulse animasyonu
- Altın: parlayan ikon + sayı değişim animasyonu
- Dalga bilgisi: üst ortada minimal gösterim
- Neon border'lar kule renklerine uyumlu

### Alt Kule Seçim Paneli
- Yatay scroll, glassmorphism arka plan
- Seçili kule büyür (scale animasyonu)
- Kule ikonları sprite'lardan alınır
- Maliyet etiketi altında

### Wave Break Ekranı
- Arka plan blur
- Merkezi glassmorphism kart
- Gelen düşman preview'ı sprite'larla
- Animasyonlu geri sayım

### Diğer Ekranlar
- Ana menü: parallax arka plan + glassmorphism butonlar
- Ölüm ekranı: blur + sonuç kartı
- Meta ekranı: glassmorphism paneller + neon node'lar
- Pause: blur overlay + glassmorphism menü

## 4. Animasyon & Efekt Sistemi

### Kule Ateş Animasyonu
- Ateş anında kule sprite'ı hafif recoil (geri tepme)
- Mermi: sprite + arkasında renk bazlı trail
- Trail renkleri: ateş=turuncu/kırmızı, buz=mavi/beyaz, yıldırım=mor/beyaz

### Düşman Yürüme Animasyonu
- 4-8 frame sprite sheet animasyonu
- Yön bazlı flip (sola/sağa)
- Hız durumuna göre animasyon speed ayarı

### Darbe & Ölüm Efektleri
- Hasar alınca: kırmızı flash overlay (0.1s)
- Ölüm: fade out + particle burst (kule tipine göre renk)
- Floating damage text: yukarı kayarak solar
- Kritik vuruş: büyük font + farklı renk + screen shake

### Sinerji Parıltısı
- Aktif sinerji kuleleri: dönen altın parçacıklar
- Hafif altın glow aura
- Sinerji aktivasyonunda kısa parlama efekti

### Arka Plan Parallax
- 3 katman:
  1. Uzak (dağlar/gökyüzü) — çok yavaş hareket
  2. Orta (tepe/ağaç siluetleri) — orta hız
  3. Ön (dekorasyon/sis) — oyuncu hareketiyle
- Biome bazlı farklı katman sprite'ları
- Gece atmosferi: yıldızlar, ay, hafif sis

### Screen Shake
- Tetikleyiciler: boss hasarı, büyük patlamalar, kale hasarı
- Süre: 0.2-0.4s
- Şiddet: hasar miktarına orantılı
- Ayardan kapatılabilir (settings_screen.dart)

## 5. Kale Sprite

- Detaylı 2D sprite, biome uyumlu renk varyasyonları
- 3 hasar aşaması: sağlam → hasarlı → yıkık
- Pencerelerden sıcak ışık glow efekti
- HP azaldıkça glow söner, duman çıkar

## 6. Düşman Sprite'ları

### Tasarım Prensipleri
- Her düşmanın benzersiz silueti (okunabilirlik öncelik)
- Karanlık arka planda iyi görünecek renk kontrastı
- Status effect göstergeleri:
  - Frozen: buz kristalleri overlay
  - Poison: yeşil duman parçacıkları
  - Burn: ateş parçacıkları
  - Slow: mavi parıltı
  - Curse: mor aura

### Boyutlandırma
- Normal düşman: ~0.7 hücre boyutu (mevcut ile aynı)
- Boss: 1.5-2× hücre boyutu
- Zırhlı düşmanlar: normal boyut + zırh detayı

## 7. Renk Paleti

### Ana Palet
```
Arka plan zemin: #050510 → #0a0e1a (koyu lacivert/siyah)
Zemin: #0d1a0d → #1a2a1a (koyu orman yeşili)
Yol: #1a1510 → #3a3025 (koyu kahve/taş)
UI panel: rgba(15, 15, 25, 0.7) + blur
UI border: rgba(212, 168, 67, 0.3) (altın)
UI text: #f0e6d0 (krem)
```

### Kule Renkleri (neon vurgular)
```
Ateş: #e94560 / #ff6b81
Buz: #4ecdc4 / #a0e6ff
Yıldırım: #a78bfa / #c4b5fd
Zehir: #2ecc71 / #a0ffa0
Su: #3498db / #74b9ff
Karanlık: #8b5cf6 / #a78bfa
Kutsal: #ffd700 / #fff5e0
Ok: #d4a843 / #f0e6d0
Ateş (cannon): #e67e22 / #f39c12
Büyücü: #9b59b6 / #c084fc
Destek: #ffd700 / #fff8e0
Diken: #7f8c8d / #95a5a6
```

## 8. Dokunulan Dosyalar

### Yeni Dosyalar
- `assets/images/**` — tüm sprite asset'leri
- `lib/game/components/rendering/sprite_manager.dart` — merkezi sprite yönetimi
- `lib/game/components/effects/screen_shake.dart`
- `lib/game/components/effects/trail_effect.dart`
- `lib/game/components/effects/death_effect.dart`
- `lib/game/components/map/biome_data.dart`
- `lib/game/components/background/parallax_background.dart`

### Değişen Dosyalar
- `lib/game/components/towers/tower.dart` — Canvas render → sprite render
- `lib/game/components/enemies/enemy.dart` — Canvas render → sprite render + yürüme animasyonu
- `lib/game/components/castle.dart` — sprite render + hasar aşamaları
- `lib/game/components/map/grid_cell.dart` — tile sprite render + grid gizleme
- `lib/game/components/map/map_generator.dart` — biome desteği + dekorasyon
- `lib/game/components/map/game_map.dart` — biome seçimi
- `lib/game/components/background.dart` — parallax sistemi
- `lib/game/components/effects/hit_effect.dart` — sprite efektler
- `lib/game/components/towers/projectile.dart` — sprite + trail
- `lib/game/components/rendering/sprite_cache.dart` — gerçek asset cache
- `lib/game/kale_game.dart` — screen shake entegrasyonu + biome init
- `lib/game/data/game_config.dart` — biome-difficulty mapping
- `lib/screens/game_hud.dart` — glassmorphism UI
- `lib/screens/main_menu.dart` — parallax + glassmorphism
- `lib/screens/wave_break.dart` — blur + glassmorphism kart
- `lib/screens/death_screen.dart` — blur + sonuç kartı
- `lib/screens/pause_overlay.dart` — blur + glassmorphism
- `lib/screens/meta_screen.dart` — glassmorphism + neon node'lar
- `lib/screens/run_setup.dart` — biome preview + glassmorphism
- `lib/screens/settings_screen.dart` — screen shake toggle
- `lib/screens/bestiary_screen.dart` — düşman sprite'ları
- `lib/screens/synergy_guide.dart` — kule sprite'ları
- `pubspec.yaml` — asset path'leri ekleme
