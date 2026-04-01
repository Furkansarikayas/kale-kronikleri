import '../data/enemy_data.dart';
import '../data/tower_data.dart';

/// Contextual tutorial hint system.
/// Shows progressive hints based on game state transitions.
enum TutorialTrigger {
  gameStart,        // Wave 0, no towers placed
  towerSelected,    // Player selected a tower from grid (onboarding only)
  firstTowerPlaced, // First tower placed
  firstWaveStart,   // Wave 1 started
  firstWaveComplete,// Wave 1 completed
  upgradeAvailable, // Has enough gold to upgrade a tower
  synergyPossible,  // Could form a synergy with current placement
  spellUnlocked,    // First spell available
  eliteAppeared,    // First elite enemy
  bossWave,         // Boss wave incoming (wave 5, 10, etc.)
  lowHp,            // Castle HP < 30%
  t4Available,      // Tower at tier 3
  comboOccurred,    // First combo triggered
  eventAppeared,    // First wave event
  endlessModeStart, // Endless mode activated
}

class TutorialHint {
  final TutorialTrigger trigger;
  final String message;
  final String icon; // icon name for display

  const TutorialHint({
    required this.trigger,
    required this.message,
    this.icon = 'info',
  });
}

class TutorialSystem {
  final bool isFirstRun;
  final Set<TutorialTrigger> _shownHints = {};
  TutorialHint? _currentHint;
  double _hintTimer = 0;
  static const double _hintDuration = 6.0;
  static const double _onboardingHintDuration = 8.0;

  TutorialSystem({this.isFirstRun = false});

  TutorialHint? get currentHint => _currentHint;

  /// Onboarding triggers that only show on first run.
  static const _onboardingTriggers = {
    TutorialTrigger.gameStart,
    TutorialTrigger.towerSelected,
    TutorialTrigger.firstTowerPlaced,
    TutorialTrigger.firstWaveStart,
    TutorialTrigger.firstWaveComplete,
    TutorialTrigger.upgradeAvailable,
  };

  /// Step-by-step onboarding hints (first run only).
  static const List<TutorialHint> _onboardingHints = [
    TutorialHint(
      trigger: TutorialTrigger.gameStart,
      message: 'Aşağıdan bir kule seç!',
      icon: 'start',
    ),
    TutorialHint(
      trigger: TutorialTrigger.towerSelected,
      message: 'Harita üzerinde yeşil alana dokunarak kuleyi yerleştir.',
      icon: 'place',
    ),
    TutorialHint(
      trigger: TutorialTrigger.firstTowerPlaced,
      message: 'Harika! Daha fazla kule koy veya ⚔ Dalga Başlat butonuna bas.',
      icon: 'wave',
    ),
    TutorialHint(
      trigger: TutorialTrigger.firstWaveStart,
      message: 'Düşmanlar geliyor! Kulelerin otomatik saldırıyor.',
      icon: 'target',
    ),
    TutorialHint(
      trigger: TutorialTrigger.firstWaveComplete,
      message: 'İlk dalga tamam! Kulelere dokunarak yükseltebilirsin.',
      icon: 'upgrade',
    ),
    TutorialHint(
      trigger: TutorialTrigger.upgradeAvailable,
      message: 'Bir kulen yükseltilebilir! Dokunup "Yükselt" butonuna bas.',
      icon: 'upgrade',
    ),
  ];

