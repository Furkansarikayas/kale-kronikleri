import 'game_config.dart';
import 'tower_data.dart';

enum EnemyType {
  soldier, cavalry, goblin,
  armoredGiant, undead, shieldBearer, healer,
  burrower, troll, darkKnight,
  shadowLord, dragonEmperor,
}

enum EnemyDifficulty { easy, medium, hard, boss }

class EnemyStats {
  final EnemyType type;
  final String name;
  final int hp;
  final int armor;
  final double speed;
  final int goldReward;
  final int castleDamage;
  final EnemyDifficulty difficulty;
  final bool isBoss;
  final int splitCount;
  final int splitHp;

  const EnemyStats({
    required this.type, required this.name, required this.hp,
    required this.armor, required this.speed, required this.goldReward,
    required this.castleDamage, required this.difficulty,
    this.isBoss = false, this.splitCount = 0, this.splitHp = 0,
  });

  EnemyStats withDifficulty(DifficultyTier tier) {
    return EnemyStats(
      type: type, name: name,
      hp: (hp * tier.hpMultiplier).round(),
      armor: armor, speed: speed * tier.speedMultiplier,
      goldReward: goldReward, castleDamage: castleDamage,
      difficulty: difficulty, isBoss: isBoss,
      splitCount: splitCount, splitHp: (splitHp * tier.hpMultiplier).round(),
    );
  }
}

class EnemyData {
  EnemyData._();
  static const Map<EnemyType, EnemyStats> _stats = {
    EnemyType.soldier: EnemyStats(type: EnemyType.soldier, name: 'Sıradan Asker', hp: 30, armor: 0, speed: 1.0, goldReward: 5, castleDamage: 1, difficulty: EnemyDifficulty.easy),
    EnemyType.cavalry: EnemyStats(type: EnemyType.cavalry, name: 'Hızlı Süvari', hp: 20, armor: 0, speed: 2.0, goldReward: 6, castleDamage: 1, difficulty: EnemyDifficulty.easy),
    EnemyType.goblin: EnemyStats(type: EnemyType.goblin, name: 'Goblin Hırsız', hp: 25, armor: 0, speed: 1.3, goldReward: 8, castleDamage: 1, difficulty: EnemyDifficulty.easy),
    EnemyType.armoredGiant: EnemyStats(type: EnemyType.armoredGiant, name: 'Zırhlı Dev', hp: 120, armor: 15, speed: 0.5, goldReward: 12, castleDamage: 2, difficulty: EnemyDifficulty.medium),
    EnemyType.undead: EnemyStats(type: EnemyType.undead, name: 'Canlanır Ölü', hp: 60, armor: 0, speed: 0.8, goldReward: 10, castleDamage: 2, difficulty: EnemyDifficulty.medium, splitCount: 3, splitHp: 15),
    EnemyType.shieldBearer: EnemyStats(type: EnemyType.shieldBearer, name: 'Kalkan Taşıyıcı', hp: 50, armor: 25, speed: 0.7, goldReward: 10, castleDamage: 2, difficulty: EnemyDifficulty.medium),
    EnemyType.healer: EnemyStats(type: EnemyType.healer, name: 'Şifacı', hp: 40, armor: 0, speed: 0.9, goldReward: 12, castleDamage: 2, difficulty: EnemyDifficulty.medium),
    EnemyType.burrower: EnemyStats(type: EnemyType.burrower, name: 'Yeraltı Solucanı', hp: 70, armor: 10, speed: 1.0, goldReward: 15, castleDamage: 3, difficulty: EnemyDifficulty.hard),
    EnemyType.troll: EnemyStats(type: EnemyType.troll, name: 'Trol', hp: 150, armor: 5, speed: 0.6, goldReward: 18, castleDamage: 3, difficulty: EnemyDifficulty.hard),
    EnemyType.darkKnight: EnemyStats(type: EnemyType.darkKnight, name: 'Karanlık Şövalye', hp: 100, armor: 20, speed: 1.2, goldReward: 20, castleDamage: 3, difficulty: EnemyDifficulty.hard),
    EnemyType.shadowLord: EnemyStats(type: EnemyType.shadowLord, name: 'Gölge Lord', hp: 500, armor: 10, speed: 0.4, goldReward: 50, castleDamage: 5, difficulty: EnemyDifficulty.boss, isBoss: true),
    EnemyType.dragonEmperor: EnemyStats(type: EnemyType.dragonEmperor, name: 'Ejderha İmparatoru', hp: 800, armor: 0, speed: 0.3, goldReward: 100, castleDamage: 5, difficulty: EnemyDifficulty.boss, isBoss: true),
  };
  static EnemyStats getStats(EnemyType type) => _stats[type]!;

  /// Tower types that deal bonus damage or are especially effective against this enemy.
  static List<TowerType> getWeaknesses(EnemyType type) {
    switch (type) {
      case EnemyType.soldier: return []; // basic, no special weakness
      case EnemyType.cavalry: return [TowerType.ice, TowerType.spikeWall]; // slow stops speed
      case EnemyType.goblin: return [TowerType.fire, TowerType.cannon]; // low HP, AoE
      case EnemyType.armoredGiant: return [TowerType.dark, TowerType.poison]; // armor reduction
      case EnemyType.undead: return [TowerType.holy, TowerType.fire]; // holy purge, fire burn
      case EnemyType.shieldBearer: return [TowerType.dark, TowerType.lightning]; // bypass shield
      case EnemyType.healer: return [TowerType.poison, TowerType.arrow]; // fast kill before heal
      case EnemyType.burrower: return [TowerType.lightning, TowerType.cannon]; // AoE hits underground
      case EnemyType.troll: return [TowerType.fire, TowerType.poison]; // prevents regen
      case EnemyType.darkKnight: return [TowerType.holy, TowerType.ice]; // holy counter
      case EnemyType.shadowLord: return [TowerType.holy, TowerType.lightning]; // boss weakness
      case EnemyType.dragonEmperor: return [TowerType.ice, TowerType.dark]; // ice counter fire boss
    }
  }
}
