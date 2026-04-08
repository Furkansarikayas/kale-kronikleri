import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/enemy_data.dart';
import '../../data/game_config.dart';
import '../../data/tower_data.dart';
import '../../systems/pathfinding.dart';
import '../../systems/elite_system.dart';
import '../../systems/audio_system.dart';
import '../rendering/enemy_sprites.dart';
import 'status_effect.dart';

class Enemy extends RectangleComponent {
  final EnemyType type;
  final EnemyStats baseStats;
  final List<GridPos> path;
  final double cellSize;

  int _hp;
  int _scaledMaxHp;
  int _pathIndex = 0;
  bool _reachedCastle = false;
  bool _isDead = false;
  final List<StatusEffect> _effects = [];

  // Elite system
  bool isElite = false;
  EliteModifier? eliteModifier;

  // Boss ability tracking
  double bossAbilityTimer = 0;
  bool abilitiesDisabled = false; // EMP effect
  bool isEnraged = false; // Dragon emperor enrage at 50% HP

  // Adaptation: takes 30% less damage from this tower type (null = no adaptation)
  TowerType? adaptedAgainst;

  // Threat telegraph (set externally, ticks down)
  double telegraphTimer = 0;
  Color telegraphColor = const Color(0xFFFF4400);
  double telegraphProgress = 0; // 0→1 over wind-up window (boss only)

  // Boss attack release aftermath (set externally when ability fires)
  double attackReleaseTimer = 0;
  static const double _attackReleaseDuration = 0.4;

  // Unique ID for combo system tracking
  static int _nextId = 0;
  final int enemyId = _nextId++;

  // Burrower mechanic
  bool _isBurrowed = false;
  double _burrowTimer = 0;
  double _burrowCooldown = 0;
  static const double _burrowDuration = 1.5;
  static const double _burrowCooldownTime = 5.0;
  static const int _burrowSkipCells = 4;
  bool get isBurrowed => _isBurrowed;
  double _surfaceFlashTimer = 0;
  static const double _surfaceFlashDuration = 0.35;

  // Last tower type that hit this enemy (for element kill effects)
  TowerType? lastHitTowerType;

  // Animation
  double _animTimer = 0;

  // Cached paints for render — single-threaded, safe to share
  static final Paint _fp = Paint();
  static final Paint _sp = Paint()..style = PaintingStyle.stroke;
  static final Paint _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  // Shared RNG — avoids constructing new Random() per hit
  static final math.Random _rng = math.Random();

  /// Debug flag: skip boss aura/shadow rendering (set from KaleGame debug flags)
  static bool debugSkipBossAura = false;

  // Pre-computed HP bar colors (21 stops, 0%→100% in 5% steps) — avoids Color.lerp per frame
  static final List<Color> _hpBarColors = List.generate(21, (i) {
    final ratio = i / 20.0;
    if (ratio > 0.5) {
      final t = (ratio - 0.5) * 2;
      return Color.fromARGB(255,
        (0xFF + (0x00 - 0xFF) * t).round().clamp(0, 255),
        (0xDD + (0xFF - 0xDD) * t).round().clamp(0, 255),
        (0x00 + (0x44 - 0x00) * t).round().clamp(0, 255));
    } else {
      final t = ratio * 2;
      return Color.fromARGB(255,
        (0xFF + (0xFF - 0xFF) * t).round().clamp(0, 255),
        (0x22 + (0xDD - 0x22) * t).round().clamp(0, 255),
        (0x00 + (0x00 - 0x00) * t).round().clamp(0, 255));
    }
  });

  // Cached ColorFilters to avoid per-frame list + ColorFilter allocation
  static final List<ColorFilter> _hitFlashFilters = List.generate(6, (i) {
    final v = (i / 5.0) * 200;
    return ColorFilter.matrix(<double>[
      1, 0, 0, 0, v, 0, 1, 0, 0, v, 0, 0, 1, 0, v, 0, 0, 0, 1, 0,
    ]);
  });
  static final List<ColorFilter> _deathTintFilters = List.generate(6, (i) {
    final t = i / 5.0;
    return ColorFilter.matrix(<double>[
      1, 0, 0, 0, t * 80, 0, 1, 0, 0, -t * 25, 0, 0, 1, 0, -t * 25, 0, 0, 0, 1, 0,
    ]);
  });

  // Spawn materialization
  double _spawnTimer;
  final double _spawnDuration;

  // Hit flash + stagger + scale pulse
  double _hitFlashTimer = 0;
  static const double _hitFlashDuration = 0.12;
  double _hitShakeX = 0;
  double _hitShakeY = 0;
  double _hitScaleTimer = 0;
  static const double _hitScaleDuration = 0.10;

  // Death visual (lingers after game logic removes enemy)
  bool _dyingVisual = false;
  double _deathVisualTimer = 0;
  double _deathVisualDuration = 0.4;

  Enemy({
    required this.type,
    required this.baseStats,
    required this.path,
    required this.cellSize,
  }) : _hp = baseStats.hp,
       _scaledMaxHp = baseStats.hp,
       _spawnDuration = baseStats.isBoss ? 0.4 : 0.25,
       _spawnTimer = baseStats.isBoss ? 0.4 : 0.25,
    super(
      size: Vector2.all(cellSize * 0.7),
      paint: Paint()..color = Colors.transparent, // Custom render
      anchor: Anchor.center,
    ) {
    if (path.isNotEmpty) {
      position = _gridToWorld(path[0]);
    }
  }

  int get hp => _hp;
  int get maxHp => _scaledMaxHp;
  bool get isDead => _isDead;
  bool get reachedCastle => _reachedCastle;
  int get goldReward => baseStats.goldReward * (isElite ? 2 : 1);
  int get castleDamage => baseStats.castleDamage;
  List<StatusEffect> get activeEffects => _effects;
  List<GridPos> get remainingPath => path.sublist(_pathIndex);
  /// Remaining path length without allocating a sublist.
  int get remainingPathLength => path.length - _pathIndex;

