import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/game/systems/economy_system.dart';
import 'package:kale_kronikleri/game/data/game_config.dart';

void main() {
  late EconomySystem eco;
  setUp(() { eco = EconomySystem(); });

  test('starts with correct gold', () { expect(eco.gold, GameConfig.startingGold); });
  test('can spend gold', () { expect(eco.trySpend(50), true); expect(eco.gold, GameConfig.startingGold - 50); });
  test('cannot overspend', () { expect(eco.trySpend(9999), false); expect(eco.gold, GameConfig.startingGold); });
  test('earn gold', () { eco.earnGold(30); expect(eco.gold, GameConfig.startingGold + 30); });
  test('sell value 65%', () { expect(eco.sellValue(100), 65); });
  test('stone spirit', () { eco.earnStoneSpirit(25); expect(eco.stoneSpirit, 25); });
  test('wave completion gives spirit and gold', () {
    eco.onWaveComplete(5);
    expect(eco.stoneSpirit, 10);
    expect(eco.gold, GameConfig.startingGold + 15 + 5 * 5); // base gold + wave bonus
  });
  test('difficulty multiplier', () { eco.difficultyMultiplier = 2.5; eco.earnStoneSpirit(10); expect(eco.stoneSpirit, 25); });
}
