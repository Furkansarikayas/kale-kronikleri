import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../game/data/enemy_data.dart';
import '../game/data/tower_data.dart';
import '../game/data/wave_data.dart';
import '../game/systems/event_system.dart';
import 'widgets/glass_panel.dart';

class WaveBreak extends StatelessWidget {
  final int nextWave;
  final int totalWaves;
  final int gold;
  final double timeRemaining;
  final List<WaveEntry> wavePreview;
  final VoidCallback onStartNow;
  final VoidCallback? onWatchAd;
  final bool showEnemyWeakness;
  final String? loreMessage;
  final WaveEventDef? currentEvent;
  final bool merchantAvailable;
  final VoidCallback? onAcceptMerchant;
  final VoidCallback? onDismissEvent;
  final bool showEndlessPrompt;
  final VoidCallback? onContinueEndless;
  final VoidCallback? onDeclineEndless;
  final int pathCount;
  final WavePathPattern? nextWavePattern;

  const WaveBreak({
    super.key,
    required this.nextWave,
    required this.totalWaves,
    required this.gold,
    required this.timeRemaining,
    this.wavePreview = const [],
    required this.onStartNow,
    this.onWatchAd,
    this.showEnemyWeakness = false,
    this.loreMessage,
    this.currentEvent,
    this.merchantAvailable = false,
    this.onAcceptMerchant,
    this.onDismissEvent,
    this.showEndlessPrompt = false,
    this.onContinueEndless,
    this.onDeclineEndless,
    this.pathCount = 1,
    this.nextWavePattern,
  });

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Center(
        child: GlassPanel(
          padding: const EdgeInsets.all(24),
          borderColor: _gold,
          borderRadius: 12,
          blur: 12,
          child: SizedBox(
            width: 340,
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dalga $nextWave / $totalWaves',
              style: const TextStyle(
                color: _gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hazırlık Süresi',
              style: TextStyle(color: _cream.withAlpha(150), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '${timeRemaining.ceil()}s',
              style: const TextStyle(
                color: _cream,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on, color: _gold, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$gold Altın',
                  style: const TextStyle(color: _cream, fontSize: 14),
                ),
                if (pathCount > 1 && nextWavePattern != null) ...[
                  const SizedBox(width: 16),
                  Icon(_patternIcon(nextWavePattern!), color: _patternColor(nextWavePattern!), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _patternLabel(nextWavePattern!),
                    style: TextStyle(color: _patternColor(nextWavePattern!), fontSize: 12),
                  ),
                ],
              ],
            ),
            // Lore message for boss waves
            if (loreMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                loreMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD4A843),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            // Wave preview
            if (wavePreview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cream.withAlpha(10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _cream.withAlpha(30)),
                ),
                child: Column(
                  children: [
                    Text('Gelen Düşmanlar', style: TextStyle(color: _cream.withAlpha(150), fontSize: 10)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: wavePreview.map((entry) {
                        final stats = EnemyData.getStats(entry.type);
                        final weaknesses = showEnemyWeakness ? EnemyData.getWeaknesses(entry.type) : <TowerType>[];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16, height: 16,
                              child: Image.asset(
                                'assets/images/enemies/${entry.type.name}.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: _enemyColor(entry.type),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${stats.name} x${entry.count}',
                              style: TextStyle(color: _cream.withAlpha(200), fontSize: 10),
                            ),
                            if (weaknesses.isNotEmpty) ...[
                              const SizedBox(width: 3),
                              ...weaknesses.map((t) => Padding(
                                padding: const EdgeInsets.only(left: 1),
                                child: SizedBox(
                                  width: 12, height: 12,
                                  child: Image.asset(
                                    'assets/images/towers/${t.name}_t1.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(_towerIcon(t), color: const Color(0xFFFF6666), size: 9),
                                  ),
                                ),
                              )),
                            ],
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            // Wave event display
            if (currentEvent != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_eventColor(currentEvent!.type).withAlpha(30), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _eventColor(currentEvent!.type).withAlpha(100)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_eventIcon(currentEvent!.type), color: _eventColor(currentEvent!.type), size: 16),
                        const SizedBox(width: 6),
                        Text(currentEvent!.name, style: TextStyle(
                          color: _eventColor(currentEvent!.type), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(currentEvent!.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _cream.withAlpha(200), fontSize: 10)),
                    if (merchantAvailable && onAcceptMerchant != null) ...[
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: onAcceptMerchant,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4A843),
                          foregroundColor: _darkBg,
                          minimumSize: const Size(120, 30),
                        ),
                        child: const Text('Satın Al (50g)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // Endless mode prompt
            if (showEndlessPrompt) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_gold.withAlpha(30), Colors.transparent]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _gold.withAlpha(120)),
                ),
                child: Column(
                  children: [
                    const Text('ZAFER!', style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Sonsuz moda devam etmek ister misin?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _cream.withAlpha(200), fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: onContinueEndless,
                          style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: _darkBg),
                          child: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: onDeclineEndless,
                          style: OutlinedButton.styleFrom(foregroundColor: _cream, side: BorderSide(color: _cream.withAlpha(80))),
                          child: const Text('Bitir'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (!showEndlessPrompt) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onStartNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _darkBg,
                  minimumSize: const Size.fromHeight(40),
                ),
                child: const Text('ŞİMDİ BAŞLA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            if (onWatchAd != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onWatchAd,
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Reklam İzle (+50 Altın)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cream,
                  side: BorderSide(color: _cream.withAlpha(80)),
                  minimumSize: const Size.fromHeight(36),
                ),
              ),
            ],
          ],
        ),
          ),
        ),
      ),
    );
  }

  IconData _towerIcon(TowerType type) {
    switch (type) {
      case TowerType.arrow: return Icons.north_east;
      case TowerType.ice: return Icons.ac_unit;
      case TowerType.fire: return Icons.local_fire_department;
      case TowerType.lightning: return Icons.bolt;
      case TowerType.poison: return Icons.science;
      case TowerType.cannon: return Icons.adjust;
      case TowerType.spikeWall: return Icons.fence;
      case TowerType.support: return Icons.shield;
      case TowerType.water: return Icons.water_drop;
      case TowerType.wizard: return Icons.auto_fix_high;
      case TowerType.dark: return Icons.nightlight;
      case TowerType.holy: return Icons.wb_sunny;
    }
  }

  IconData _eventIcon(WaveEventType type) {
    switch (type) {
      case WaveEventType.merchant: return Icons.store;
      case WaveEventType.treasure: return Icons.card_giftcard;
      case WaveEventType.ambush: return Icons.warning;
      case WaveEventType.castleRepair: return Icons.build;
      case WaveEventType.curse: return Icons.flash_on;
    }
  }

  Color _eventColor(WaveEventType type) {
    switch (type) {
      case WaveEventType.merchant: return const Color(0xFFD4A843);
      case WaveEventType.treasure: return const Color(0xFFFFD700);
      case WaveEventType.ambush: return const Color(0xFFFF4444);
      case WaveEventType.castleRepair: return const Color(0xFF44CC44);
      case WaveEventType.curse: return const Color(0xFFAA00AA);
    }
  }

  Color _enemyColor(EnemyType type) {
    switch (type) {
      case EnemyType.soldier: return const Color(0xFFCC3333);
      case EnemyType.cavalry: return const Color(0xFFFF6600);
      case EnemyType.goblin: return const Color(0xFF33CC33);
      case EnemyType.armoredGiant: return const Color(0xFF999999);
      case EnemyType.undead: return const Color(0xFF666688);
      case EnemyType.shieldBearer: return const Color(0xFF4488CC);
      case EnemyType.healer: return const Color(0xFFFFFFFF);
      case EnemyType.burrower: return const Color(0xFF886633);
      case EnemyType.troll: return const Color(0xFF338833);
      case EnemyType.darkKnight: return const Color(0xFF330033);
      case EnemyType.shadowLord: return const Color(0xFF220022);
      case EnemyType.dragonEmperor: return const Color(0xFFFF0000);
    }
  }

  IconData _patternIcon(WavePathPattern pattern) {
    switch (pattern) {
      case WavePathPattern.spread: return Icons.call_split;
      case WavePathPattern.focused: return Icons.arrow_forward;
      case WavePathPattern.pincer: return Icons.compress;
    }
  }

  Color _patternColor(WavePathPattern pattern) {
    switch (pattern) {
      case WavePathPattern.spread: return const Color(0xFF88BBFF);
      case WavePathPattern.focused: return const Color(0xFFFF8844);
      case WavePathPattern.pincer: return const Color(0xFFFF4466);
    }
  }

  String _patternLabel(WavePathPattern pattern) {
    switch (pattern) {
      case WavePathPattern.spread: return 'Dağılım';
      case WavePathPattern.focused: return 'Tek Yol';
      case WavePathPattern.pincer: return 'Kıskaç';
    }
  }
}
