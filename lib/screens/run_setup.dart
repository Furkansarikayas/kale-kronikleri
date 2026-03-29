import 'dart:ui' as ui;
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

  static const _gold = Color(0xFFD4A843);
  static const _goldDark = Color(0xFFBA7517);
  static const _cream = Color(0xFFF5EDD8);
  static const _darkBg = Color(0xFF1A150E);


  @override
  void initState() {
    super.initState();
    _difficulty = widget.selectedDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/images/ui/menu_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Container(color: const Color(0xCC000000)),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Difficulty + Mutations (combined)
                        Expanded(
                          flex: 2,
                          child: _buildPanelFrame(
                            'assets/images/ui/panel_left.png',
                            _buildLeftContent(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right: Artifacts
                        Expanded(
                          flex: 3,
                          child: _buildPanelFrame(
                            'assets/images/ui/panel_right.png',
                            _buildArtifactContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildStartButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          // Themed back button
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_gold.withAlpha(25), _goldDark.withAlpha(10)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withAlpha(70)),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, color: _gold, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'GERİ',
                    style: TextStyle(
                      color: _gold.withAlpha(180),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Decorative dash
          Container(width: 24, height: 1, color: _gold.withAlpha(50)),
          const SizedBox(width: 8),
          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFBA7517), Color(0xFFE8C878), Color(0xFFD4A843), Color(0xFFE8C878), Color(0xFFBA7517)],
            ).createShader(bounds),
            child: const Text(
              'KOŞU HAZIRLIK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                shadows: [Shadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 24, height: 1, color: _gold.withAlpha(50)),
          const Spacer(),
          // Decorative shield
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withAlpha(40)),
            ),
            child: Icon(Icons.shield_outlined, color: _gold.withAlpha(80), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelFrame(String asset, Widget content) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: const Color(0xAA0D0D15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withAlpha(60)),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 38, 30, 30),
            child: content,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_gold, Color(0xFFE8C878), _gold],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          shadows: [Shadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
      ),
    );
  }

  // ──────────────── LEFT PANEL ────────────────

  Widget _buildLeftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('ZORLUK'),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ...widget.unlockedDifficulties.map(_buildDifficultyCard),
              // Mutations inside the same panel
              if (widget.weeklyMutations.isNotEmpty) ...[
                const SizedBox(height: 10),
                _mutationDivider(),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.redAccent, Color(0xFFFF6666), Colors.redAccent],
                  ).createShader(bounds),
                  child: const Text(
                    'MUTASYONLAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2))],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ...widget.weeklyMutations.map(_buildMutationCard),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _mutationDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.red.withAlpha(40))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent.withAlpha(120), size: 12),
        ),
        Expanded(child: Container(height: 1, color: Colors.red.withAlpha(40))),
      ],
    );
  }

  Widget _buildDifficultyCard(DifficultyTier d) {
    final isSelected = _difficulty == d;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() => _difficulty = d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [_gold.withAlpha(50), _goldDark.withAlpha(25)])
                : null,
            color: isSelected ? null : _cream.withAlpha(8),
            border: Border.all(
              color: isSelected ? _gold : _cream.withAlpha(30),
              width: isSelected ? 1.5 : 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: _gold.withAlpha(20), blurRadius: 8)]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? _gold : _cream.withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.displayName.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? _gold : _cream,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.5,
                        shadows: [Shadow(color: Colors.black.withAlpha(180), blurRadius: 3, offset: const Offset(0, 1))],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${d.totalWaves} dalga | HP x${d.hpMultiplier} | Ruh x${d.spiritMultiplier}',
                      style: TextStyle(
                        color: _cream.withAlpha(160),
                        fontSize: 9,
                        shadows: [Shadow(color: Colors.black.withAlpha(150), blurRadius: 2)],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: _gold, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMutationCard(MutationType m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.red.withAlpha(20), Colors.red.withAlpha(5)]),
          border: Border.all(color: Colors.red.withAlpha(40)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(150),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.displayName,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black.withAlpha(180), blurRadius: 3, offset: const Offset(0, 1))],
                    ),
                  ),
                  Text(
                    m.description,
                    style: TextStyle(
                      color: _cream.withAlpha(160),
                      fontSize: 9,
                      shadows: [Shadow(color: Colors.black.withAlpha(150), blurRadius: 2)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── RIGHT PANEL ────────────────

  Widget _buildArtifactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle('ARTIFACTLER'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_gold.withAlpha(40), _goldDark.withAlpha(20)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withAlpha(100)),
              ),
              child: Text(
                '${_selectedArtifactIds.length} / ${widget.maxArtifacts}',
                style: TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black.withAlpha(150), blurRadius: 2)],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: widget.artifactChoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) => _buildArtifactCard(widget.artifactChoices[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildArtifactCard(ArtifactDef artifact) {
    final isSelected = _selectedArtifactIds.contains(artifact.id);
    final canSelect = isSelected || _selectedArtifactIds.length < widget.maxArtifacts;
    final rColor = _rarityColor(artifact.rarity);

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [rColor.withAlpha(40), rColor.withAlpha(12)],
                )
              : null,
          color: isSelected ? null : _cream.withAlpha(8),
          border: Border.all(
            color: isSelected ? rColor : rColor.withAlpha(50),
            width: isSelected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: rColor.withAlpha(30), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Row(
          children: [
            // Artifact icon
            SizedBox(
              width: 36,
              height: 36,
              child: Image.asset(
                'assets/images/ui/artifact_${artifact.id}.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    color: rColor.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: rColor.withAlpha(80)),
                  ),
                  child: Icon(Icons.auto_awesome, color: rColor, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          artifact.name,
                          style: TextStyle(
                            color: rColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black.withAlpha(200), blurRadius: 3, offset: const Offset(0, 1))],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Rarity badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: rColor.withAlpha(70), width: 0.5),
                        ),
                        child: Text(
                          _rarityLabel(artifact.rarity),
                          style: TextStyle(
                            color: rColor.withAlpha(220),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    artifact.description,
                    style: TextStyle(
                      color: _cream.withAlpha(180),
                      fontSize: 10,
                      shadows: [Shadow(color: Colors.black.withAlpha(180), blurRadius: 2)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: rColor, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────── START BUTTON ────────────────

  Widget _buildStartButton() {
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GestureDetector(
        onTap: () {
          final selected = widget.artifactChoices
              .where((a) => _selectedArtifactIds.contains(a.id))
              .toList();
          widget.onStart(_difficulty, selected);
        },
        child: Container(
          height: h * 0.11,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: _gold.withAlpha(50), blurRadius: 16, spreadRadius: 2),
              BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Image.asset(
            'assets/images/ui/btn_basla.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_gold, _goldDark]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('BAŞLA', style: TextStyle(color: _darkBg, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────── HELPERS ────────────────

  String _rarityLabel(ArtifactRarity rarity) {
    switch (rarity) {
      case ArtifactRarity.common: return 'SİRADAN';
      case ArtifactRarity.rare: return 'NADİR';
      case ArtifactRarity.epic: return 'EPİK';
      case ArtifactRarity.legendary: return 'EFSANEVİ';
    }
  }

  Color _rarityColor(ArtifactRarity rarity) {
    switch (rarity) {
      case ArtifactRarity.common: return const Color(0xFFAAAAAA);
      case ArtifactRarity.rare: return const Color(0xFF4488FF);
      case ArtifactRarity.epic: return const Color(0xFFAA44FF);
      case ArtifactRarity.legendary: return _gold;
    }
  }
}
