import 'dart:ui';

enum BiomeType { forest, desert, snow, volcano, dark }

class BiomeData {
  final BiomeType type;
  final String name;
  final Color groundBase;
  final Color groundAccent;
  final Color pathBase;
  final Color pathAccent;
  final Color skyTop;
  final Color skyBottom;
  final Color fogColor;
  final Color ambientLight;
  final List<Color> decorationColors;

  const BiomeData({
    required this.type,
    required this.name,
    required this.groundBase,
    required this.groundAccent,
    required this.pathBase,
    required this.pathAccent,
    required this.skyTop,
    required this.skyBottom,
    required this.fogColor,
    required this.ambientLight,
    required this.decorationColors,
  });

  // Vibrant, modern color palette with rich tones:

  static const BiomeData forest = BiomeData(
    type: BiomeType.forest,
    name: 'Orman',
    groundBase: Color(0xFF3B7A35),
    groundAccent: Color(0xFF5AA050),
    pathBase: Color(0xFF8B7350),
    pathAccent: Color(0xFFAA9068),
    skyTop: Color(0xFF0B1628),
    skyBottom: Color(0xFF1A3045),
    fogColor: Color(0x10AADDBB),
    ambientLight: Color(0xFF2A4A2A),
    decorationColors: [Color(0xFF4A8A40), Color(0xFF2A6A25), Color(0xFF6AAA55)],
  );

  static const BiomeData desert = BiomeData(
    type: BiomeType.desert,
    name: 'Çöl',
    groundBase: Color(0xFFC4A060),
    groundAccent: Color(0xFFDDBB78),
    pathBase: Color(0xFF9A8058),
    pathAccent: Color(0xFFBB9A70),
    skyTop: Color(0xFF1A1030),
    skyBottom: Color(0xFF3A2838),
    fogColor: Color(0x10DDBB88),
    ambientLight: Color(0xFF3A2A18),
    decorationColors: [Color(0xFFBB9A60), Color(0xFFDDBB80), Color(0xFF8A7048)],
  );

  static const BiomeData snow = BiomeData(
    type: BiomeType.snow,
    name: 'Kar',
    groundBase: Color(0xFF8AAABB),
    groundAccent: Color(0xFFAAC8DD),
    pathBase: Color(0xFF7A8A9A),
    pathAccent: Color(0xFF9AAABB),
    skyTop: Color(0xFF0A1828),
    skyBottom: Color(0xFF1A3050),
    fogColor: Color(0x18CCDDEE),
    ambientLight: Color(0xFF2A3A50),
    decorationColors: [Color(0xFF8AAABB), Color(0xFFAAC8DD), Color(0xFFCCDDEE)],
  );

  static const BiomeData volcano = BiomeData(
    type: BiomeType.volcano,
    name: 'Volkan',
    groundBase: Color(0xFF5A3A30),
    groundAccent: Color(0xFF7A5040),
    pathBase: Color(0xFF6A4A3A),
    pathAccent: Color(0xFF8A6A55),
    skyTop: Color(0xFF200808),
    skyBottom: Color(0xFF3A1510),
    fogColor: Color(0x18FF4400),
    ambientLight: Color(0xFF3A1818),
    decorationColors: [Color(0xFF8A4A35), Color(0xFFCC6630), Color(0xFFAA4420)],
  );

  static const BiomeData dark = BiomeData(
    type: BiomeType.dark,
    name: 'Karanlık Diyar',
    groundBase: Color(0xFF302040),
    groundAccent: Color(0xFF483058),
    pathBase: Color(0xFF3A2A40),
    pathAccent: Color(0xFF5A4060),
    skyTop: Color(0xFF080515),
    skyBottom: Color(0xFF150A25),
    fogColor: Color(0x188800FF),
    ambientLight: Color(0xFF180A25),
    decorationColors: [Color(0xFF5A3080), Color(0xFF7040BB), Color(0xFF9060DD)],
  );

  static BiomeData fromDifficulty(String difficultyName) {
    switch (difficultyName) {
      case 'apprentice':
        return forest;
      case 'knight':
        return desert;
      case 'lord':
        return snow;
      case 'king':
        return volcano;
      case 'legend':
        return dark;
      default:
        return forest;
    }
  }
}
