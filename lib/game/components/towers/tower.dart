import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/tower_data.dart';
import '../../data/game_config.dart';
import '../../data/t4_branch_data.dart';
import '../../data/attack_profiles.dart';
import '../effects/synergy_particles.dart';
import '../enemies/enemy.dart';
import '../rendering/tower_sprites.dart';
import 'projectile.dart';

enum TargetingMode { nearest, first, strongest }

class Tower extends RectangleComponent {
  final TowerType type;
  int _tier = 1;
  int _totalSpent = 0;
  double _cooldown = 0;

  // T4 branching
  T4BranchPath t4Branch = T4BranchPath.none;
  double _t4DmgMult = 1.0;
  double _t4RangeMult = 1.0;
  double _t4FireRateMult = 1.0;

  // Disable timer (dragon breath / curse)
  double disableTimer = 0;
  bool get isDisabled => disableTimer > 0;

  // Curse debuff
  double curseDebuffMult = 1.0; // 0.7 when cursed
  bool shadowAuraAffected = false; // ShadowLord aura debuff visual
  double _synergyDamageMultiplier = 1.0;
  double _synergyRangeBonus = 0.0;
  double _synergyFireRateMultiplier = 1.0;
  final int col;
  final int row;
  final double cellSize;

  double artifactDamageMultiplier = 1.0;
  double artifactRangeMultiplier = 1.0;
  double artifactFireRateMultiplier = 1.0;
  double supportDamageMultiplier = 1.0;
  double supportRangeMultiplier = 1.0;
  double kaleRuhuMultiplier = 1.0;
  bool showRange = false;
  bool synergyFreezeOnHit = false;
  int kills = 0;
  int totalDamageDealt = 0;
  TargetingMode targetingMode = TargetingMode.nearest;

  SynergyParticles? _synergyParticles;

  // Target caching — avoids full enemy scan every frame
  Enemy? _cachedTarget;
  double _retargetTimer = 0;
  static const double retargetInterval = 0.20; // re-scan every 200ms

  /// Get current cached target (may be null/stale).
  Enemy? get cachedTarget => _cachedTarget;

  /// Set a new cached target from external targeting logic.
  void setCachedTarget(Enemy? target) {
    _cachedTarget = target;
    _retargetTimer = 0;
  }

  /// Pre-offset the retarget timer so towers don't all scan on the same frame.
  void staggerRetargetTimer(double offset) {
    _retargetTimer = offset;
  }

  /// Returns true if the tower needs a new target scan.
  bool needsRetarget(double dt) {
    _retargetTimer += dt;
    // Retarget if: no target, target dead/gone/out-of-range, or timer expired
    if (_cachedTarget != null) {
      if (_cachedTarget!.isDead || _cachedTarget!.reachedCastle || !isInRange(_cachedTarget!.position)) {
        _cachedTarget = null;
        return true;
      }
    }
    if (_cachedTarget == null) return true;
    if (_retargetTimer >= retargetInterval) {
      _retargetTimer = 0;
      return true;
    }
    return false;
  }

  // Animation state
  double _animTimer = 0;
  double _recoilTimer = 0;
  double _lastFireDirX = 0;
  double _lastFireDirY = -1; // default: upward

  // Tier-up celebration
  double _tierUpTimer = 0;
  static const double _tierUpDuration = 0.4;

  // Merge absorption (stacks on top of tier-up)
  double _mergeTimer = 0;
  static const double _mergeDuration = 0.5;

  // Placement slam
  double _placeTimer;
  static const double _placeDuration = 0.3;

  // Effect color (tinted by tower type or branch)
  Color _effectColor = const Color(0xFFFFD700);

  // Cached paints for render — single-threaded, safe to share
  static final Paint _fp = Paint();
  static final Paint _sp = Paint()..style = PaintingStyle.stroke;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.medium;

  // Cached brightness ColorFilters (quantized to 10 levels, 0-100 brightness)
  static final List<ColorFilter> _brightnessFilters = List.generate(10, (i) {
    final v = (i + 1) * 10.0;
    return ColorFilter.matrix(<double>[
      1, 0, 0, 0, v, 0, 1, 0, 0, v, 0, 0, 1, 0, v, 0, 0, 0, 1, 0,
    ]);
  });

  AttackProfile get attackProfile => AttackProfile.get(type);

  Tower({
    required this.type,
    required this.col,
    required this.row,
    required this.cellSize,
  }) : _placeTimer = _placeDuration,
       super(
    position: Vector2(col * cellSize, row * cellSize),
    size: Vector2.all(cellSize),
    paint: Paint()..color = Colors.transparent, // We draw everything custom
    anchor: Anchor.topLeft,
  ) {
    _totalSpent = stats.cost;
  }

