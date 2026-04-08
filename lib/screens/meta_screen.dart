import 'package:flutter/material.dart';
import '../meta/meta_tree.dart';

class MetaScreen extends StatefulWidget {
  final int stoneSpirit;
  final int totalRuns;
  final int totalMetaUnlocks;
  final Map<String, int> unlockedLevels; // tree id -> unlocked level (0-based)
  final void Function(String treeId, int nodeIndex) onUnlock;
  final VoidCallback onBack;

  const MetaScreen({
    super.key,
    required this.stoneSpirit,
    required this.totalRuns,
    this.totalMetaUnlocks = 0,
    required this.unlockedLevels,
    required this.onUnlock,
    required this.onBack,
  });

  @override
  State<MetaScreen> createState() => _MetaScreenState();
}

class _MetaScreenState extends State<MetaScreen> {
  String _selectedTreeId = 'savas';

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back, color: _cream),
        ),
        title: const Text('Meta Ağacı', style: TextStyle(color: _gold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.diamond, color: _gold, size: 16),
                const SizedBox(width: 4),
                Text('${widget.stoneSpirit}', style: const TextStyle(color: _cream)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _gold.withAlpha(15),
            child: Text(
              'Her koşuda kazandığın Ruh ile kalıcı güçlendirmeler aç. Bu bonuslar tüm gelecek koşularda geçerli olur.',
              style: TextStyle(color: _cream.withAlpha(180), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Tree tabs
                SizedBox(
                  width: 150,
                  child: ListView(
                    children: MetaTree.trees.map((tree) {
                      final isSelected = tree.id == _selectedTreeId;
                      final level = widget.unlockedLevels[tree.id] ?? 0;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: _gold.withAlpha(30),
                        leading: SizedBox(
                          width: 24,
                          height: 24,
                          child: Image.asset(
                            'assets/images/ui/meta_${tree.id}_1.webp',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(_treeIcon(tree.id), color: isSelected ? _gold : _cream.withAlpha(120), size: 20),
                          ),
                        ),
                        title: Text(
                          tree.name,
                          style: TextStyle(
                            color: isSelected ? _gold : _cream,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '$level / ${tree.nodes.length}',
                          style: TextStyle(color: _cream.withAlpha(80), fontSize: 10),
                        ),
                        onTap: () => setState(() => _selectedTreeId = tree.id),
                      );
                    }).toList(),
                  ),
                ),
                const VerticalDivider(color: _gold, width: 1),
                // Node list
                Expanded(child: _buildNodeList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _treeIcon(String treeId) {
    switch (treeId) {
      case 'savas': return Icons.shield;
      case 'kesif': return Icons.explore;
      case 'kale': return Icons.castle;
      case 'efsane': return Icons.auto_awesome;
      default: return Icons.star;
    }
  }

  Widget _nodeIcon(String treeId, int nodeIndex) {
    final path = 'assets/images/ui/meta_${treeId}_${nodeIndex + 1}.webp';
    return Image.asset(
      path,
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[800],
        ),
        alignment: Alignment.center,
        child: Text(
          '${nodeIndex + 1}',
          style: const TextStyle(color: _cream, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNodeList() {
    final tree = MetaTree.trees.firstWhere((t) => t.id == _selectedTreeId);
    final unlockedLevel = widget.unlockedLevels[_selectedTreeId] ?? 0;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tree.nodes.length + 1, // +1 for header
      itemBuilder: (context, index) {
        // Tree header with subtitle
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tree.name, style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(tree.subtitle, style: TextStyle(color: _cream.withAlpha(140), fontSize: 12)),
                if (tree.id == 'efsane')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Bu ağaçtaki yetenekler belirli sayıda koşu tamamlamayı gerektirir.',
                      style: TextStyle(color: Colors.orange.withAlpha(180), fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 8),
                Divider(color: _gold.withAlpha(40)),
              ],
            ),
          );
        }
        index -= 1; // adjust for header
        final node = tree.nodes[index];
        final isUnlocked = index < unlockedLevel;
        final isNext = index == unlockedLevel;
        final effectiveCost = MetaTree.effectiveCost(node.cost, widget.totalMetaUnlocks);
        final isDiscounted = effectiveCost < node.cost;
        final canUnlock = isNext && node.canUnlock(
          spirit: widget.stoneSpirit,
          currentLevel: unlockedLevel,
          totalRuns: widget.totalRuns,
        ) && widget.stoneSpirit >= effectiveCost;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked
                ? _gold.withAlpha(30)
                : isNext
                    ? _cream.withAlpha(10)
                    : Colors.transparent,
            border: Border.all(
              color: isUnlocked
                  ? _gold
                  : isNext
                      ? _cream.withAlpha(80)
                      : _cream.withAlpha(20),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Node icon
              ClipOval(
                child: ColorFiltered(
                  colorFilter: isUnlocked
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                      : const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      0.5, 0,
                        ]),
                  child: _nodeIcon(_selectedTreeId, index),
                ),
              ),
              const SizedBox(width: 12),
              // Node info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      style: TextStyle(
                        color: isUnlocked ? _gold : _cream,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      node.description,
                      style: TextStyle(color: _cream.withAlpha(150), fontSize: 12),
                    ),
                    if (!isUnlocked)
                      Row(
                        children: [
                          if (isDiscounted && isNext) ...[
                            Text(
                              '${node.cost}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$effectiveCost Ruh',
                              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('-%50', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ] else
                            Text(
                              '$effectiveCost Ruh',
                              style: TextStyle(color: canUnlock ? _gold : Colors.grey, fontSize: 11),
                            ),
                          if (node.runGate > 0)
                            Text(
                              ' | ${node.runGate} koşu gerekli',
                              style: TextStyle(color: canUnlock ? _gold : Colors.grey, fontSize: 11),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              // Unlock button
              if (isNext)
                ElevatedButton(
                  onPressed: canUnlock
                      ? () => widget.onUnlock(_selectedTreeId, index)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _darkBg,
                    disabledBackgroundColor: Colors.grey[800],
                  ),
                  child: const Text('AÇ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (isUnlocked)
                const Icon(Icons.check_circle, color: _gold, size: 24),
            ],
          ),
        );
      },
    );
  }
}
