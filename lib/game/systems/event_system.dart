import 'dart:math' as math;

enum WaveEventType { merchant, treasure, ambush, castleRepair, curse }

class WaveEventDef {
  final WaveEventType type;
  final String name;
  final String description;
  final int? goldAmount; // for treasure
  final bool needsAction; // merchant needs player interaction

  const WaveEventDef({
    required this.type,
    required this.name,
    required this.description,
    this.goldAmount,
    this.needsAction = false,
  });
}

class EventSystem {
  static const int eventFrequency = 3; // every N waves
  static const double eventChance = 0.40;

  /// Roll a random event for this wave. Returns null if no event.
  static WaveEventDef? rollEvent(int waveNumber, math.Random rng) {
    // Only trigger every N waves, starting from wave 3
    if (waveNumber < 3 || waveNumber % eventFrequency != 0) return null;
    if (rng.nextDouble() > eventChance) return null;

    final eventIndex = rng.nextInt(5);
    switch (eventIndex) {
      case 0:
        return const WaveEventDef(
          type: WaveEventType.merchant,
          name: 'Gezgin Tüccar',
          description: '50 altına rastgele güçlendirme satın al',
          needsAction: true,
        );
      case 1:
        final gold = 30 + rng.nextInt(51); // 30-80
        return WaveEventDef(
          type: WaveEventType.treasure,
          name: 'Hazine Sandığı',
          description: '+$gold altın bulundu!',
          goldAmount: gold,
        );
      case 2:
        return const WaveEventDef(
          type: WaveEventType.ambush,
          name: 'Pusu!',
          description: 'Düşmanlar aniden saldırıyor!',
        );
      case 3:
        return const WaveEventDef(
          type: WaveEventType.castleRepair,
          name: 'Kale Tamircisi',
          description: 'Kale HP %15 onarıldı',
        );
      case 4:
        return const WaveEventDef(
          type: WaveEventType.curse,
          name: 'Karanlık Lanet',
          description: 'Rastgele bir kulenin hasarı 2 dalga boyunca %20 azalır',
        );
      default:
        return null;
    }
  }
}
