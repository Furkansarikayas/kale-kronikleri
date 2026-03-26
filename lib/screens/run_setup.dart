import 'package:flutter/material.dart';
import '../game/data/game_config.dart';
import '../game/systems/mutation_system.dart';
import '../meta/artifact_system.dart';

class RunSetup extends StatefulWidget {
  final List<ArtifactDef> artifactChoices;
  final int maxArtifacts;
  final DifficultyTier selectedDifficulty;
  final List<DifficultyTier> unlockedDifficulties;
  final List<MutationType> weeklyMutations;
  final void Function(DifficultyTier difficulty, List<ArtifactDef> selectedArtifacts) onStart;
  final VoidCallback onBack;

  const RunSetup({
    super.key,
    required this.artifactChoices,
    required this.maxArtifacts,
    required this.selectedDifficulty,
    required this.unlockedDifficulties,
    this.weeklyMutations = const [],
    required this.onStart,
    required this.onBack,
  });

  @override
  State<RunSetup> createState() => _RunSetupState();
}

class _RunSetupState extends State<RunSetup> {
  late DifficultyTier _difficulty;
  final Set<int> _selectedArtifactIds = {};

  static const _gold = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);

  @override
  void initState() {
    super.initState();
    _difficulty = widget.selectedDifficulty;
  }

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
        title: const Text('Kosu Hazirlik', style: TextStyle(color: _gold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left: Difficulty + Mutations
            Expanded(child: Column(
              children: [
                Expanded(child: _buildDifficultySection()),
                if (widget.weeklyMutations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildMutationSection(),
                ],
              ],
            )),
            const SizedBox(width: 16),
            // Right: Artifacts
            Expanded(flex: 2, child: _buildArtifactSection()),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            final selected = widget.artifactChoices
                .where((a) => _selectedArtifactIds.contains(a.id))
                .toList();
            widget.onStart(_difficulty, selected);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: _darkBg,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('BASLA', style: TextStyle(fontSize: 18, letterSpacing: 2)),
        ),
      ),
    );
  }

  Widget _buildDifficultySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zorluk', style: TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: widget.unlockedDifficulties.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _difficulty = d),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _difficulty == d ? _gold.withAlpha(40) : Colors.transparent,
                    border: Border.all(color: _difficulty == d ? _gold : _cream.withAlpha(40)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name.toUpperCase(),
                        style: TextStyle(
                          color: _difficulty == d ? _gold : _cream,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${d.totalWaves} dalga | HP x${d.hpMultiplier} | Ruh x${d.spiritMultiplier}',
                        style: TextStyle(color: _cream.withAlpha(150), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildArtifactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artifactler (${_selectedArtifactIds.length}/${widget.maxArtifacts})',
          style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: widget.artifactChoices.length,
            itemBuilder: (context, index) {
              final artifact = widget.artifactChoices[index];
              final isSelected = _selectedArtifactIds.contains(artifact.id);
              final canSelect = isSelected || _selectedArtifactIds.length < widget.maxArtifacts;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedArtifactIds.remove(artifact.id);
                    } else if (canSelect) {
                      _selectedArtifactIds.add(artifact.id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? _gold.withAlpha(40) : _darkBg,
                    border: Border.all(
                      color: isSelected ? _gold : _rarityColor(artifact.rarity),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        artifact.name,
                        style: TextStyle(
                          color: _rarityColor(artifact.rarity),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        artifact.description,
                        style: TextStyle(color: _cream.withAlpha(150), fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMutationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Haftalik Mutasyonlar', style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...widget.weeklyMutations.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(20),
              border: Border.all(color: Colors.red.withAlpha(80)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.displayName, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(m.description, style: TextStyle(color: _cream.withAlpha(150), fontSize: 10)),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Color _rarityColor(ArtifactRarity rarity) {
    switch (rarity) {
      case ArtifactRarity.common: return Colors.grey;
      case ArtifactRarity.rare: return Colors.blue;
      case ArtifactRarity.epic: return Colors.purple;
      case ArtifactRarity.legendary: return _gold;
    }
  }
}
