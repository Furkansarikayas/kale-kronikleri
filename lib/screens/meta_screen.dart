import 'package:flutter/material.dart';
import '../meta/meta_tree.dart';

class MetaScreen extends StatefulWidget {
  final int stoneSpirit;
  final int totalRuns;
  final Map<String, int> unlockedLevels; // tree id -> unlocked level (0-based)
  final void Function(String treeId, int nodeIndex) onUnlock;
  final VoidCallback onBack;

  const MetaScreen({
    super.key,
    required this.stoneSpirit,
    required this.totalRuns,
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
        title: const Text('Meta Agaci', style: TextStyle(color: _gold)),
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
      body: Row(
        children: [
          // Tree tabs
          SizedBox(
            width: 140,
            child: ListView(
              children: MetaTree.trees.map((tree) {
                final isSelected = tree.id == _selectedTreeId;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: _gold.withAlpha(30),
                  title: Text(
                    tree.name,
                    style: TextStyle(
                      color: isSelected ? _gold : _cream,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
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
    );
  }

  Widget _buildNodeList() {
    final tree = MetaTree.trees.firstWhere((t) => t.id == _selectedTreeId);
    final unlockedLevel = widget.unlockedLevels[_selectedTreeId] ?? 0;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tree.nodes.length,
      itemBuilder: (context, index) {
        final node = tree.nodes[index];
        final isUnlocked = index < unlockedLevel;
        final isNext = index == unlockedLevel;
        final canUnlock = isNext && node.canUnlock(
          spirit: widget.stoneSpirit,
          currentLevel: unlockedLevel,
          totalRuns: widget.totalRuns,
        );

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
              // Node number
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked ? _gold : Colors.grey[800],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isUnlocked ? _darkBg : _cream,
                    fontWeight: FontWeight.bold,
                  ),
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
                      Text(
                        '${node.cost} Ruh${node.runGate > 0 ? ' | ${node.runGate} kosu gerekli' : ''}',
                        style: TextStyle(
                          color: canUnlock ? _gold : Colors.grey,
                          fontSize: 11,
                        ),
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
                  child: const Text('AC', style: TextStyle(fontWeight: FontWeight.bold)),
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