  TowerStats get stats => TowerData.getStats(type);
  int get tier => _tier;
  int get totalSpent => _totalSpent;

  int get currentDamage => (stats.damageAtTier(_tier) * _synergyDamageMultiplier * artifactDamageMultiplier * supportDamageMultiplier * kaleRuhuMultiplier * _t4DmgMult * curseDebuffMult).round();
  double get currentRange => (stats.rangeAtTier(_tier) + _synergyRangeBonus) * artifactRangeMultiplier * supportRangeMultiplier * _t4RangeMult;
  double get currentFireRate => stats.fireRate * _synergyFireRateMultiplier * artifactFireRateMultiplier * _t4FireRateMult;

  int get sellValue => (totalSpent * GameConfig.sellRefundRatio).round();

  bool get canUpgrade => _tier < 4;
  bool get needsT4Choice => _tier == 3; // at tier 3, next upgrade is T4 branch
  int get upgradeCost => stats.upgradeCost(_tier + 1);

  bool upgrade() {
    if (!canUpgrade) return false;
    final cost = upgradeCost;
    _tier++;
    _totalSpent += cost;
    return true;
  }

  /// Add spent gold from a merged tower (for sell value calculation).
  void addSpent(int amount) {
    _totalSpent += amount;
  }

  /// Trigger visual celebration for tier-up.
  void triggerTierUpEffect({Color? color}) {
    _tierUpTimer = _tierUpDuration;
    _effectColor = color ?? Color.lerp(primaryColor(type), const Color(0xFFFFD700), 0.7)!;
  }

  /// Trigger enhanced celebration for merge (includes tier-up effects).
  void triggerMergeEffect({Color? color}) {
    _tierUpTimer = _tierUpDuration;
    _mergeTimer = _mergeDuration;
    _effectColor = color ?? Color.lerp(primaryColor(type), const Color(0xFFFFD700), 0.7)!;
  }

  bool upgradeToT4(T4BranchPath path, int cost) {
    if (_tier != 3 || t4Branch != T4BranchPath.none) return false;
    _tier = 4;
    t4Branch = path;
    _totalSpent += cost;
    // Apply branch stat multipliers
    final branch = T4BranchData.getBranch(type);
    if (path == T4BranchPath.pathA) {
      _t4DmgMult = branch.dmgMultA;
      _t4RangeMult = branch.rangeMultA;
      _t4FireRateMult = branch.fireRateMultA;
    } else {
      _t4DmgMult = branch.dmgMultB;
      _t4RangeMult = branch.rangeMultB;
      _t4FireRateMult = branch.fireRateMultB;
    }
    return true;
  }

  String get t4Name {
    if (t4Branch == T4BranchPath.none) return stats.tierNames[3];
    final branch = T4BranchData.getBranch(type);
    return t4Branch == T4BranchPath.pathA ? branch.nameA : branch.nameB;
  }

  void applySynergyBonus({double damageMultiplier = 1.0, double rangeBonus = 0.0, double fireRateMultiplier = 1.0}) {
    _synergyDamageMultiplier = damageMultiplier;
    _synergyRangeBonus = rangeBonus;
    _synergyFireRateMultiplier = fireRateMultiplier;

    final hasSynergy = _synergyDamageMultiplier > 1.0 || _synergyRangeBonus > 0 || _synergyFireRateMultiplier < 1.0;
    if (hasSynergy && _synergyParticles == null) {
      _synergyParticles = SynergyParticles(cellSize: cellSize);
      add(_synergyParticles!);
    } else if (!hasSynergy && _synergyParticles != null) {
      _synergyParticles!.removeFromParent();
      _synergyParticles = null;
    }
  }

  void clearSynergyBonus() {
    _synergyDamageMultiplier = 1.0;
    _synergyRangeBonus = 0.0;
    _synergyFireRateMultiplier = 1.0;
    synergyFreezeOnHit = false;

    if (_synergyParticles != null) {
      _synergyParticles!.removeFromParent();
      _synergyParticles = null;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldown > 0) _cooldown -= dt;
    if (disableTimer > 0) disableTimer -= dt;
    if (_recoilTimer > 0) _recoilTimer -= dt;
    if (_tierUpTimer > 0) _tierUpTimer -= dt;
    if (_mergeTimer > 0) _mergeTimer -= dt;
    if (_placeTimer > 0) _placeTimer -= dt;
    _animTimer += dt;
  }

  bool canFire() => _cooldown <= 0 && !isDisabled && type != TowerType.spikeWall && type != TowerType.support;

