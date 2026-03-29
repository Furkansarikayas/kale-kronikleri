import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kale_kronikleri/main.dart';

Finder findImageButton(String assetSubstring) {
  return find.byWidgetPredicate(
    (w) => w is Image && w.image is AssetImage &&
           (w.image as AssetImage).assetName.contains(assetSubstring),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tour', (t) async {
    await t.pumpWidget(const KaleKronikleriApp());
    await t.pump(const Duration(seconds: 4));
    debugPrint('READY:main_menu');

    // 1. Main Menu - long pause for adb screencap
    await t.pump(const Duration(seconds: 8));

    // 2. META AĞACI
    final metaBtn = findImageButton('btn_meta');
    if (metaBtn.evaluate().isNotEmpty) {
      await t.tap(metaBtn.first);
      await t.pump(const Duration(seconds: 2));
      debugPrint('READY:meta_savas');
      await t.pump(const Duration(seconds: 8));

      // Tap tabs by textContaining (names are "Keşif Ağacı" etc.)
      for (final tabName in ['Keşif', 'Kale', 'Efsane']) {
        final tab = find.textContaining(tabName);
        if (tab.evaluate().isNotEmpty) {
          await t.tap(tab.first);
          await t.pump(const Duration(seconds: 1));
          debugPrint('READY:meta_$tabName');
          await t.pump(const Duration(seconds: 6));
        } else {
          debugPrint('NOT_FOUND:$tabName');
        }
      }

      // Back to main menu
      final back = find.byIcon(Icons.arrow_back);
      if (back.evaluate().isNotEmpty) {
        await t.tap(back.first);
        await t.pump(const Duration(seconds: 2));
      }
    }

    // 3. OYNA -> Run Setup
    final oynaBtn = findImageButton('btn_oyna');
    if (oynaBtn.evaluate().isNotEmpty) {
      await t.tap(oynaBtn.first);
      await t.pump(const Duration(seconds: 2));
      debugPrint('READY:run_setup');
      await t.pump(const Duration(seconds: 8));

      // Find BAŞLA by image asset
      final baslaBtn = findImageButton('btn_basla');
      debugPrint('BASLA_IMG:${baslaBtn.evaluate().length}');
      if (baslaBtn.evaluate().isNotEmpty) {
        await t.tap(baslaBtn.first);
        // Wait for game to load (map generation, sprite loading)
        for (int i = 0; i < 15; i++) {
          await t.pump(const Duration(seconds: 1));
        }
        debugPrint('READY:game_view');
        await t.pump(const Duration(seconds: 10));
      }
    }

    debugPrint('TOUR_DONE');
  });
}
