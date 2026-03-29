import 'save_manager.dart';
import 'meta_tree.dart';

enum AchievementId {
  ilkZafer,
  sinerjiUstasi,
  kuleMimari,
  dusmanAvcisi,
  altinKoleksiyoncu,
  zorlukAvcisi,
  efsaneSavascisi,
  mukemmelSavunma,
  bossKatili,
  kaleUstasi,
}

class AchievementDef {
  final AchievementId id;
  final String name;
  final String description;
  final int target;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.target,
  });
}

class AchievementSystem {
  static const List<AchievementDef> definitions = [
    AchievementDef(
      id: AchievementId.ilkZafer,
      name: 'İlk Zafer',
      description: 'İlk koşuyu tamamla',
      target: 1,
    ),
    AchievementDef(
      id: AchievementId.sinerjiUstasi,
      name: 'Sinerji Ustası',
      description: '5 farklı sinerji keşfet',
      target: 5,
    ),
    AchievementDef(
      id: AchievementId.kuleMimari,
      name: 'Kule Mimarı',
      description: '50 kule yerleştir (toplam)',
      target: 50,
    ),
    AchievementDef(
      id: AchievementId.dusmanAvcisi,
      name: 'Düşman Avcısı',
      description: '500 düşman öldür (toplam)',
      target: 500,
    ),
    AchievementDef(
      id: AchievementId.altinKoleksiyoncu,
      name: 'Altın Koleksiyoncu',
      description: '1000 taş ruhu biriktir',
      target: 1000,
    ),
    AchievementDef(
      id: AchievementId.zorlukAvcisi,
      name: 'Zorluk Avcısı',
      description: 'Şövalye zorluğunu yen',
      target: 1,
    ),
    AchievementDef(
      id: AchievementId.efsaneSavascisi,
      name: 'Efsane Savaşçı',
      description: 'Efsane zorluğunu yen',
      target: 1,
    ),
    AchievementDef(
      id: AchievementId.mukemmelSavunma,
      name: 'Mükemmel Savunma',
      description: 'Hiç hasar almadan 5 dalga geç',
      target: 5,
    ),
    AchievementDef(
      id: AchievementId.bossKatili,
      name: 'Boss Katili',
      description: '10 boss öldür (toplam)',
      target: 10,
    ),
    AchievementDef(
      id: AchievementId.kaleUstasi,
      name: 'Kale Ustası',
      description: 'Tüm meta ağaç düğümlerini aç',
      target: 1,
    ),
  ];

  static AchievementDef getDef(AchievementId id) =>
      definitions.firstWhere((d) => d.id == id);

  /// Check all achievements and unlock any newly completed ones.
  /// Returns list of newly unlocked achievement IDs.
  static List<AchievementId> checkAll(SaveManager save) {
    final newlyUnlocked = <AchievementId>[];

    for (final def in definitions) {
      if (save.isAchievementUnlocked(def.id)) continue;

      final progress = getProgress(def.id, save);
      if (progress >= def.target) {
        save.unlockAchievement(def.id);
        newlyUnlocked.add(def.id);
      }
    }

    return newlyUnlocked;
  }

  /// Get current progress for an achievement.
  static int getProgress(AchievementId id, SaveManager save) {
    switch (id) {
      case AchievementId.ilkZafer:
        return save.totalRuns >= 1 ? 1 : 0;
      case AchievementId.sinerjiUstasi:
        return save.discoveredSynergies.length;
      case AchievementId.kuleMimari:
        return save.totalTowersPlaced;
      case AchievementId.dusmanAvcisi:
        return save.totalKills;
      case AchievementId.altinKoleksiyoncu:
        return save.totalSpiritEarned;
      case AchievementId.zorlukAvcisi:
        // bestDifficulty >= knight (index 1)
        return save.bestDifficulty >= 1 ? 1 : 0;
      case AchievementId.efsaneSavascisi:
        // bestDifficulty >= legend (index 4)
        return save.bestDifficulty >= 4 ? 1 : 0;
      case AchievementId.mukemmelSavunma:
        return save.bestPerfectWaves;
      case AchievementId.bossKatili:
        return save.totalBossKills;
      case AchievementId.kaleUstasi:
        return _allMetaNodesUnlocked(save) ? 1 : 0;
    }
  }

  static bool _allMetaNodesUnlocked(SaveManager save) {
    for (final tree in MetaTree.trees) {
      final level = save.getMetaLevel(tree.id);
      if (level < tree.nodes.length) return false;
    }
    return true;
  }
}