  Projectile? tryFire(Vector2 targetPos) {
    if (!canFire()) return null;
    _cooldown = currentFireRate;
    _recoilTimer = attackProfile.recoilDuration;
    // Store fire direction for muzzle flash
    final dir = targetPos - (position + size / 2);
    final len = dir.length;
    if (len > 0) {
      _lastFireDirX = dir.x / len;
      _lastFireDirY = dir.y / len;
    }
    final profile = attackProfile;
    final ProjectileShape projShape;
    if (type == TowerType.arrow || type == TowerType.lightning) {
      projShape = ProjectileShape.bolt;
    } else if (type == TowerType.cannon) {
      projShape = ProjectileShape.heavy;
    } else {
      projShape = ProjectileShape.orb;
    }
    final TrailStyle trail = switch (type) {
      TowerType.arrow => TrailStyle.arrow,
      TowerType.fire => TrailStyle.fire,
      TowerType.ice => TrailStyle.ice,
      TowerType.lightning => TrailStyle.lightning,
      TowerType.poison => TrailStyle.poison,
      TowerType.cannon => TrailStyle.cannon,
      TowerType.water => TrailStyle.water,
      TowerType.dark => TrailStyle.dark,
      TowerType.wizard => TrailStyle.wizard,
      TowerType.holy => TrailStyle.holy,
      _ => TrailStyle.defaultTrail,
    };
    return Projectile(
      startPos: position + size / 2,
      target: targetPos,
      damage: currentDamage,
      color: primaryColor(type),
      speed: profile.projectileSpeed,
      projectileRadius: profile.projectileRadius,
      trailLength: profile.trailLength,
      shape: projShape,
      trailStyle: trail,
    );
  }

  bool isInRange(Vector2 targetPos) {
    final center = position + size / 2;
    final dx = center.x - targetPos.x;
    final dy = center.y - targetPos.y;
    final rangePx = currentRange * cellSize;
    return dx * dx + dy * dy <= rangePx * rangePx;
  }

