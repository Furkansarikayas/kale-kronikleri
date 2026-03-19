import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kale_kronikleri/meta/save_manager.dart';

void main() {
  setUp(() { SharedPreferences.setMockInitialValues({}); });

  test('defaults', () async {
    final sm = await SaveManager.create();
    expect(sm.stoneSpirit, 0); expect(sm.totalRuns, 0); expect(sm.bestWave, 0);
    expect(sm.metaSavas, 0); expect(sm.metaKesif, 0); expect(sm.metaKale, 0); expect(sm.metaEfsane, 0);
  });

  test('save and load spirit', () async {
    final sm = await SaveManager.create();
    await sm.addStoneSpirit(100);
    expect(sm.stoneSpirit, 100);
    final sm2 = await SaveManager.create();
    expect(sm2.stoneSpirit, 100);
  });

  test('increment runs', () async {
    final sm = await SaveManager.create();
    await sm.incrementRuns(); await sm.incrementRuns();
    expect(sm.totalRuns, 2);
  });

  test('unlock meta node', () async {
    final sm = await SaveManager.create();
    await sm.addStoneSpirit(50);
    final success = await sm.unlockMetaNode('savas', cost: 15);
    expect(success, true); expect(sm.metaSavas, 1); expect(sm.stoneSpirit, 35);
  });

  test('cannot unlock without spirit', () async {
    final sm = await SaveManager.create();
    final success = await sm.unlockMetaNode('savas', cost: 15);
    expect(success, false); expect(sm.metaSavas, 0);
  });

  test('synergy discovery persists', () async {
    final sm = await SaveManager.create();
    await sm.discoverSynergy(1); await sm.discoverSynergy(3);
    expect(sm.discoveredSynergies, containsAll([1, 3]));
    final sm2 = await SaveManager.create();
    expect(sm2.discoveredSynergies, containsAll([1, 3]));
  });
}
