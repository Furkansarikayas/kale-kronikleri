import 'tower_data.dart';

/// Per-tower attack feel — recoil, flash, projectile, shake.
/// Only recoil values are used initially; others reserved for later steps.
class AttackProfile {
  // Recoil
  final double recoilDuration;
  final double recoilScale;
  final double recoilKickback;

  // Muzzle flash (Step 2)
  final double flashSize;

  // Projectile (Step 3)
  final double projectileSpeed;
  final double projectileRadius;
  final int trailLength;

  // Screen shake (Step 4)
  final double shakeIntensity;
  final double shakeDuration;

  // Wind-up anticipation (0 = no wind-up, instant fire)
  final double windupDuration;

  const AttackProfile({
    required this.recoilDuration,
    required this.recoilScale,
    required this.recoilKickback,
    required this.flashSize,
    required this.projectileSpeed,
    required this.projectileRadius,
    required this.trailLength,
    this.shakeIntensity = 0,
    this.shakeDuration = 0,
    this.windupDuration = 0,
  });

  static AttackProfile get(TowerType type) => _profiles[type]!;

  static const Map<TowerType, AttackProfile> _profiles = {
    // Arrow: Quick precise snap
    TowerType.arrow: AttackProfile(
      recoilDuration: 0.12,
      recoilScale: 0.05,
      recoilKickback: 2.0,
      flashSize: 0.12,
      projectileSpeed: 380.0,
      projectileRadius: 2.5,
      trailLength: 8,
    ),

    // Fire: Explosive burst
    TowerType.fire: AttackProfile(
      recoilDuration: 0.18,
      recoilScale: 0.10,
      recoilKickback: 4.0,
      flashSize: 0.25,
      projectileSpeed: 320.0,
      projectileRadius: 3.5,
      trailLength: 10,
      shakeIntensity: 1.0,
      shakeDuration: 0.1,
      windupDuration: 0.10,
    ),

    // Ice: Smooth crystalline push
    TowerType.ice: AttackProfile(
      recoilDuration: 0.15,
      recoilScale: 0.04,
      recoilKickback: 1.0,
      flashSize: 0.15,
      projectileSpeed: 280.0,
      projectileRadius: 3.0,
      trailLength: 14,
    ),

    // Lightning: Instant electric snap
    TowerType.lightning: AttackProfile(
      recoilDuration: 0.08,
      recoilScale: 0.06,
      recoilKickback: 0.0,
      flashSize: 0.18,
      projectileSpeed: 500.0,
      projectileRadius: 2.0,
      trailLength: 6,
    ),

    // Poison: Subtle oozy release
    TowerType.poison: AttackProfile(
      recoilDuration: 0.12,
      recoilScale: 0.03,
      recoilKickback: 1.0,
      flashSize: 0.12,
      projectileSpeed: 250.0,
      projectileRadius: 3.5,
      trailLength: 10,
    ),

    // Cannon: Heavy powerful blast
    TowerType.cannon: AttackProfile(
      recoilDuration: 0.25,
      recoilScale: 0.15,
      recoilKickback: 6.0,
      flashSize: 0.30,
      projectileSpeed: 220.0,
      projectileRadius: 5.0,
      trailLength: 8,
      shakeIntensity: 3.0,
      shakeDuration: 0.15,
      windupDuration: 0.18,
    ),

    // Water: Flowing wave
    TowerType.water: AttackProfile(
      recoilDuration: 0.14,
      recoilScale: 0.05,
      recoilKickback: 2.0,
      flashSize: 0.15,
      projectileSpeed: 300.0,
      projectileRadius: 3.0,
      trailLength: 12,
    ),

    // Wizard: Mystical pulse
    TowerType.wizard: AttackProfile(
      recoilDuration: 0.15,
      recoilScale: 0.07,
      recoilKickback: 0.0,
      flashSize: 0.20,
      projectileSpeed: 280.0,
      projectileRadius: 3.5,
      trailLength: 10,
    ),

    // Dark: Sinister void pulse
    TowerType.dark: AttackProfile(
      recoilDuration: 0.20,
      recoilScale: 0.08,
      recoilKickback: 0.0,
      flashSize: 0.22,
      projectileSpeed: 260.0,
      projectileRadius: 4.0,
      trailLength: 14,
      shakeIntensity: 1.5,
      shakeDuration: 0.1,
      windupDuration: 0.12,
    ),

    // Holy: Radiant burst
    TowerType.holy: AttackProfile(
      recoilDuration: 0.15,
      recoilScale: 0.07,
      recoilKickback: 1.0,
      flashSize: 0.22,
      projectileSpeed: 320.0,
      projectileRadius: 3.0,
      trailLength: 10,
      windupDuration: 0.12,
    ),

    // Spike Wall: No ranged attack
    TowerType.spikeWall: AttackProfile(
      recoilDuration: 0.0,
      recoilScale: 0.0,
      recoilKickback: 0.0,
      flashSize: 0.0,
      projectileSpeed: 0.0,
      projectileRadius: 0.0,
      trailLength: 0,
    ),

    // Support: No attack
    TowerType.support: AttackProfile(
      recoilDuration: 0.0,
      recoilScale: 0.0,
      recoilKickback: 0.0,
      flashSize: 0.0,
      projectileSpeed: 0.0,
      projectileRadius: 0.0,
      trailLength: 0,
    ),
  };
}
