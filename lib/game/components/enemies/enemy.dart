import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../data/enemy_data.dart';
import '../../data/game_config.dart';
import '../../systems/pathfinding.dart';
import '../rendering/enemy_sprites.dart';
import 'status_effect.dart';

class Enemy extends RectangleComponent {
  final EnemyType type;
  final EnemyStats baseStats;
  final List<GridPos> path;
  final double cellSize;

  int _hp;
  int _pathIndex = 0;
  bool _reachedCastle = false;
  bool _isDead = false;
  final List<StatusEffect> _effects = [];

  // Burrower mechanic
  bool _isBurrowed = false;
  double _burrowTimer = 0;
  double _burrowCooldown = 0;
  static const double _burrowDuration = 1.5;
  static const double _burrowCooldownTime = 5.0;
  static const int _burrowSkipCells = 4;
  bool get isBurrowed => _isBurrowed;

  // Animation
  double _animTimer = 0;

  Enemy({
    required this.type,
    required this.baseStats,
    required this.path,
    required this.cellSize,
  }) : _hp = baseStats.hp,
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
  int get maxHp => baseStats.hp;
  bool get isDead => _isDead;
  bool get reachedCastle => _reachedCastle;
  int get goldReward => baseStats.goldReward;
  int get castleDamage => baseStats.castleDamage;
  List<StatusEffect> get activeEffects => _effects;
  List<GridPos> get remainingPath => path.sublist(_pathIndex);

  double get currentSpeed {
    double speed = baseStats.speed;
    for (final e in _effects) {
      if (e.type == StatusType.slow) speed *= (1 - e.slowFactor);
    }
    return speed.clamp(0.1, 10.0);
  }

  int get currentArmor {
    double armor = baseStats.armor.toDouble() + _bonusArmor;
    for (final e in _effects) {
      if (e.type == StatusType.curse) armor -= e.armorReduction;
    }
    return armor.clamp(0, 999).round();
  }

  bool get isWet => _effects.any((e) => e.type == StatusType.wet && !e.isExpired);

  void takeDamage(int rawDamage, {bool bypassArmor = false}) {
    if (_isDead) return;
    final actual = bypassArmor ? rawDamage : GameConfig.calculateDamage(rawDamage, currentArmor);
    _hp -= actual;
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

  void applyEffect(StatusEffect effect) {
    _effects.removeWhere((e) => e.type == effect.type);
    _effects.add(effect);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDead || _reachedCastle) return;

    _animTimer += dt;

    // Update status effects
    for (final effect in _effects) {
      final tickDamage = effect.update(dt);
      if (tickDamage > 0) takeDamage(tickDamage, bypassArmor: true);
    }
    _effects.removeWhere((e) => e.isExpired);

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
    if (_isDead || _reachedCastle) return;

    // Burrowed state (keep existing Canvas code for dirt mound)
    if (_isBurrowed) {
      _renderBurrowed(canvas);
      return;
    }

    final spriteSheet = EnemySpriteGenerator.instance.getWalkSheet(type);
    if (spriteSheet != null) {
      // Walk frame selection (4 frames)
      final frameIndex = ((_animTimer * 4) % 4).floor();
      final frameSize = EnemySpriteGenerator.spriteSize.toDouble();
      final src = Rect.fromLTWH(frameIndex * frameSize, 0, frameSize, frameSize);

      // Boss enemies are larger
      final isBoss = type == EnemyType.shadowLord || type == EnemyType.dragonEmperor;
      final scale = isBoss ? 1.5 : 0.7;
      final drawSize = cellSize * scale;
      final offset = (cellSize - drawSize) / 2;
      final dst = Rect.fromLTWH(offset, offset - drawSize * 0.1, drawSize, drawSize);

      // Direction-based flip
      canvas.save();
      bool movingLeft = false;
      if (_pathIndex < path.length - 1) {
        movingLeft = path[math.min(_pathIndex + 1, path.length - 1)].col < path[_pathIndex].col;
      }
      if (movingLeft) {
        canvas.translate(cellSize, 0);
        canvas.scale(-1, 1);
      }

      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(spriteSheet, src, dst, paint);
      canvas.restore();
    }

    // Status effect visual overlays (Canvas - dynamic)
    _renderStatusEffects(canvas);

    // HP bar (Canvas - dynamic)
    _renderHpBar(canvas);
  }

