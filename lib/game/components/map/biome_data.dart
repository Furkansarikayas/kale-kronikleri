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

  // Dark fantasy + neon highlights color palette:

  static const BiomeData forest = BiomeData(
    type: BiomeType.forest,
    name: 'Orman',
    groundBase: Color(0xFF1a3a18),
    groundAccent: Color(0xFF2a5a25),
    pathBase: Color(0xFF3a3025),
    pathAccent: Color(0xFF4a4035),
    skyTop: Color(0xFF050510),
    skyBottom: Color(0xFF0f1a12),
    fogColor: Color(0x08AABBCC),
    ambientLight: Color(0xFF0a1a0a),
    decorationColors: [Color(0xFF2a5a25), Color(0xFF1a4a18), Color(0xFF3a6a30)],
  );

  static const BiomeData desert = BiomeData(
    type: BiomeType.desert,
    name: 'Çöl',
    groundBase: Color(0xFF4a3a20),
    groundAccent: Color(0xFF6a5a38),
    pathBase: Color(0xFF5a4a30),
    pathAccent: Color(0xFF7a6a48),
    skyTop: Color(0xFF0a0510),
    skyBottom: Color(0xFF1a1008),
    fogColor: Color(0x08DDBB88),
    ambientLight: Color(0xFF1a1008),
    decorationColors: [Color(0xFF6a5a38), Color(0xFF8a7a58), Color(0xFF4a3a20)],
  );

  static const BiomeData snow = BiomeData(
    type: BiomeType.snow,
    name: 'Kar',
    groundBase: Color(0xFF2a3a4a),
    groundAccent: Color(0xFF4a5a6a),
    pathBase: Color(0xFF3a3a4a),
    pathAccent: Color(0xFF5a5a6a),
    skyTop: Color(0xFF050510),
    skyBottom: Color(0xFF101828),
    fogColor: Color(0x10CCDDEE),
    ambientLight: Color(0xFF0a1020),
    decorationColors: [Color(0xFF5a6a7a), Color(0xFF7a8a9a), Color(0xFFaabbcc)],
  );

  static const BiomeData volcano = BiomeData(
    type: BiomeType.volcano,
    name: 'Volkan',
    groundBase: Color(0xFF2a1a15),
    groundAccent: Color(0xFF3a2a20),
    pathBase: Color(0xFF3a2520),
    pathAccent: Color(0xFF4a3530),
    skyTop: Color(0xFF100505),
    skyBottom: Color(0xFF1a0a08),
    fogColor: Color(0x10FF4400),
    ambientLight: Color(0xFF1a0808),
    decorationColors: [Color(0xFF5a2a20), Color(0xFFaa4420), Color(0xFF882200)],
  );

  static const BiomeData dark = BiomeData(
    type: BiomeType.dark,
    name: 'Karanlık Diyar',
    groundBase: Color(0xFF15101a),
    groundAccent: Color(0xFF201828),
    pathBase: Color(0xFF201520),
    pathAccent: Color(0xFF302530),
    skyTop: Color(0xFF030308),
    skyBottom: Color(0xFF0a0512),
    fogColor: Color(0x108800FF),
    ambientLight: Color(0xFF080510),
    decorationColors: [Color(0xFF301a40), Color(0xFF5020a0), Color(0xFF8040c0)],
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