  double get currentSpeed {
    double speed = baseStats.speed;
    for (final e in _effects) {
      if (e.type == StatusType.slow) speed *= (1 - e.slowFactor);
    }
    // Allow full freeze (speed 0) when slowFactor is 1.0
    return speed.clamp(0.0, 10.0);
  }

  int _cachedArmor = -1; // -1 = needs recalculation
  int get currentArmor {
    if (_cachedArmor >= 0) return _cachedArmor;
    double armor = baseStats.armor.toDouble() + _bonusArmor;
    for (final e in _effects) {
      if (e.type == StatusType.curse) armor -= e.armorReduction;
    }
    _cachedArmor = armor.clamp(0, 999).round();
    return _cachedArmor;
  }

  bool get isWet => _effects.any((e) => e.type == StatusType.wet && !e.isExpired);
  bool get hasSlowEffect => _effects.any((e) => e.type == StatusType.slow && !e.isExpired);

  void takeDamage(int rawDamage, {bool bypassArmor = false}) {
    if (_isDead) return;
    final actual = bypassArmor ? rawDamage : GameConfig.calculateDamage(rawDamage, currentArmor);
    _hp -= actual;
    _hitFlashTimer = _hitFlashDuration;
    _hitScaleTimer = _hitScaleDuration;
    // Directional recoil: nudge backward along path + small random jitter
    double recoilX = (_rng.nextDouble() - 0.5) * 2.0;
    double recoilY = (_rng.nextDouble() - 0.5) * 1.5;
    if (_pathIndex < path.length - 1) {
      final next = path[math.min(_pathIndex + 1, path.length - 1)];
      final curr = path[_pathIndex];
      final dx = next.col - curr.col;
      final dy = next.row - curr.row;
      // Push opposite to movement direction
      recoilX -= dx * 2.5;
      recoilY -= dy * 2.0;
    }
    _hitShakeX = recoilX;
    _hitShakeY = recoilY;
    AudioSystem.instance.play(GameSound.enemyHit);
    if (_hp <= 0) {
      _hp = 0;
      _isDead = true;
    }
  }

  int _bonusArmor = 0;

  void heal(int amount) {
    if (_isDead) return;
    _hp = (_hp + amount).clamp(0, maxHp);
  }

  void addBonusArmor(int amount) {
    _bonusArmor += amount;
  }

  /// Scale HP by a multiplier (for wave-based difficulty scaling).
  void scaleHp(double multiplier) {
    _scaledMaxHp = (_scaledMaxHp * multiplier).round();
    _hp = _scaledMaxHp;
  }

  void applyEffect(StatusEffect effect) {
    _effects.removeWhere((e) => e.type == effect.type);
    _effects.add(effect);
    _cachedArmor = -1; // invalidate
  }

  /// Start visual death animation. Enemy is already removed from game logic.
  void startDeathAnim() {
    _dyingVisual = true;
    final isBoss = type == EnemyType.shadowLord || type == EnemyType.dragonEmperor;
    // Bosses linger longer; easy enemies are snappier
    _deathVisualDuration = isBoss ? 0.55 : (baseStats.difficulty == EnemyDifficulty.easy ? 0.3 : 0.4);
    _deathVisualTimer = _deathVisualDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Death visual phase: fade out then remove
    if (_dyingVisual) {
      _deathVisualTimer -= dt;
      _animTimer += dt;
      if (_deathVisualTimer <= 0) removeFromParent();
      return;
    }

    if (_isDead || _reachedCastle) return;

    _animTimer += dt;
    if (_spawnTimer > 0) _spawnTimer -= dt;
    if (telegraphTimer > 0) telegraphTimer -= dt;
    if (attackReleaseTimer > 0) attackReleaseTimer -= dt;
    if (_hitFlashTimer > 0) _hitFlashTimer -= dt;
    if (_hitScaleTimer > 0) _hitScaleTimer -= dt;
    if (_surfaceFlashTimer > 0) _surfaceFlashTimer -= dt;

    // Update status effects
    for (final effect in _effects) {
      final tickDamage = effect.update(dt);
      if (tickDamage > 0) takeDamage(tickDamage, bypassArmor: true);
    }
    final prevLen = _effects.length;
    _effects.removeWhere((e) => e.isExpired);
    if (_effects.length != prevLen) _cachedArmor = -1;

    // Burrower mechanic
    if (type == EnemyType.burrower) {
      _updateBurrower(dt);
    }

    // Move along path
    if (_pathIndex >= path.length - 1) {
      _reachedCastle = true;
      return;
    }

    final target = _gridToWorld(path[_pathIndex + 1]);
    final direction = target - position;
    final dist = direction.length;
    final moveSpeed = currentSpeed * cellSize * dt;

    if (dist <= moveSpeed) {
      position.setFrom(target);
      _pathIndex++;
    } else {
      direction.normalize();
      position += direction * moveSpeed;
    }
  }