  @override
  void render(Canvas canvas) {
    // 1. Draw cached sprite with recoil animation
    final spriteImage = TowerSpriteGenerator.instance.getSprite(type, _tier, t4Branch);
    if (spriteImage != null) {
      final src = Rect.fromLTWH(0, 0, spriteImage.width.toDouble(), spriteImage.height.toDouble());
      final dst = Rect.fromLTWH(-cellSize * 0.25, -cellSize * 0.65, cellSize * 1.5, cellSize * 1.65);

      // Ground anchor: dark base plate shadow
      final baseCx = cellSize / 2;
      final baseCy = cellSize * 0.82;
      // Dark ground shadow
      _fp.color = const Color(0x40000000);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(baseCx, baseCy), width: cellSize * 0.9, height: cellSize * 0.22),
        _fp,
      );
      // Tier-colored base ring
      final baseColor = primaryColor(type);
      _sp.color = baseColor.withAlpha(25 + _tier * 12);
      _sp.strokeWidth = 0.8 + _tier * 0.3;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(baseCx, baseCy), width: cellSize * 0.85, height: cellSize * 0.20),
        _sp,
      );

      // Placement slam: scale 1.3→1.0 with ease-out
      final hasPlacePop = _placeTimer > 0;
      if (hasPlacePop) {
        final t = (_placeTimer / _placeDuration).clamp(0.0, 1.0);
        final placeScale = 1.0 + 0.3 * t * t; // ease-out: fast start, soft landing
        canvas.save();
        canvas.translate(cellSize / 2, cellSize / 2);
        canvas.scale(placeScale);
        canvas.translate(-cellSize / 2, -cellSize / 2);
      }

      // Merge absorption scale pop (wraps entire sprite draw)
      final hasMergePop = _mergeTimer > 0;
      if (hasMergePop) {
        final progress = 1.0 - (_mergeTimer / _mergeDuration).clamp(0.0, 1.0);
        final popScale = 1.0 + 0.12 * math.sin(math.pi * math.sqrt(progress));
        canvas.save();
        canvas.translate(cellSize / 2, cellSize / 2);
        canvas.scale(popScale);
        canvas.translate(-cellSize / 2, -cellSize / 2);
      }

      if (_recoilTimer > 0) {
        final profile = attackProfile;
        final t = (_recoilTimer / profile.recoilDuration).clamp(0.0, 1.0);
        final scaleBump = 1.0 + profile.recoilScale * t;
        final kickBack = -profile.recoilKickback * t;
        canvas.save();
        canvas.translate(cellSize / 2, cellSize / 2);
        canvas.scale(scaleBump);
        canvas.translate(-cellSize / 2, -cellSize / 2 + kickBack);
        _imgPaint.colorFilter = null;
        canvas.drawImageRect(spriteImage, src, dst, _imgPaint);
        canvas.restore();
      } else {
        // Wind-up detection: last windupDuration seconds of cooldown
        final profile = attackProfile;
        final bool isWindingUp = profile.windupDuration > 0 &&
            _cooldown > 0 && _cooldown <= profile.windupDuration;
        // windupT: 0 at start of wind-up → 1 at moment of fire
        final double windupT = isWindingUp
            ? (1.0 - _cooldown / profile.windupDuration).clamp(0.0, 1.0)
            : 0.0;

        // Idle animation: subtle breathe + sway, scaled by tier
        final idleBreathe = _tier == 1 ? 0.005
            : _tier == 2 ? 0.008
            : _tier == 3 ? 0.010
            : 0.012;
        final idleSway = _tier == 1 ? 0.005
            : _tier == 2 ? 0.009
            : _tier == 3 ? 0.012
            : 0.014;

        // During wind-up: suppress idle sway, compress scale
        final windupCompress = isWindingUp ? 1.0 - 0.03 * windupT : 1.0;
        final breatheScale = (1.0 + math.sin(_animTimer * 2.0) * idleBreathe) * windupCompress;
        final swayAngle = math.sin(_animTimer * 1.5 + 0.7) * idleSway * (isWindingUp ? 1.0 - windupT * 0.8 : 1.0);

        // T2+ hover bob: gentle vertical float (T4 deeper and slower)
        final hoverY = _tier >= 2
            ? math.sin(_animTimer * (_tier == 4 ? 0.9 : 1.2)) * (_tier == 4 ? 1.5 : _tier == 3 ? 1.0 : 0.6)
            : 0.0;

        canvas.save();
        canvas.translate(cellSize / 2, cellSize / 2 + hoverY);
        canvas.scale(breatheScale);
        canvas.rotate(swayAngle);
        canvas.translate(-cellSize / 2, -cellSize / 2);

        _imgPaint.colorFilter = null;

        // Tier-up brightness pulse (overrides shimmer while active)
        if (_tierUpTimer > 0) {
          final upT = (_tierUpTimer / _tierUpDuration).clamp(0.0, 1.0);
          final idx = (upT * 8).round().clamp(0, 9); // 0-80 brightness → indices 0-8
          _imgPaint.colorFilter = _brightnessFilters[idx];
        }
        // T3+ shimmer: periodic brightness pulse (T4 gets branch-colored)
        else if (_tier >= 3) {
          final shimmer = math.sin(_animTimer * 1.8 + 2.0) * 0.5 + 0.5;
          final shimmerAmount = shimmer * (_tier == 4 ? 25.0 : 20.0);
          if (shimmerAmount > 5.0) {
            // Use closest cached brightness filter (uniform brightness only)
            final idx = (shimmerAmount / 10).round().clamp(0, 9);
            _imgPaint.colorFilter = _brightnessFilters[idx];
          }
        }

        canvas.drawImageRect(spriteImage, src, dst, _imgPaint);

        // Wind-up charge glow (drawn in sprite transform space)
        if (isWindingUp) {
          final towerColor = primaryColor(type);
          final cx = cellSize / 2;
          final cy = cellSize * 0.15;

          // Inner charge glow — intensifies as windupT approaches 1
          final chargeAlpha = (windupT * 115).round().clamp(0, 255);
          _fp.color = towerColor.withAlpha(chargeAlpha);
          canvas.drawCircle(
            Offset(cx, cy),
            cellSize * (0.25 + 0.10 * windupT),
            _fp,
          );

          // Bright core pinpoint — appears in last 40% of wind-up
          if (windupT > 0.6) {
            final coreT = ((windupT - 0.6) / 0.4).clamp(0.0, 1.0);
            _fp.color = Color.fromRGBO(255, 255, 240, coreT * 0.7);
            canvas.drawCircle(
              Offset(cx, cy),
              cellSize * 0.08 * coreT,
              _fp,
            );
          }
        }

        canvas.restore();
      }

      // Close merge scale pop wrapper
      if (hasMergePop) {
        canvas.restore();
      }

      // Close placement slam wrapper
      if (hasPlacePop) {
        canvas.restore();
      }
    }

    // Placement ground ring + flash (drawn outside sprite transforms)
    if (_placeTimer > 0) {
      _renderPlacementEffect(canvas);
    }

    // Edge contrast outline for combat readability
    if (_recoilTimer <= 0 && _placeTimer <= 0) {
      _sp.color = Color.fromARGB(15 + _tier * 5, 0, 0, 0);
      _sp.strokeWidth = 0.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cellSize * 0.05, -cellSize * 0.15, cellSize * 0.9, cellSize * 1.0),
          const Radius.circular(4),
        ),
        _sp,
      );
    }

    // Per-tier persistent visual accent (T2-T3): base plate glow + accent ring
    if (_tier >= 2 && _tier < 4 && _recoilTimer <= 0) {
      _renderTierAccent(canvas);
    }

    // T4 ambient glow pulse + orbiting energy motes
    if (_tier == 4 && _recoilTimer <= 0) {
      final glowPhase = (0.08 + 0.05 * math.sin(_animTimer * 2.5)).clamp(0.0, 1.0);
      final isPathA = t4Branch == T4BranchPath.pathA;
      final glowColor = isPathA
          ? Color.fromRGBO(255, 200, 80, glowPhase)
          : Color.fromRGBO(120, 180, 255, glowPhase);
      _fp.color = glowColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-cellSize * 0.15, -cellSize * 0.5, cellSize * 1.3, cellSize * 1.45),
          const Radius.circular(6),
        ),
        _fp,
      );

      // 2 orbiting energy motes (~8s per revolution)
      final moteCenterY = cellSize * 0.15;
      for (int i = 0; i < 2; i++) {
        final moteAngle = _animTimer * 0.8 + i * math.pi;
        final moteR = cellSize * 0.55;
        final moteX = cellSize / 2 + math.cos(moteAngle) * moteR;
        final moteY = moteCenterY + math.sin(moteAngle) * moteR * 0.6;
        final moteAlpha = (0.4 + 0.2 * math.sin(_animTimer * 3 + i * 1.5)).clamp(0.0, 1.0);
        _fp.color = isPathA
            ? Color.fromRGBO(255, 200, 80, moteAlpha)
            : Color.fromRGBO(120, 180, 255, moteAlpha);
        canvas.drawCircle(Offset(moteX, moteY), 2.0, _fp);
      }
    }

    // Tier-up celebration: double ring + center flash + rising sparks
    if (_tierUpTimer > 0) {
      final t = (_tierUpTimer / _tierUpDuration).clamp(0.0, 1.0);
      final progress = 1.0 - t; // 0→1 over animation
      final cx = cellSize / 2;
      final cy = cellSize * 0.15;

      // Inner expanding ring (tinted by tower type)
      final ringRadius = cellSize * (0.3 + 0.7 * progress);
      final ringAlpha = (t * 160).round().clamp(0, 255);
      _sp.color = _effectColor.withAlpha(ringAlpha);
      _sp.strokeWidth = 2.5 * t;
      canvas.drawCircle(Offset(cx, cy), ringRadius, _sp);

      // Outer expanding ring (wider, softer — makes upgrade feel bigger)
      final outerRadius = cellSize * (0.5 + 0.9 * progress);
      final outerAlpha = (t * 100).round().clamp(0, 255);
      _sp.color = _effectColor.withAlpha(outerAlpha);
      _sp.strokeWidth = 1.5 * t;
      canvas.drawCircle(Offset(cx, cy), outerRadius, _sp);

      // Bright center flash
      final flashAlpha = (t * 140).round().clamp(0, 255);
      _fp.color = Color.fromARGB(flashAlpha, 255, 255, 240);
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.35 * t, _fp);

      // Rising sparks (4 bright dots shooting upward)
      for (int i = 0; i < 4; i++) {
        final sparkAngle = i * math.pi / 2 + 0.4;
        final sparkDist = progress * cellSize * 0.7;
        final sparkX = cx + math.cos(sparkAngle) * sparkDist * 0.5;
        final sparkY = cy - sparkDist - i * 3; // shoots upward
        final sparkAlpha = (t * 200).round().clamp(0, 255);
        _fp.color = Color.fromARGB(sparkAlpha, 255, 255, 200);
        canvas.drawCircle(Offset(sparkX, sparkY), 2.0 * t, _fp);
        // Tiny glow behind spark
        _fp.color = _effectColor.withAlpha((sparkAlpha * 0.3).round().clamp(0, 255));
        canvas.drawCircle(Offset(sparkX, sparkY), 4.0 * t, _fp);
      }
    }

    // Merge celebration: second ring + absorption glow
    if (_mergeTimer > 0) {
      final mt = (_mergeTimer / _mergeDuration).clamp(0.0, 1.0);
      final cx = cellSize / 2;
      final cy = cellSize * 0.15;

      // Second expanding ring (larger, slightly delayed, type-tinted)
      if (mt < 0.85) {
        final ringT = mt / 0.85;
        final ringRadius = cellSize * (0.4 + 0.8 * (1.0 - ringT));
        final ringAlpha = (ringT * 130).round().clamp(0, 255);
        _sp.color = _effectColor.withAlpha(ringAlpha);
        _sp.strokeWidth = 1.5 * ringT;
        canvas.drawCircle(Offset(cx, cy), ringRadius, _sp);
      }

      // Absorption glow (type-tinted pulse)
      final glowAlpha = (mt * 90).round().clamp(0, 255);
      _fp.color = _effectColor.withAlpha(glowAlpha);
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.4, _fp);
    }

    // 2. Synergy glow overlay
    if (_synergyDamageMultiplier > 1.0 || _synergyRangeBonus > 0 || _synergyFireRateMultiplier < 1.0 || synergyFreezeOnHit) {
      final glowAlpha = (0.3 + 0.2 * math.sin(_animTimer * 3)).clamp(0.0, 1.0);
      _sp.color = Color.fromRGBO(255, 215, 0, glowAlpha);
      _sp.strokeWidth = 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-cellSize * 0.27, -cellSize * 0.67, cellSize * 1.54, cellSize * 1.69),
          const Radius.circular(4),
        ),
        _sp,
      );
    }

    // 3. Support aura
    if (supportDamageMultiplier > 1.0 || supportRangeMultiplier > 1.0) {
      _fp.color = const Color(0x18FFFF00);
      canvas.drawCircle(Offset(cellSize / 2, cellSize / 2), cellSize * 0.6, _fp);
    }

    // 4. Range indicator (when selected)
    if (showRange) {
      final rangePx = currentRange * cellSize;
      final rangeCenter = Offset(cellSize / 2, cellSize / 2);
      _fp.color = const Color(0x1800FF88);
      canvas.drawCircle(rangeCenter, rangePx, _fp);
      _sp.color = const Color(0x4400FF88);
      _sp.strokeWidth = 1.5;
      canvas.drawCircle(rangeCenter, rangePx, _sp);
    }

    // 5. Muzzle flash (when shooting)
    if (_recoilTimer > 0) {
      final profile = attackProfile;
      final t = (_recoilTimer / profile.recoilDuration).clamp(0.0, 1.0);
      final towerColor = primaryColor(type);
      final flashSize = profile.flashSize;
      final flashX = cellSize / 2 + _lastFireDirX * cellSize * 0.15;
      final flashY = cellSize * 0.0 + _lastFireDirY * cellSize * 0.15;
      final flashCenter = Offset(flashX, flashY);

      _fp.color = towerColor.withAlpha((t * 120).round());
      canvas.drawCircle(flashCenter, cellSize * flashSize * t, _fp);

      // Bright white core
      _fp.color = Color.fromRGBO(255, 255, 240, t * 0.8);
      canvas.drawCircle(flashCenter, cellSize * flashSize * 0.45 * t, _fp);
    }

    // 6. Disable overlay
    if (isDisabled) {
      _fp.color = const Color(0x66FF0000);
      canvas.drawRect(
        Rect.fromLTWH(-cellSize * 0.25, -cellSize * 0.65, cellSize * 1.5, cellSize * 1.65),
        _fp,
      );
    }

    // 7. Curse debuff indicator
    if (curseDebuffMult < 1.0) {
      _fp.color = const Color(0xFFAA00AA);
      canvas.drawCircle(Offset(cellSize / 2, -cellSize * 0.3), 4, _fp);
    }

    // 8. ShadowLord aura debuff: red pulse + slow-down feel
    if (shadowAuraAffected) {
      final redPulse = 0.15 + 0.1 * math.sin(_animTimer * 4);
      final redAlpha = (redPulse * 255).round().clamp(0, 60);
      _fp.color = Color.fromARGB(redAlpha, 255, 30, 30);
      canvas.drawRect(Rect.fromLTWH(0, 0, cellSize, cellSize), _fp);
      // Small debuff icon
      _fp.color = const Color(0xBBFF3333);
      canvas.drawCircle(Offset(cellSize - 6, -4), 3, _fp);
    }
  }

  /// Placement slam: expanding ground ring + center flash.
  void _renderPlacementEffect(Canvas canvas) {
    final t = (1.0 - _placeTimer / _placeDuration).clamp(0.0, 1.0); // 0→1
    final center = Offset(cellSize / 2, cellSize / 2);
    final color = primaryColor(type);

    // Expanding ground ring
    final ringRadius = cellSize * 0.3 + t * cellSize * 0.5;
    final ringAlpha = ((1.0 - t) * 180).round().clamp(0, 255);
    _sp.color = color.withAlpha(ringAlpha);
    _sp.strokeWidth = 2.5 * (1.0 - t);
    canvas.drawCircle(center, ringRadius, _sp);

    // Center flash (bright at start, fades quickly)
    if (t < 0.5) {
      final flashT = t / 0.5;
      final flashAlpha = ((1.0 - flashT) * 120).round().clamp(0, 255);
      _fp.color = Color.fromARGB(flashAlpha, 255, 255, 220);
      canvas.drawCircle(center, cellSize * 0.3 * (1.0 - flashT * 0.5), _fp);
    }
  }

  /// Per-tier persistent visual evolution (T2-T3).
  /// Adds structural elements that make each tier visibly distinct.
  void _renderTierAccent(Canvas canvas) {
    final cx = cellSize / 2;
    final cy = cellSize * 0.15; // tower visual center
    final color = primaryColor(type);
    final isT3 = _tier >= 3;

    // ── T2+: Structural base ring — permanent visible change ──
    final baseRingRadius = cellSize * (isT3 ? 0.52 : 0.42);
    _sp.color = color.withAlpha(isT3 ? 55 : 35);
    _sp.strokeWidth = isT3 ? 2.0 : 1.5;
    canvas.drawCircle(Offset(cx, cellSize * 0.55), baseRingRadius, _sp);

    // ── T2+: Base plate glow — ground presence ──
    final plateWidth = cellSize * (isT3 ? 1.05 : 0.85);
    _fp.color = color.withAlpha(isT3 ? 45 : 28);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cellSize * 0.74),
        width: plateWidth,
        height: cellSize * 0.18,
      ),
      _fp,
    );

    // ── T2+: Accent nodes — 2 small structural dots flanking the tower ──
    final nodeY = cellSize * 0.55;
    final nodeDist = cellSize * (isT3 ? 0.48 : 0.38);
    final nodeAlpha = isT3 ? 50 : 30;
    final nodeSize = isT3 ? 2.0 : 1.5;
    _fp.color = color.withAlpha(nodeAlpha);
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(cx + side * nodeDist, nodeY), nodeSize, _fp);
    }

    // ── T3 only: Type-specific core element + rotating energy ring ──
    if (!isT3) return;

    // Slow rotating accent ring with 4 energy nodes
    final ringAngle = _animTimer * 0.6;
    final ringR = cellSize * 0.38;
    _sp.color = color.withAlpha(20);
    _sp.strokeWidth = 0.8;
    canvas.drawCircle(Offset(cx, cy), ringR, _sp);
    _fp.color = color.withAlpha(60);
    for (int i = 0; i < 4; i++) {
      final a = ringAngle + i * math.pi / 2;
      final nx = cx + math.cos(a) * ringR;
      final ny = cy + math.sin(a) * ringR;
      canvas.drawCircle(Offset(nx, ny), 1.8, _fp);
    }

    // Type-specific core glow
    _renderTypeCore(canvas, cx, cy, color);
  }

  /// Per-type core identity element at T3. Each tower type feels distinct.
  void _renderTypeCore(Canvas canvas, double cx, double cy, Color color) {
    final pulse = 0.5 + 0.5 * math.sin(_animTimer * 2.0);

    switch (type) {
      case TowerType.fire:
        // Flame core: flickering warm glow
        final flicker = 0.6 + 0.4 * math.sin(_animTimer * 5.0 + 1.3);
        final a = (flicker * 55).round().clamp(0, 68);
        _fp.color = Color.fromARGB(a, 255, 120, 20);
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.175, _fp);
        // Hot pinpoint
        _fp.color = Color.fromARGB((flicker * 70).round(), 255, 220, 100);
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.063, _fp);
        // Upward triangle flame tip
        final triPath = ui.Path()
          ..moveTo(cx, cy - cellSize * 0.22)
          ..lineTo(cx - cellSize * 0.09, cy - cellSize * 0.07)
          ..lineTo(cx + cellSize * 0.09, cy - cellSize * 0.07)
          ..close();
        _fp.color = Color.fromARGB((flicker * 38).round(), 255, 160, 30);
        canvas.drawPath(triPath, _fp);

      case TowerType.ice:
        // Crystal core: diamond shape (rotated square) — 30% bigger
        final size = cellSize * 0.156;
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(math.pi / 4 + _animTimer * 0.3);
        _sp.color = color.withAlpha((pulse * 50).round().clamp(0, 60));
        _sp.strokeWidth = 1.5;
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: size, height: size),
          _sp,
        );
        canvas.restore();
        _fp.color = Color.fromARGB((pulse * 45).round(), 180, 240, 255);
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.078, _fp);

      case TowerType.dark:
        // Void core: dark center with inverted glow + second orbiting ring
        _fp.color = Color.fromARGB((pulse * 40).round(), 10, 0, 30);
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.15, _fp);
        _sp.color = color.withAlpha((pulse * 25).round().clamp(0, 35));
        _sp.strokeWidth = 1.0;
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.225, _sp);
        // Second orbiting ring slightly offset for depth
        final orbitAngle = _animTimer * 0.7;
        _sp.color = color.withAlpha((pulse * 15).round().clamp(0, 25));
        _sp.strokeWidth = 0.7;
        canvas.drawCircle(
          Offset(cx + math.cos(orbitAngle) * cellSize * 0.06, cy + math.sin(orbitAngle) * cellSize * 0.06),
          cellSize * 0.175, _sp);

      case TowerType.holy:
        // Radiant orb: bright center with 4 subtle rays
        _fp.color = Color.fromARGB((pulse * 40).round(), 255, 240, 180);
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.1, _fp);
        _fp.color = Color.fromARGB((pulse * 30).round(), 255, 255, 220);
        for (int i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + _animTimer * 0.2;
          final rx = cx + math.cos(a) * cellSize * 0.2;
          final ry = cy + math.sin(a) * cellSize * 0.2;
          canvas.drawCircle(Offset(rx, ry), 1.0, _fp);
        }

      case TowerType.cannon:
        // Reinforced mass: thick ring + heavy center dot
        _sp.color = color.withAlpha(35);
        _sp.strokeWidth = 3.0;
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.1875, _sp);
        _fp.color = Color.fromARGB(45, 100, 100, 110);
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.0625, _fp);

      case TowerType.lightning:
        // Electric sparks: 3 fast-orbiting dots
        _fp.color = Color.fromARGB((pulse * 60).round(), 255, 230, 50);
        for (int i = 0; i < 3; i++) {
          final a = _animTimer * 4.0 + i * math.pi * 2 / 3;
          final d = cellSize * 0.15;
          canvas.drawCircle(
            Offset(cx + math.cos(a) * d, cy + math.sin(a) * d), 1.2, _fp);
        }

      case TowerType.poison:
        // Bubbling dots: 3 slowly drifting dots
        _fp.color = Color.fromARGB((pulse * 45).round(), 60, 255, 60);
        for (int i = 0; i < 3; i++) {
          final bobY = math.sin(_animTimer * 1.5 + i * 2.0) * cellSize * 0.06;
          final bx = cx + (i - 1) * cellSize * 0.1;
          canvas.drawCircle(Offset(bx, cy + bobY), 1.5, _fp);
        }

      case TowerType.water:
        // Ripple ring: expanding + fading concentric ring
        final rippleT = (_animTimer * 0.5) % 1.0;
        final rippleR = cellSize * (0.08 + 0.15 * rippleT);
        final rippleA = ((1.0 - rippleT) * 35).round().clamp(0, 40);
        _sp.color = color.withAlpha(rippleA);
        _sp.strokeWidth = 0.8;
        canvas.drawCircle(Offset(cx, cy), rippleR, _sp);

      case TowerType.wizard:
        // Mystic star: slow rotating 3-point highlight
        _fp.color = Color.fromARGB((pulse * 40).round(), 180, 80, 240);
        for (int i = 0; i < 3; i++) {
          final a = _animTimer * 0.8 + i * math.pi * 2 / 3;
          final d = cellSize * 0.13;
          canvas.drawCircle(
            Offset(cx + math.cos(a) * d, cy + math.sin(a) * d), 1.5, _fp);
        }

      case TowerType.arrow:
        // Precision lines: 2 subtle crosshair lines
        final lineA = (pulse * 25).round().clamp(0, 30);
        _sp.color = color.withAlpha(lineA);
        _sp.strokeWidth = 0.8;
        canvas.drawLine(Offset(cx - cellSize * 0.12, cy), Offset(cx + cellSize * 0.12, cy), _sp);
        canvas.drawLine(Offset(cx, cy - cellSize * 0.12), Offset(cx, cy + cellSize * 0.12), _sp);

      case TowerType.spikeWall:
      case TowerType.support:
        // Minimal: just a subtle center dot
        _fp.color = color.withAlpha((pulse * 25).round());
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.06, _fp);
    }
  }

  static Color primaryColor(TowerType type) {
    switch (type) {
      case TowerType.arrow: return const Color(0xFF9E5B3C);     // rich mahogany/copper
      case TowerType.ice: return const Color(0xFF22CCEE);        // brilliant cyan/frost
      case TowerType.fire: return const Color(0xFFFF5511);       // bright orange-red
      case TowerType.lightning: return const Color(0xFFFFDD00);  // electric bright yellow
      case TowerType.poison: return const Color(0xFF33FF33);     // toxic neon green
      case TowerType.cannon: return const Color(0xFF4A5568);     // dark steel/gunmetal
      case TowerType.spikeWall: return const Color(0xFF555555);
      case TowerType.support: return const Color(0xFFDDCC00);
      case TowerType.water: return const Color(0xFF00BBCC);      // ocean turquoise
      case TowerType.wizard: return const Color(0xFFAA33DD);     // vibrant violet
      case TowerType.dark: return const Color(0xFF3311AA);       // deep indigo
      case TowerType.holy: return const Color(0xFFFFDD66);       // radiant warm white-gold
    }
  }

}