  /// Regular contextual hints (shown every run for advanced mechanics).
  static const List<TutorialHint> _contextualHints = [
    TutorialHint(
      trigger: TutorialTrigger.spellUnlocked,
      message: 'Büyü açıldı! Alt barda büyü ikonlarına basarak kale büyüleri kullan.',
      icon: 'spell',
    ),
    TutorialHint(
      trigger: TutorialTrigger.eliteAppeared,
      message: 'Elit düşman! Parlayan düşmanlar daha güçlü ama 2x altın verir.',
      icon: 'elite',
    ),
    TutorialHint(
      trigger: TutorialTrigger.bossWave,
      message: 'Boss dalgası geliyor! Güçlü kuleler ve büyüler hazırla.',
      icon: 'boss',
    ),
    TutorialHint(
      trigger: TutorialTrigger.lowHp,
      message: 'Kale tehlikede! Onarım büyüsünü veya destek kulesini düşün.',
      icon: 'danger',
    ),
    TutorialHint(
      trigger: TutorialTrigger.t4Available,
      message: 'Tier 4 yükseltme! İki branş arasından seçim yapabilirsin.',
      icon: 'branch',
    ),
    TutorialHint(
      trigger: TutorialTrigger.comboOccurred,
      message: 'Kombo! Farklı elementleri birleştirerek güçlü kombolar tetikle.',
      icon: 'combo',
    ),
    TutorialHint(
      trigger: TutorialTrigger.eventAppeared,
      message: 'Dalga olayı! Tüccar, hazine veya pusu gibi sürprizler çıkabilir.',
      icon: 'event',
    ),
  ];

  /// Try to show a hint for the given trigger. Returns true if a new hint was shown.
  bool tryShow(TutorialTrigger trigger) {
    if (_shownHints.contains(trigger)) return false;

    // On non-first runs, skip onboarding-only triggers
    if (!isFirstRun && _onboardingTriggers.contains(trigger)) return false;

    // Don't interrupt an existing hint
    if (_currentHint != null) return false;

    // Look up hint: first-run uses onboarding hints, then falls through to contextual
    TutorialHint? hint;
    if (isFirstRun) {
      hint = _onboardingHints.where((h) => h.trigger == trigger).firstOrNull;
    }
    hint ??= _contextualHints.where((h) => h.trigger == trigger).firstOrNull;
    if (hint == null) return false;

    _shownHints.add(trigger);
    _currentHint = hint;
    _hintTimer = isFirstRun && _onboardingTriggers.contains(trigger)
        ? _onboardingHintDuration
        : _hintDuration;
    return true;
  }

  void update(double dt) {
    if (_currentHint == null) return;
    _hintTimer -= dt;
    if (_hintTimer <= 0) {
      _currentHint = null;
    }
  }

  void dismiss() {
    _currentHint = null;
    _hintTimer = 0;
  }

  bool wasShown(TutorialTrigger trigger) => _shownHints.contains(trigger);

  // ─── Enemy weakness hints (Issue #2) ─────────────────────────────────────
  final Set<EnemyType> _seenEnemyTypes = {};

  /// Show weakness hint when a new enemy type is first encountered.
  bool tryShowEnemyWeakness(EnemyType type) {
    if (_seenEnemyTypes.contains(type)) return false;
    _seenEnemyTypes.add(type);

    final weaknesses = EnemyData.getWeaknesses(type);
    if (weaknesses.isEmpty) return false;

    // Don't interrupt existing hint
    if (_currentHint != null) return false;

    final enemyName = EnemyData.getStats(type).name;
    final towerNames = weaknesses.map((t) => TowerData.getStats(t).tierNames[0]).join(', ');
    final mechanic = _enemyMechanic(type);
    final message = '$enemyName zayıflığı: $towerNames${mechanic.isNotEmpty ? ' | $mechanic' : ''}';

    _currentHint = TutorialHint(
      trigger: TutorialTrigger.gameStart, // dummy trigger
      message: message,
      icon: 'weakness',
    );
    _hintTimer = 5.0;
    return true;
  }

  String _enemyMechanic(EnemyType type) {
    switch (type) {
      case EnemyType.cavalry: return 'Çok hızlı!';
      case EnemyType.goblin: return 'Kaleye ulaşırsa altın çalar!';
      case EnemyType.undead: return 'Öldürünce 3 küçük parçaya bölünür!';
      case EnemyType.healer: return 'Yakındaki düşmanları iyileştirir!';
      case EnemyType.burrower: return 'Yeraltına dalıp 4 hücre atlar!';
      case EnemyType.troll: return 'Sürekli HP yeniler!';
      case EnemyType.darkKnight: return 'Yakındaki düşmanlara zırh verir!';
      case EnemyType.shadowLord: return 'Işınlanır ve asker çağırır!';
      case EnemyType.dragonEmperor: return 'Nefes saldırısıyla kuleleri devre dışı bırakır!';
      default: return '';
    }
  }
}