  void _updateBurrower(double dt) {
    if (_isBurrowed) {
      _burrowTimer -= dt;
      if (_burrowTimer <= 0) {
        _isBurrowed = false;
        _surfaceFlashTimer = _surfaceFlashDuration;
        _burrowCooldown = _burrowCooldownTime;
        final newIndex = (_pathIndex + _burrowSkipCells).clamp(0, path.length - 1);
        _pathIndex = newIndex;
        position.setFrom(_gridToWorld(path[_pathIndex]));
      }
    } else {
      _burrowCooldown -= dt;
      if (_burrowCooldown <= 0 && _pathIndex < path.length - _burrowSkipCells) {
        _isBurrowed = true;
        _burrowTimer = _burrowDuration;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isDead && !_dyingVisual) return;
    if (_reachedCastle) return;

    // ─── Death animation: fade + shrink + spin ───
    if (_dyingVisual) {
      _renderDeathAnim(canvas);
      return;
    }

    // Burrowed state
    if (_isBurrowed) {
      _renderBurrowed(canvas);
      return;
    }

    // Spawn materialization: fade-in + scale-in + ground pulse + flash
    final bool isSpawning = _spawnTimer > 0;
    if (isSpawning) {
      final spawnT = (1.0 - _spawnTimer / _spawnDuration).clamp(0.0, 1.0);
      // Ground pulse (below everything)
      _renderSpawnGroundPulse(canvas, spawnT);
      // Scale-in transform (no saveLayer — use paint alpha instead for performance)
      final spawnScale = 0.6 + 0.4 * Curves.easeOut.transform(spawnT);
      canvas.save();
      canvas.translate(cellSize / 2, cellSize / 2);
      canvas.scale(spawnScale);
      canvas.translate(-cellSize / 2, -cellSize / 2);
    }

    // Healer aura (Issue #6)
    if (type == EnemyType.healer) {
      _renderHealerAura(canvas);
    }

    // Troll regen particles (Issue #7)
    if (type == EnemyType.troll) {
      _renderTrollRegen(canvas);
    }

    // Speed afterimage for fast enemies (behind sprite)
    if (baseStats.speed >= 1.3) {
      _renderSpeedTrail(canvas);
    }

    // Undead split orbs (behind sprite)
    if (baseStats.splitCount > 0) {
      _renderSplitOrbs(canvas);
    }

    // Footfall dust removed for performance

    // Boss ground shadow + danger aura (behind sprite, suppressed during spawn)
    if (baseStats.isBoss && !isSpawning && !debugSkipBossAura) {
      _renderBossGroundShadow(canvas);
      _renderBossAura(canvas);
    }

    final spriteSheet = EnemySpriteGenerator.instance.getWalkSheet(type);
    if (spriteSheet != null) {
      _renderWalkingSprite(canvas, spriteSheet);
    }

    // ShieldBearer shield arc (over sprite)
    if (type == EnemyType.shieldBearer) {
      _renderShieldArc(canvas);
    }

    // Burrower surface flash
    if (_surfaceFlashTimer > 0) {
      _renderSurfaceFlash(canvas);
    }

    // Elite glow overlay
    if (isElite) {
      _renderEliteGlow(canvas);
    }

    // Threat telegraph overlay
    if (telegraphTimer > 0) {
      _renderTelegraph(canvas);
    }

    // Boss attack release aftermath
    if (attackReleaseTimer > 0 && baseStats.isBoss) {
      _renderAttackRelease(canvas);
    }

    // Castle proximity warning
    if (!isSpawning && path.length > 5 && _pathIndex >= path.length - 3) {
      final proxPulse = (0.15 + 0.10 * math.sin(_animTimer * 4)).clamp(0.0, 1.0);
      _fp.color = Color.fromRGBO(255, 50, 50, proxPulse);
      canvas.drawCircle(Offset(cellSize / 2, cellSize * 0.7), cellSize * 0.2, _fp);
    }

    // Status effect visual overlays
    _renderStatusEffects(canvas);

    // HP bar
    _renderHpBar(canvas);

    // Close spawn scale transform
    if (isSpawning) {
      canvas.restore(); // scale transform

      // Spawn flash: brief bright tint at start of spawn
      final spawnT = (1.0 - _spawnTimer / _spawnDuration).clamp(0.0, 1.0);
      if (spawnT < 0.3) {
        final flashAlpha = ((1.0 - spawnT / 0.3) * 80).round().clamp(0, 255);
        _fp.color = Color.fromARGB(flashAlpha, 255, 255, 220);
        canvas.drawCircle(
          Offset(cellSize / 2, cellSize / 2),
          cellSize * 0.3,
          _fp,
        );
      }
    }
  }

  void _renderWalkingSprite(Canvas canvas, ui.Image spriteSheet) {
    final frameIndex = ((_animTimer * 4) % 4).floor();
    final frameSize = EnemySpriteGenerator.spriteSize.toDouble();
    final src = Rect.fromLTWH(frameIndex * frameSize, 0, frameSize, frameSize);

    final isBoss = type == EnemyType.shadowLord || type == EnemyType.dragonEmperor;
    final scale = isBoss ? 1.5 : 0.7;
    final drawSize = cellSize * scale;
    final offset = (cellSize - drawSize) / 2;

    // Weight-class locomotion: different bob/tilt/sway by enemy speed
    final double walkSpeed;    // bob frequency
    final double bobAmount;    // vertical bob amplitude
    final double tiltAmount;   // body tilt amplitude
    final double swayAmount;   // horizontal sway (heavy enemies only)
    if (isBoss) {
      // Boss: slow, heavy, deliberate
      walkSpeed = 4.0;
      bobAmount = 1.0;
      tiltAmount = 0.02;
      swayAmount = 0.8;
    } else if (baseStats.speed <= 0.7) {
      // Heavy: armoredGiant, troll, shieldBearer
      walkSpeed = 5.0;
      bobAmount = 1.8;
      tiltAmount = 0.03;
      swayAmount = 0.5;
    } else if (baseStats.speed >= 1.3) {
      // Light/fast: cavalry, goblin, darkKnight
      walkSpeed = 12.0;
      bobAmount = 1.0;
      tiltAmount = 0.06;
      swayAmount = 0.0;
    } else {
      // Medium: soldier, undead, healer, burrower
      walkSpeed = 8.0;
      bobAmount = 1.5;
      tiltAmount = 0.04;
      swayAmount = 0.0;
    }
    final walkPhase = _animTimer * walkSpeed;
    final bobY = math.sin(walkPhase) * bobAmount;
    final tilt = math.sin(walkPhase) * tiltAmount;
    final swayX = swayAmount > 0 ? math.sin(walkPhase * 0.5) * swayAmount : 0.0;

    final dst = Rect.fromLTWH(offset, offset - drawSize * 0.1 + bobY, drawSize, drawSize);

    canvas.save();
    // Heavy sway: lateral weight shift for heavy/boss enemies
    if (swayX != 0.0) {
      canvas.translate(swayX, 0);
    }
    // Hit stagger: offset decays with flash timer
    if (_hitFlashTimer > 0) {
      final shakeT = (_hitFlashTimer / _hitFlashDuration).clamp(0.0, 1.0);
      canvas.translate(_hitShakeX * shakeT, _hitShakeY * shakeT);
    }
    // Hit scale pulse: brief 1.05x pop that snaps back
    if (_hitScaleTimer > 0) {
      final scaleT = (_hitScaleTimer / _hitScaleDuration).clamp(0.0, 1.0);
      final hitScale = 1.0 + 0.05 * scaleT;
      final cx = cellSize / 2;
      final cy = cellSize / 2;
      canvas.translate(cx, cy);
      canvas.scale(hitScale, hitScale);
      canvas.translate(-cx, -cy);
    }
    bool movingLeft = false;
    if (_pathIndex < path.length - 1) {
      movingLeft = path[math.min(_pathIndex + 1, path.length - 1)].col < path[_pathIndex].col;
    }
    if (movingLeft) {
      canvas.translate(cellSize, 0);
      canvas.scale(-1, 1);
    }

    final centerX = offset + drawSize / 2;
    final centerY = offset - drawSize * 0.1 + bobY + drawSize / 2;
    canvas.translate(centerX, centerY);
    canvas.rotate(tilt);
    canvas.translate(-centerX, -centerY);

    _spritePaint.colorFilter = null;
    _spritePaint.color = const Color(0xFFFFFFFF);
    // Spawn fade-in: apply opacity via paint alpha (cheaper than saveLayer)
    if (_spawnTimer > 0) {
      final spawnAlpha = ((1.0 - _spawnTimer / _spawnDuration).clamp(0.0, 1.0) * 255).round();
      _spritePaint.color = Color.fromARGB(spawnAlpha, 255, 255, 255);
    }
    if (_hitFlashTimer > 0) {
      final flashT = (_hitFlashTimer / _hitFlashDuration).clamp(0.0, 1.0);
      _spritePaint.colorFilter = _hitFlashFilters[(flashT * 5).round().clamp(0, 5)];
    }
    canvas.drawImageRect(spriteSheet, src, dst, _spritePaint);
    canvas.restore();
  }

  // Cached paint for speed trail
  static final Paint _trailPaint = Paint()..strokeCap = StrokeCap.round;

  /// Subtle motion lines behind fast enemies.
  void _renderSpeedTrail(Canvas canvas) {
    final cx = cellSize / 2;
    final cy = cellSize / 2;
    final a = (0.15 + 0.1 * math.sin(_animTimer * 6)).clamp(0.0, 1.0);
    _trailPaint.color = Color.fromRGBO(255, 200, 100, a);
    _trailPaint.strokeWidth = 1.2;

    for (int i = 0; i < 3; i++) {
      final yOff = -6.0 + i * 6.0;
      final phase = _animTimer * 10 + i * 1.5;
      final xStart = cx + cellSize * 0.35 + math.sin(phase) * 2;
      canvas.drawLine(
        Offset(xStart, cy + yOff),
        Offset(xStart + 5 + math.sin(phase + 1) * 2, cy + yOff),
        _trailPaint,
      );
    }
  }

  /// Ghostly orbs orbiting undead enemies to signal split-on-death.
  void _renderSplitOrbs(Canvas canvas) {
    final cx = cellSize / 2;
    final cy = cellSize / 2;
    final count = baseStats.splitCount;
    for (int i = 0; i < count; i++) {
      final angle = _animTimer * 2.5 + i * math.pi * 2 / count;
      final orbX = cx + math.cos(angle) * cellSize * 0.4;
      final orbY = cy + math.sin(angle) * cellSize * 0.3;
      final a = ((0.5 + 0.3 * math.sin(_animTimer * 4 + i)) * 140).round().clamp(0, 255);
      _fp.color = Color.fromARGB(a, 180, 255, 200);
      canvas.drawCircle(Offset(orbX, orbY), 2.5, _fp);
    }
  }

  /// Steel-blue shield arc in front of shieldBearer.
  void _renderShieldArc(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final pulse = 0.5 + 0.2 * math.sin(_animTimer * 3);
    final a = (pulse * 255).round().clamp(0, 255);

    // Arc: left-front facing shield
    final arcRect = Rect.fromCenter(
      center: Offset(center.dx - cellSize * 0.05, center.dy),
      width: cellSize * 0.65,
      height: cellSize * 0.7,
    );
    // Draw from -60° to +60° (front-facing arc)
    _sp.color = Color.fromARGB(a, 140, 170, 220);
    _sp.strokeWidth = 2.5;
    _sp.strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 3, math.pi * 2 / 3, false, _sp);

    // Inner brighter arc
    _sp.color = Color.fromARGB((a * 0.5).round().clamp(0, 255), 200, 220, 255);
    _sp.strokeWidth = 1.2;
    canvas.drawArc(arcRect, -math.pi / 4, math.pi / 2, false, _sp);
  }

