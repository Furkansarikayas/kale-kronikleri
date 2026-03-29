/// Contextual tutorial hint system.
/// Shows progressive hints based on game state transitions.
enum TutorialTrigger {
  gameStart,        // Wave 0, no towers placed
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
  final Set<TutorialTrigger> _shownHints = {};
  TutorialHint? _currentHint;
  double _hintTimer = 0;
  static const double _hintDuration = 6.0; // seconds to show each hint

  TutorialHint? get currentHint => _currentHint;

  static const List<TutorialHint> _allHints = [
    TutorialHint(
      trigger: TutorialTrigger.gameStart,
      message: 'Aşağıdan kule seç, yeşil alana yerleştir, dalga başlat!',
      icon: 'start',
    ),
    TutorialHint(
      trigger: TutorialTrigger.firstTowerPlaced,
      message: 'Harika! Kuleleri yan yana koyarak sinerji oluşturabilirsin.',
      icon: 'synergy',
    ),
    TutorialHint(
      trigger: TutorialTrigger.firstWaveStart,
      message: 'Düşmanlar yola çıktı! Kuleye dokunarak hedefleme modunu değiştirebilirsin.',
      icon: 'target',
    ),
    TutorialHint(
      trigger: TutorialTrigger.firstWaveComplete,
      message: 'İyi iş! Dalga arası kulelerini geliştir veya yeni kuleler yerleştir.',
      icon: 'upgrade',
    ),
    TutorialHint(
      trigger: TutorialTrigger.upgradeAvailable,
      message: 'Bir kulen yükseltilebilir! Dokunup "Yükselt" butonuna bas.',
      icon: 'upgrade',
    ),
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
    final hint = _allHints.where((h) => h.trigger == trigger).firstOrNull;
    if (hint == null) return false;

    // Don't interrupt an existing hint (queue would be overkill)
    if (_currentHint != null) return false;

    _shownHints.add(trigger);
    _currentHint = hint;
    _hintTimer = _hintDuration;
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
}