  void _renderBurrowed(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final r = size.x * 0.45;

    // Dirt mound with cracks
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.5), width: size.x * 0.75, height: size.y * 0.35),
      Paint()..color = const Color(0xBB886633),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.4), width: size.x * 0.55, height: size.y * 0.18),
      Paint()..color = const Color(0x66AA8844),
    );
    // Dirt particles flying up
    for (int i = 0; i < 3; i++) {
      final px = center.dx + math.sin(_animTimer * 4 + i * 2) * r * 0.4;
      final py = center.dy + r * 0.2 - math.sin(_animTimer * 5 + i) * r * 0.3;
      canvas.drawCircle(Offset(px, py), 1.5, Paint()..color = const Color(0x88775522));
    }
  }

  void _renderStatusEffects(Canvas canvas) {
    final center = Offset(cellSize / 2, cellSize / 2);
    for (final effect in _effects) {
      if (effect.isExpired) continue;
      switch (effect.type) {
        case StatusType.burn:
          canvas.drawCircle(
            center + Offset(math.sin(_animTimer * 8) * 6, -8), 3,
            Paint()..color = const Color(0xCCFF4500)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
          break;
        case StatusType.poison:
          canvas.drawCircle(
            center + Offset(0, -10 - math.sin(_animTimer * 3) * 4), 5,
            Paint()..color = const Color(0x8800FF00)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
          break;
        case StatusType.slow:
          canvas.drawCircle(center, cellSize * 0.35,
            Paint()..color = const Color(0x4487CEEB)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
          break;
        case StatusType.wet:
          canvas.drawCircle(center + const Offset(4, -6), 2, Paint()..color = const Color(0xAA4169E1));
          canvas.drawCircle(center + const Offset(-5, -3), 1.5, Paint()..color = const Color(0xAA4169E1));
          break;
        case StatusType.curse:
          canvas.drawCircle(center, cellSize * 0.4,
            Paint()..color = const Color(0x33AA00AA)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          break;
      }
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
    canvas.drawRRect(barBgRect, Paint()..color = const Color(0xBB000000));

    // HP fill with vivid gradient
    if (hpRatio > 0) {
      final barColor = hpRatio > 0.5
          ? Color.lerp(const Color(0xFFFFDD00), const Color(0xFF00FF44), (hpRatio - 0.5) * 2)!
          : Color.lerp(const Color(0xFFFF2200), const Color(0xFFFFDD00), hpRatio * 2)!;
      final barGrad = ui.Gradient.linear(
        Offset(0, barY), Offset(0, barY + barHeight),
        [_lighten(barColor, 0.4), barColor, _darken(barColor, 0.15)],
        [0.0, 0.5, 1.0],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barY, barWidth * hpRatio, barHeight),
          const Radius.circular(2),
        ),
        Paint()..shader = barGrad,
      );
    }

    // Bright border around HP bar
    canvas.drawRRect(barBgRect, Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6,
    );

    // --- STATUS EFFECT INDICATORS ---
    double indicatorX = barLeft + 1;
    for (final effect in _effects) {
      if (effect.isExpired) continue;
      Color dotColor;
      switch (effect.type) {
        case StatusType.burn: dotColor = const Color(0xFFFF4500); break;
        case StatusType.poison: dotColor = const Color(0xFF00FF00); break;
        case StatusType.slow: dotColor = const Color(0xFF87CEEB); break;
        case StatusType.wet: dotColor = const Color(0xFF4169E1); break;
        case StatusType.curse: dotColor = const Color(0xFFAA00AA); break;
      }
      canvas.drawCircle(Offset(indicatorX + 2, barY - 3.5), 2.2, Paint()..color = dotColor);
      canvas.drawCircle(Offset(indicatorX + 2, barY - 3.5), 2.2, Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
      );
      indicatorX += 5.5;
    }

    // --- ARMOR INDICATOR ---
    if (currentArmor > 0) {
      final armorX = barLeft + barWidth - 9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(armorX, barY - 4.5, 9, 4.5), const Radius.circular(1.5)),
        Paint()..color = const Color(0xBB7788AA),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(armorX, barY - 4.5, 9, 4.5), const Radius.circular(1.5)),
        Paint()..color = const Color(0x44FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(text: '$currentArmor', style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 3)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(armorX + (9 - tp.width) / 2, barY - 4.5));
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
