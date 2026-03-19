import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/meta/artifact_system.dart';

void main() {
  test('12 artifacts', () { expect(ArtifactData.all.length, 12); });
  test('rarity distribution 3-3-3-3', () {
    final counts = <ArtifactRarity, int>{};
    for (final a in ArtifactData.all) counts[a.rarity] = (counts[a.rarity] ?? 0) + 1;
    expect(counts[ArtifactRarity.common], 3);
    expect(counts[ArtifactRarity.rare], 3);
    expect(counts[ArtifactRarity.epic], 3);
    expect(counts[ArtifactRarity.legendary], 3);
  });
  test('rollChoices returns 3', () {
    final choices = ArtifactData.rollChoices(seed: 42);
    expect(choices.length, 3);
  });
  test('improved rarity gives more legendaries', () {
    int normal = 0, improved = 0;
    for (int i = 0; i < 1000; i++) {
      normal += ArtifactData.rollChoices(seed: i).where((a) => a.rarity == ArtifactRarity.legendary).length;
      improved += ArtifactData.rollChoices(seed: i, improved: true).where((a) => a.rarity == ArtifactRarity.legendary).length;
    }
    expect(improved, greaterThan(normal));
  });
}
