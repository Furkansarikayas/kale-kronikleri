enum StatusType { burn, slow, poison, wet, curse }

class StatusEffect {
  final StatusType type;
  double remaining;
  final double duration;
  final double tickInterval;
  double _tickTimer = 0;

  // Effect values
  final int damagePerTick;     // burn, poison
  final double slowFactor;      // slow (0.5 = 50% slow)
  final double armorReduction;  // curse

  StatusEffect({
    required this.type,
    required this.duration,
    this.tickInterval = 1.0,
    this.damagePerTick = 0,
    this.slowFactor = 0.0,
    this.armorReduction = 0.0,
  }) : remaining = duration;

  bool get isExpired => remaining <= 0;

  /// Returns damage dealt this tick (0 if no tick this frame)
  int update(double dt) {
    remaining -= dt;
    if (isExpired) return 0;

    _tickTimer += dt;
    if (_tickTimer >= tickInterval && damagePerTick > 0) {
      _tickTimer -= tickInterval;
      return damagePerTick;
    }
    return 0;
  }

  static StatusEffect burn({int dps = 5, double duration = 3.0}) =>
    StatusEffect(type: StatusType.burn, duration: duration, damagePerTick: dps);

  static StatusEffect slow({double factor = 0.5, double duration = 2.0}) =>
    StatusEffect(type: StatusType.slow, duration: duration, slowFactor: factor);

  static StatusEffect poison({int dps = 3, double duration = 5.0}) =>
    StatusEffect(type: StatusType.poison, duration: duration, damagePerTick: dps);

  static StatusEffect wet({double duration = 3.0}) =>
    StatusEffect(type: StatusType.wet, duration: duration);

  static StatusEffect curse({double armorReduce = 10.0, double duration = 4.0}) =>
    StatusEffect(type: StatusType.curse, duration: duration, armorReduction: armorReduce);
}
