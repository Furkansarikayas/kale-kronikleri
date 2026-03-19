import 'package:flutter_test/flutter_test.dart';
import 'package:kale_kronikleri/meta/meta_tree.dart';

void main() {
  test('4 trees with 7 nodes each', () {
    expect(MetaTree.trees.length, 4);
    for (final tree in MetaTree.trees) expect(tree.nodes.length, 7);
  });
  test('savas first node costs 15', () {
    final savas = MetaTree.trees.firstWhere((t) => t.id == 'savas');
    expect(savas.nodes[0].cost, 15);
    expect(savas.nodes[0].name, 'Kule Hafızası');
  });
  test('efsane has run gates', () {
    final efsane = MetaTree.trees.firstWhere((t) => t.id == 'efsane');
    expect(efsane.nodes[0].runGate, 10);
    expect(efsane.nodes[6].runGate, 150);
  });
  test('canUnlock checks cost and run gate', () {
    final efsane = MetaTree.trees.firstWhere((t) => t.id == 'efsane');
    expect(efsane.nodes[0].canUnlock(spirit: 50, currentLevel: 0, totalRuns: 10), true);
    expect(efsane.nodes[0].canUnlock(spirit: 50, currentLevel: 0, totalRuns: 5), false);
    expect(efsane.nodes[0].canUnlock(spirit: 10, currentLevel: 0, totalRuns: 10), false);
  });
}