  /// Expanding dirt ring when burrower surfaces.
  void _renderSurfaceFlash(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final t = (1.0 - _surfaceFlashTimer / _surfaceFlashDuration).clamp(0.0, 1.0);
    final radius = cellSize * 0.3 + t * cellSize * 0.5;
    final a = ((1.0 - t) * 160).round().clamp(0, 255);

    // Dirt-colored expanding ring
    _sp.color = Color.fromARGB(a, 160, 120, 60);
    _sp.strokeWidth = 3.0 * (1.0 - t);
    _sp.strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, _sp);

    // Inner dust puff
    _fp.color = Color.fromARGB((a * 0.3).round().clamp(0, 255), 180, 150, 80);
    canvas.drawCircle(center, radius * 0.5, _fp);
  }

  /// Dark menacing aura for boss enemies.
  /// Ground pulse at spawn point — expanding ring that fades out.
  void _renderSpawnGroundPulse(Canvas canvas, double spawnT) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final ringRadius = cellSize * (0.15 + 0.45 * spawnT);
    final ringAlpha = ((1.0 - spawnT) * 140).round().clamp(0, 255);
    final isBoss = baseStats.isBoss;
    final ringColor = isBoss
        ? Color.fromARGB(ringAlpha, 200, 50, 50)
        : Color.fromARGB(ringAlpha, 200, 200, 180);
    _sp.color = ringColor;
    _sp.strokeWidth = (isBoss ? 2.5 : 1.5) * (1.0 - spawnT);
    _sp.strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, ringRadius, _sp);
    // Boss: second wider ring for heavier entry
    if (isBoss && spawnT > 0.2) {
      final outerT = ((spawnT - 0.2) / 0.8).clamp(0.0, 1.0);
      final outerRadius = cellSize * (0.3 + 0.6 * outerT);
      final outerAlpha = ((1.0 - outerT) * 80).round().clamp(0, 255);
      _sp.color = Color.fromARGB(outerAlpha, 200, 50, 50);
      _sp.strokeWidth = 1.5 * (1.0 - outerT);
      canvas.drawCircle(center, outerRadius, _sp);
    }
  }

  /// Subtle dust puffs tied to walk cycle — heavier enemies show more.
  void _renderFootfallDust(Canvas canvas) {
    final isBoss = baseStats.isBoss;
    final walkSpeed = isBoss ? 4.0
        : baseStats.speed <= 0.7 ? 5.0
        : baseStats.speed >= 1.3 ? 12.0
        : 8.0;
    final walkPhase = _animTimer * walkSpeed;
    // Two footfalls per walk cycle (each half-period)
    final halfPhase = (walkPhase % math.pi) / math.pi; // 0→1 within each step
    // Dust visible in first 40% of each step (foot contact)
    if (halfPhase > 0.4) return;
    final dustT = halfPhase / 0.4; // 0→1 over dust lifetime
    final feetY = cellSize * 0.75; // ground level
    final cx = cellSize / 2;

    if (isBoss) {
      // Boss: wider ground impact ring
      final ringR = cellSize * (0.2 + 0.25 * dustT);
      final a = ((1.0 - dustT) * 60).round().clamp(0, 255);
      _sp.color = Color.fromARGB(a, 160, 130, 80);
      _sp.strokeWidth = 1.5 * (1.0 - dustT);
      _sp.strokeCap = StrokeCap.butt;
      canvas.drawCircle(Offset(cx, feetY), ringR, _sp);
    } else if (baseStats.speed <= 0.7) {
      // Heavy: small dust puff
      final puffR = cellSize * (0.08 + 0.12 * dustT);
      final a = ((1.0 - dustT) * 40).round().clamp(0, 255);
      _fp.color = Color.fromARGB(a, 180, 150, 100);
      canvas.drawCircle(Offset(cx, feetY), puffR, _fp);
    }
    // Light/medium enemies: no dust (keeps screen clean during large waves)
  }

  void _renderBossGroundShadow(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize * 0.78);
    _fp.color = const Color.fromARGB(25, 0, 0, 0);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: cellSize * 1.1, height: cellSize * 0.22),
      _fp,
    );
  }

  void _renderBossAura(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final pulse = 0.3 + 0.15 * math.sin(_animTimer * 2.5);
    final a = (pulse * 100).round().clamp(0, 120);

    _sp.color = type == EnemyType.dragonEmperor
        ? Color.fromARGB(a, 0xCC, 0x33, 0x00)
        : Color.fromARGB(a, 0x66, 0x33, 0xAA);
    _sp.strokeWidth = 2.0;
    _sp.strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, cellSize * 0.6, _sp);

    // ShadowLord debuff aura: translucent red radius showing tower debuff zone
    if (type == EnemyType.shadowLord) {
      final debuffRadius = cellSize * 3;
      final debuffPulse = 0.06 + 0.03 * math.sin(_animTimer * 1.5);
      final debuffAlpha = (debuffPulse * 255).round().clamp(0, 40);
      // Filled translucent red zone
      _fp.color = Color.fromARGB(debuffAlpha, 255, 30, 30);
      canvas.drawCircle(center, debuffRadius, _fp);
      // Red border ring
      final ringAlpha = (debuffPulse * 400).round().clamp(0, 80);
      _sp.color = Color.fromARGB(ringAlpha, 255, 50, 50);
      _sp.strokeWidth = 1.5;
      canvas.drawCircle(center, debuffRadius, _sp);
    }
  }

  // ─── Issue #5: Death animation (enhanced) ──────────────────────────────────
  void _renderDeathAnim(Canvas canvas) {
    final t = (_deathVisualTimer / _deathVisualDuration).clamp(0.0, 1.0);
    final spriteSheet = EnemySpriteGenerator.instance.getWalkSheet(type);
    if (spriteSheet == null) return;

    final frameSize = EnemySpriteGenerator.spriteSize.toDouble();
    final src = Rect.fromLTWH(frameSize, 0, frameSize, frameSize);

    final isBoss = type == EnemyType.shadowLord || type == EnemyType.dragonEmperor;
    final baseScale = isBoss ? 1.5 : 0.7;
    final drawSize = cellSize * baseScale;

    // Scale pop: brief expand (first 12%), then collapse
    double scale;
    if (t > 0.88) {
      final popT = (1.0 - t) / 0.12; // 0→1 during pop
      scale = 1.0 + (isBoss ? 0.35 : 0.25) * popT; // snappier, bigger pop
    } else {
      final shrinkT = t / 0.88;
      scale = 0.15 + 1.1 * shrinkT; // collapses more (to 0.15)
    }

    final alpha = (t * 255).round().clamp(0, 255);
    final floatUp = (1.0 - t) * (isBoss ? -8.0 : -14.0);
    final spin = (1.0 - t) * (isBoss ? 0.2 : 0.4);

    final cx = cellSize / 2;
    final cy = cellSize / 2 + floatUp;

    // 1. Particle burst — dots flying outward (more for bosses/elites)
    final particleCount = isBoss ? 6 : isElite ? 4 : 3;
    final burstRadius = isBoss ? 0.45 : 0.35;
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * math.pi * 2 + 0.7;
      final progress = 1.0 - t;
      final dist = progress * cellSize * burstRadius;
      final px = cx + math.cos(angle) * dist;
      final py = cy + math.sin(angle) * dist;
      final pAlpha = (t * 150).round().clamp(0, 255);
      final pSize = (isBoss ? 1.8 : 1.2) * t + 0.4;
      _fp.color = Color.fromARGB(pAlpha, 255, 160, 40);
      canvas.drawCircle(Offset(px, py), pSize, _fp);
    }

    // 2. Sprite with red tint + scale pop
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(spin);
    canvas.scale(scale);
    canvas.translate(-drawSize / 2, -drawSize / 2);

    final dst = Rect.fromLTWH(0, 0, drawSize, drawSize);
    _spritePaint.color = Color.fromARGB(alpha, 255, 255, 255);
    _spritePaint.colorFilter = null;

    // Red tint increases as death progresses
    final redTint = (1.0 - t).clamp(0.0, 1.0);
    if (redTint > 0.15) {
      _spritePaint.colorFilter = _deathTintFilters[(redTint * 5).round().clamp(0, 5)];
    }

    canvas.drawImageRect(spriteSheet, src, dst, _spritePaint);
    canvas.restore();

    // 3. Bright warm flash at death start (stronger, snappier)
    if (t > 0.75) {
      final flashT = (t - 0.75) / 0.25;
      final flashAlpha = (flashT * (isBoss ? 110 : 140)).round().clamp(0, 255);
      final flashRadius = cellSize * (isBoss ? 0.35 : 0.3) * scale;
      _fp.color = Color.fromARGB(flashAlpha, 255, 240, 200);
      canvas.drawCircle(Offset(cx, cy), flashRadius, _fp);
      // Extra bright core for immediate death impact
      if (flashT > 0.5) {
        final coreAlpha = ((flashT - 0.5) * 2.0 * (isBoss ? 80 : 100)).round().clamp(0, 255);
        _fp.color = Color.fromARGB(coreAlpha, 255, 255, 255);
        canvas.drawCircle(Offset(cx, cy), flashRadius * 0.4, _fp);
      }
    }
  }

  // ─── Issue #6: Healer aura ─────────────────────────────────────────────────
  void _renderHealerAura(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final pulse = 0.3 + 0.2 * math.sin(_animTimer * 3);
    // Green healing aura circle
    _fp.color = Color.fromRGBO(0, 255, 80, pulse * 0.12);
    canvas.drawCircle(center, cellSize * 1.8, _fp);
    // Inner ring
    _sp.color = Color.fromRGBO(0, 255, 80, pulse * 0.25);
    _sp.strokeWidth = 1.0;
    _sp.strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, cellSize * 1.8, _sp);
    // Small + sign above
    final plusY = -cellSize * 0.15 + math.sin(_animTimer * 2) * 2;
    _fp.color = Color.fromRGBO(0, 255, 80, 0.8);
    _fp.strokeWidth = 1.5;
    canvas.drawLine(Offset(cellSize / 2, plusY - 3), Offset(cellSize / 2, plusY + 3), _fp);
    canvas.drawLine(Offset(cellSize / 2 - 3, plusY), Offset(cellSize / 2 + 3, plusY), _fp);
  }

  // ─── Issue #7: Troll regen visual ──────────────────────────────────────────
  void _renderTrollRegen(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    // Green regen particles floating up
    for (int i = 0; i < 3; i++) {
      final phase = _animTimer * 2 + i * 2.1;
      final yOff = -(phase % 1.0) * cellSize * 0.5;
      final xOff = math.sin(phase * 3 + i) * cellSize * 0.2;
      final alpha = ((1.0 - (phase % 1.0)) * 180).round().clamp(0, 255);
      _fp.color = Color.fromARGB(alpha, 0, 255, 100);
      canvas.drawCircle(
        center + Offset(xOff, yOff - cellSize * 0.1),
        1.5 + (phase % 1.0) * 0.5,
        _fp,
      );
    }
    // Subtle green glow
    final pulse = 0.1 + 0.06 * math.sin(_animTimer * 4);
    _fp.color = Color.fromRGBO(0, 255, 80, pulse);
    canvas.drawCircle(center, cellSize * 0.35, _fp);
  }

  void _renderBurrowed(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final r = size.x * 0.45;

    // Dirt mound with cracks
    _fp.color = const Color(0xBB886633);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.5), width: size.x * 0.75, height: size.y * 0.35),
      _fp,
    );
    _fp.color = const Color(0x66AA8844);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.4), width: size.x * 0.55, height: size.y * 0.18),
      _fp,
    );
    // Dirt particles flying up
    _fp.color = const Color(0x88775522);
    for (int i = 0; i < 3; i++) {
      final px = center.dx + math.sin(_animTimer * 4 + i * 2) * r * 0.4;
      final py = center.dy + r * 0.2 - math.sin(_animTimer * 5 + i) * r * 0.3;
      canvas.drawCircle(Offset(px, py), 1.5, _fp);
    }
  }

  void _renderEliteGlow(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final glowAlpha = (0.25 + 0.15 * math.sin(_animTimer * 4)).clamp(0.0, 1.0);
    Color glowColor;
    switch (eliteModifier) {
      case EliteModifier.fast: glowColor = const Color(0xFFFF8800); break;
      case EliteModifier.armored: glowColor = const Color(0xFF8899BB); break;
      case EliteModifier.regenerating: glowColor = const Color(0xFF00FF44); break;
      case EliteModifier.splitting: glowColor = const Color(0xFFFF44FF); break;
      case null: glowColor = const Color(0xFFFFAA00); break;
    }
    final gr = (glowColor.r * 255).round();
    final gg = (glowColor.g * 255).round();
    final gb = (glowColor.b * 255).round();
    _fp.color = Color.fromARGB((glowAlpha * 255).round(), gr, gg, gb);
    canvas.drawCircle(center, cellSize * 0.5, _fp);
    // Crown
    final crownPath = Path()
      ..moveTo(center.dx - 5, center.dy - cellSize * 0.5)
      ..lineTo(center.dx - 3, center.dy - cellSize * 0.5 - 4)
      ..lineTo(center.dx, center.dy - cellSize * 0.5 - 2)
      ..lineTo(center.dx + 3, center.dy - cellSize * 0.5 - 4)
      ..lineTo(center.dx + 5, center.dy - cellSize * 0.5)
      ..close();
    _fp.color = const Color(0xFFFFD700);
    canvas.drawPath(crownPath, _fp);

    // Modifier-specific icon below HP bar
    final iconY = -14.0;
    final iconX = cellSize / 2;
    _sp.color = glowColor;
    _sp.strokeWidth = 1.2;
    _sp.strokeCap = StrokeCap.butt;
    _fp.color = Color.fromARGB(120, gr, gg, gb);
    switch (eliteModifier) {
      case EliteModifier.fast:
        // Speed lines >>>
        for (int i = 0; i < 3; i++) {
          final x = iconX - 6 + i * 4.0;
          canvas.drawLine(Offset(x, iconY - 2), Offset(x + 2.5, iconY), _sp);
          canvas.drawLine(Offset(x + 2.5, iconY), Offset(x, iconY + 2), _sp);
        }
        break;
      case EliteModifier.armored:
        // Shield shape
        final shield = Path()
          ..moveTo(iconX, iconY - 4)
          ..lineTo(iconX + 4, iconY - 2)
          ..lineTo(iconX + 4, iconY + 1)
          ..quadraticBezierTo(iconX, iconY + 5, iconX, iconY + 5)
          ..quadraticBezierTo(iconX, iconY + 5, iconX - 4, iconY + 1)
          ..lineTo(iconX - 4, iconY - 2)
          ..close();
        canvas.drawPath(shield, _fp);
        canvas.drawPath(shield, _sp);
        break;
      case EliteModifier.regenerating:
        // + sign
        canvas.drawLine(Offset(iconX, iconY - 3), Offset(iconX, iconY + 3), _sp..strokeWidth = 1.8);
        canvas.drawLine(Offset(iconX - 3, iconY), Offset(iconX + 3, iconY), _sp..strokeWidth = 1.8);
        break;
      case EliteModifier.splitting:
        // Split icon: Y shape
        canvas.drawLine(Offset(iconX, iconY + 3), Offset(iconX, iconY), _sp);
        canvas.drawLine(Offset(iconX, iconY), Offset(iconX - 3, iconY - 3), _sp);
        canvas.drawLine(Offset(iconX, iconY), Offset(iconX + 3, iconY - 3), _sp);
        break;
      case null:
        break;
    }
  }

  /// Pulsing charge glow + rhythmic ring telegraph before a dangerous action.
  /// Boss telegraphs escalate over telegraphProgress and have per-type identity.
  void _renderTelegraph(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final isBoss = baseStats.isBoss;
    final radius = cellSize * (isBoss ? 0.75 : 0.45);

    // Extract RGB once to avoid repeated getter calls
    final tr = (telegraphColor.r * 255).round();
    final tg = (telegraphColor.g * 255).round();
    final tb = (telegraphColor.b * 255).round();

    final pulse = (0.5 + 0.5 * math.sin(_animTimer * 10)).clamp(0.0, 1.0);
    final ringAlpha = (pulse * 100).round().clamp(0, 255);
    _sp.color = Color.fromARGB(ringAlpha, tr, tg, tb);
    _sp.strokeWidth = isBoss ? 2.5 : 1.2;
    _sp.strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius * (0.6 + 0.4 * pulse), _sp);

    if (!isBoss) return;

    final p = telegraphProgress.clamp(0.0, 1.0);
    final coreAlpha = (pulse * 80 * (0.5 + p * 0.5)).round().clamp(0, 255);
    _fp.color = Color.fromARGB(coreAlpha, tr, tg, tb);
    canvas.drawCircle(center, radius * 0.3, _fp);
  }

  /// Short-lived aftermath visual after boss special attack fires.
  void _renderAttackRelease(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    final t = (1.0 - attackReleaseTimer / _attackReleaseDuration).clamp(0.0, 1.0);
    final fade = 1.0 - t; // 1→0
    final isDragon = type == EnemyType.dragonEmperor;

    if (isDragon) {
      // Dragon: explosive outward ring expanding + central heat flash
      final ringRadius = cellSize * (0.4 + 0.8 * t);
      final ringAlpha = (fade * 150).round().clamp(0, 255);
      _sp.color = Color.fromARGB(ringAlpha, 255, 100, 20);
      _sp.strokeWidth = 2.5 * fade;
      _sp.strokeCap = StrokeCap.butt;
      canvas.drawCircle(center, ringRadius, _sp);

      // Central heat flash (first 35% of duration)
      if (t < 0.35) {
        final flashFade = 1.0 - t / 0.35;
        final flashAlpha = (flashFade * 90).round().clamp(0, 255);
        _fp.color = Color.fromARGB(flashAlpha, 255, 180, 60);
        canvas.drawCircle(center, cellSize * 0.3 * (1.0 + t), _fp);
      }
    } else {
      // Shadow Lord: dark implosion then outward snap
      if (t < 0.3) {
        // Implosion phase: ring contracts inward
        final impT = t / 0.3;
        final ringRadius = cellSize * (0.7 - 0.5 * impT);
        final ringAlpha = (130 * (1.0 - impT * 0.3)).round().clamp(0, 255);
        _sp.color = Color.fromARGB(ringAlpha, 120, 0, 200);
        _sp.strokeWidth = 2.5;
        _sp.strokeCap = StrokeCap.butt;
        canvas.drawCircle(center, ringRadius, _sp);
        // Void core builds
        _fp.color = Color.fromARGB((100 * (0.5 + 0.5 * impT)).round(), 30, 0, 50);
        canvas.drawCircle(center, cellSize * 0.15 * (1.0 + impT), _fp);
      } else {
        // Outward snap: ring expands rapidly from center
        final snapT = (t - 0.3) / 0.7;
        final ringRadius = cellSize * (0.2 + 0.9 * snapT);
        final snapFade = 1.0 - snapT;
        final ringAlpha = (snapFade * 120).round().clamp(0, 255);
        _sp.color = Color.fromARGB(ringAlpha, 140, 0, 220);
        _sp.strokeWidth = 2.0 * snapFade;
        _sp.strokeCap = StrokeCap.butt;
        canvas.drawCircle(center, ringRadius, _sp);
      }
    }

    // Residual glow — faint lingering core (both types, last 60%)
    if (t > 0.4) {
      final residualT = (t - 0.4) / 0.6;
      final residualFade = 1.0 - residualT;
      final residualAlpha = (residualFade * 40).round().clamp(0, 255);
      final residualColor = isDragon
          ? Color.fromARGB(residualAlpha, 255, 120, 30)
          : Color.fromARGB(residualAlpha, 100, 0, 180);
      _fp.color = residualColor;
      canvas.drawCircle(center, cellSize * 0.25, _fp);
    }
  }

  void _renderStatusEffects(Canvas canvas) {
    final cx = cellSize / 2;
    final cy = cellSize / 2;
    final center = Offset(cx, cy - 10);
    for (final effect in _effects) {
      if (effect.isExpired) continue;
      final lifeRatio = (effect.remaining / effect.duration).clamp(0.0, 1.0);
      final fadeAlpha = lifeRatio < 0.2 ? lifeRatio / 0.2 : 1.0;
      final a = (fadeAlpha * 120).round().clamp(0, 255);

      switch (effect.type) {
        case StatusType.burn: _fp.color = Color.fromARGB(a, 255, 100, 20);
        case StatusType.poison: _fp.color = Color.fromARGB(a, 80, 255, 80);
        case StatusType.slow: _fp.color = Color.fromARGB(a, 135, 206, 235);
        case StatusType.wet: _fp.color = Color.fromARGB(a, 100, 150, 255);
        case StatusType.curse: _fp.color = Color.fromARGB(a, 160, 50, 200);
      }
      canvas.drawCircle(center, 2.5, _fp);
    }
  }

  void _renderHpBar(Canvas canvas) {
    final barWidth = size.x * 1.05;
    const barHeight = 4.0;
    const barY = -8.0;
    final hpRatio = _hp / maxHp;
    final barLeft = (size.x - barWidth) / 2;

    // Bar background
    final barBgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barLeft, barY, barWidth, barHeight),
      const Radius.circular(2),
    );
    _fp.color = const Color(0xBB000000);
    canvas.drawRRect(barBgRect, _fp);

    // HP fill — pre-computed color table (zero allocation per frame)
    if (hpRatio > 0) {
      _fp.color = _hpBarColors[(hpRatio * 20).round().clamp(0, 20)];
      _fp.shader = null;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barY, barWidth * hpRatio, barHeight),
          const Radius.circular(2),
        ),
        _fp,
      );
    }

    // Border
    _sp.color = const Color(0x66FFFFFF);
    _sp.strokeWidth = 0.6;
    canvas.drawRRect(barBgRect, _sp);

    // Status effect indicators
    double indicatorX = barLeft + 1;
    for (final effect in _effects) {
      if (effect.isExpired) continue;
      switch (effect.type) {
        case StatusType.burn: _fp.color = const Color(0xFFFF4500);
        case StatusType.poison: _fp.color = const Color(0xFF00FF00);
        case StatusType.slow: _fp.color = const Color(0xFF87CEEB);
        case StatusType.wet: _fp.color = const Color(0xFF4169E1);
        case StatusType.curse: _fp.color = const Color(0xFFAA00AA);
      }
      canvas.drawCircle(Offset(indicatorX + 2, barY - 3.5), 2.2, _fp);
      indicatorX += 5.5;
    }

    // Armor indicator
    if (currentArmor > 0) {
      final armorX = barLeft + barWidth - 9;
      _fp.color = const Color(0xBB7788AA);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(armorX, barY - 4.5, 9, 4.5), const Radius.circular(1.5)),
        _fp,
      );
    }
  }

  static Color _lighten(Color c, double amount) {
    return Color.fromARGB(c.alpha,
      (c.red + (255 - c.red) * amount).round().clamp(0, 255),
      (c.green + (255 - c.green) * amount).round().clamp(0, 255),
      (c.blue + (255 - c.blue) * amount).round().clamp(0, 255));
  }

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255));
  }

  Vector2 _gridToWorld(GridPos pos) => Vector2((pos.col + 0.5) * cellSize, (pos.row + 0.5) * cellSize);
}
