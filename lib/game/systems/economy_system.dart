import '../data/game_config.dart';

class EconomySystem {
  int _gold = GameConfig.startingGold;
  int _stoneSpirit = 0;
  double difficultyMultiplier = 1.0;

  int get gold => _gold;
  int get stoneSpirit => _stoneSpirit;

  bool trySpend(int amount) {
    if (_gold >= amount) { _gold -= amount; return true; }
    return false;
  }

  void earnGold(int amount) { _gold += amount; }

  int sellValue(int totalSpent) => (totalSpent * GameConfig.sellRefundRatio).round();

  void earnStoneSpirit(int baseAmount) {
    _stoneSpirit += (baseAmount * difficultyMultiplier).round();
  }

  void onWaveComplete(int waveNumber) {
    earnStoneSpirit(waveNumber * 2);
    // Gold bonus for surviving the wave
    earnGold(15 + waveNumber * 5);
  }
}
