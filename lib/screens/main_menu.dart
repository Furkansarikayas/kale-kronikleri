import 'dart:math' as math;
import 'package:flutter/material.dart';

class MainMenu extends StatefulWidget {
  final VoidCallback onPlay;
  final VoidCallback onMeta;
  final VoidCallback? onSettings;
  final int stoneSpirit;
  final int totalRuns;
  final int bestWave;
  final int totalKills;

  const MainMenu({
    super.key,
    required this.onPlay,
    required this.onMeta,
    this.onSettings,
    required this.stoneSpirit,
    required this.totalRuns,
    this.bestWave = 0,
    this.totalKills = 0,
  });

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4A843);
  static const _goldDark = Color(0xFFBA7517);
  static const _cream = Color(0xFFF0E6D0);
  static const _creamDim = Color(0xAAB8AE98);
  static const _bgDark = Color(0xFF0D0D15);

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  Color(0xFF151525),
                  Color(0xFF0D0D18),
                  Color(0xFF08080E),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Shimmer particles overlay
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ShimmerParticlePainter(phase: _shimmerController.value),
              );
            },
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Castle with golden glow
                      _buildCastleLogo(),
                      const SizedBox(height: 16),
                      // Title
                      _buildTitle(),
                      const SizedBox(height: 4),
                      // Subtitle
                      Text(
                        'Castle Chronicles',
                        style: TextStyle(
                          color: _cream.withAlpha(140),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Buttons
                      _buildButtons(),
                      const SizedBox(height: 24),
                      // Stats bar
                      _buildStatsBar(),
                      const SizedBox(height: 20),
                      // Decorative divider
                      _buildDecorativeDivider(),
                      const SizedBox(height: 8),
                      // Version
                      Text(
                        'v0.1.0',
                        style: TextStyle(
                          color: _creamDim.withAlpha(80),
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastleLogo() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _gold.withAlpha(30),
            blurRadius: 40,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: _goldDark.withAlpha(15),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: CustomPaint(
        size: const Size(140, 70),
        painter: _CastleSilhouettePainter(),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_gold, Color(0xFFE8C878), _gold],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: const Text(
        'KALE KRONIKLERI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
          letterSpacing: 3.0,
          shadows: [
            Shadow(color: Color(0x66D4A843), blurRadius: 12, offset: Offset(0, 2)),
            Shadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 3)),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 10,
      children: [
        _PremiumMenuButton(
          label: 'OYNA',
          icon: Icons.play_arrow,
          onPressed: widget.onPlay,
        ),
        _PremiumMenuButton(
          label: 'META AGACI',
          icon: Icons.account_tree,
          onPressed: widget.onMeta,
        ),
        if (widget.onSettings != null)
          _PremiumMenuButton(
            label: 'AYARLAR',
            icon: Icons.settings,
            onPressed: widget.onSettings!,
          ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _PremiumStatChip(icon: Icons.diamond, label: 'Tas Ruhu', value: '${widget.stoneSpirit}'),
        _PremiumStatChip(icon: Icons.loop, label: 'Kosu', value: '${widget.totalRuns}'),
        if (widget.bestWave > 0)
          _PremiumStatChip(icon: Icons.waves, label: 'En Iyi Dalga', value: '${widget.bestWave}'),
        if (widget.totalKills > 0)
          _PremiumStatChip(icon: Icons.dangerous, label: 'Toplam Oldurulen', value: '${widget.totalKills}'),
      ],
    );
  }

  Widget _buildDecorativeDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, _gold.withAlpha(80)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.star, color: _gold.withAlpha(60), size: 10),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_gold.withAlpha(80), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

class _CastleSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD4A843);
    final w = size.width;
    final h = size.height;

    // Main castle body
    final body = Path()
      ..moveTo(w * 0.15, h)
      ..lineTo(w * 0.15, h * 0.45)
      ..lineTo(w * 0.85, h * 0.45)
      ..lineTo(w * 0.85, h)
      ..close();
    canvas.drawPath(body, paint);

    // Left tower
    final leftTower = Path()
      ..moveTo(w * 0.05, h)
      ..lineTo(w * 0.05, h * 0.2)
      ..lineTo(w * 0.25, h * 0.2)
      ..lineTo(w * 0.25, h)
      ..close();
    canvas.drawPath(leftTower, paint);

    // Right tower
    final rightTower = Path()
      ..moveTo(w * 0.75, h)
      ..lineTo(w * 0.75, h * 0.2)
      ..lineTo(w * 0.95, h * 0.2)
      ..lineTo(w * 0.95, h)
      ..close();
    canvas.drawPath(rightTower, paint);

    // Center tower (tallest)
    final centerTower = Path()
      ..moveTo(w * 0.38, h * 0.45)
      ..lineTo(w * 0.38, h * 0.05)
      ..lineTo(w * 0.62, h * 0.05)
      ..lineTo(w * 0.62, h * 0.45)
      ..close();
    canvas.drawPath(centerTower, paint);

    // Battlements on towers
    final battPaint = Paint()..color = const Color(0xFF0D0D15);
    final battW = w * 0.04;
    // Left tower
    for (double x = w * 0.05; x < w * 0.25 - battW; x += battW * 2) {
      canvas.drawRect(Rect.fromLTWH(x + battW * 0.5, h * 0.17, battW, h * 0.05), battPaint);
    }
    // Right tower
    for (double x = w * 0.75; x < w * 0.95 - battW; x += battW * 2) {
      canvas.drawRect(Rect.fromLTWH(x + battW * 0.5, h * 0.17, battW, h * 0.05), battPaint);
    }
    // Center tower
    for (double x = w * 0.38; x < w * 0.62 - battW; x += battW * 2) {
      canvas.drawRect(Rect.fromLTWH(x + battW * 0.5, h * 0.02, battW, h * 0.05), battPaint);
    }

    // Gate
    canvas.drawRect(
      Rect.fromLTWH(w * 0.42, h * 0.65, w * 0.16, h * 0.35),
      Paint()..color = const Color(0xFF3C2505),
    );
    // Gate arch
    canvas.drawArc(
      Rect.fromLTWH(w * 0.42, h * 0.55, w * 0.16, h * 0.22),
      3.14159, 3.14159, false,
      Paint()..color = const Color(0xFF3C2505)..style = PaintingStyle.fill,
    );

    // Flag on center tower
    final flagPaint = Paint()..color = const Color(0xFFCC0000);
    canvas.drawLine(
      Offset(w * 0.5, h * 0.05),
      Offset(w * 0.5, h * -0.05),
      Paint()..color = const Color(0xFF888888)..strokeWidth = 1,
    );
    final flag = Path()
      ..moveTo(w * 0.5, h * -0.05)
      ..lineTo(w * 0.56, h * 0.0)
      ..lineTo(w * 0.5, h * 0.03)
      ..close();
    canvas.drawPath(flag, flagPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Floating shimmer particles
class _ShimmerParticlePainter extends CustomPainter {
  final double phase;
  _ShimmerParticlePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    const count = 30;
    for (int i = 0; i < count; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final sizeR = 0.8 + rng.nextDouble() * 1.5;

      // Each particle drifts upward and fades in/out
      final offset = (phase * speed + i / count) % 1.0;
      final y = baseY - offset * size.height * 0.3;
      final opacity = (math.sin(offset * math.pi) * 0.35).clamp(0.0, 1.0);

      if (opacity > 0.02) {
        canvas.drawCircle(
          Offset(baseX + math.sin(phase * 2 * math.pi + i) * 8, y % size.height),
          sizeR,
          Paint()..color = const Color(0xFFD4A843).withAlpha((opacity * 255).round()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ShimmerParticlePainter old) => true;
}

class _PremiumStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PremiumStatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151520), Color(0xFF111118)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33D4A843), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFD4A843), size: 13),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xAAB8AE98), fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF0E6D0),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PremiumMenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_PremiumMenuButton> createState() => _PremiumMenuButtonState();
}

class _PremiumMenuButtonState extends State<_PremiumMenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 170,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pressed
                ? [const Color(0xFF8A5510), const Color(0xFF6A4010)]
                : [const Color(0xFFD4A843), const Color(0xFFBA7517)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _pressed ? const Color(0xFFAA8030) : const Color(0xFFE8C878),
            width: 1,
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFD4A843).withAlpha(30),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Top edge inner highlight
            if (!_pressed)
              Positioned(
                top: 1,
                left: 12,
                right: 12,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withAlpha(60),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            // Button content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 20, color: const Color(0xFF0D0D15)),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF0D0D15),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Color(0x33FFFFFF), blurRadius: 2),
                      ],
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
}
