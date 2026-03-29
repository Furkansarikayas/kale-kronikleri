import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'widgets/glass_panel.dart';

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
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3, 0.2),
                  radius: 1.2,
                  colors: [Color(0xFF2A1F3D), Color(0xFF18122B), Color(0xFF0D0D15)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Background castle image - full opacity, image is already dark
          Positioned.fill(
            child: Image.asset(
              'assets/images/ui/menu_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                      const SizedBox(height: 4),
                      // Title
                      _buildTitle(),
                      const SizedBox(height: 1),
                      // Subtitle
                      Text(
                        'Kale Kronikleri',
                        style: TextStyle(
                          color: _cream.withAlpha(140),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Buttons
                      _buildButtons(),
                      const SizedBox(height: 6),
                      // Stats bar
                      _buildStatsBar(),
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
      child: Image.asset(
        'assets/images/ui/castle_logo.png',
        width: 110,
        height: 110,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => CustomPaint(
          size: const Size(140, 70),
          painter: _CastleSilhouettePainter(),
        ),
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
    return Column(
      children: [
        _PremiumMenuButton(
          label: 'OYNA',
          icon: Icons.play_arrow,
          imageAsset: 'assets/images/ui/btn_oyna.png',
          onPressed: widget.onPlay,
          widthFactor: 0.52,
          heightFactor: 0.17,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PremiumMenuButton(
              label: 'META AĞACI',
              icon: Icons.account_tree,
              imageAsset: 'assets/images/ui/btn_meta.png',
              onPressed: widget.onMeta,
              widthFactor: 0.40,
              heightFactor: 0.14,
            ),
            const SizedBox(width: 14),
            if (widget.onSettings != null)
              _PremiumMenuButton(
                label: 'AYARLAR',
                icon: Icons.settings,
                imageAsset: 'assets/images/ui/btn_ayarlar.png',
                onPressed: widget.onSettings!,
                widthFactor: 0.40,
                heightFactor: 0.14,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _PremiumStatChip(imageAsset: 'assets/images/ui/stat_spirit.png', icon: Icons.diamond, label: 'Taş Ruhu', value: '${widget.stoneSpirit}'),
        _PremiumStatChip(imageAsset: 'assets/images/ui/stat_runs.png', icon: Icons.loop, label: 'Koşu', value: '${widget.totalRuns}'),
        if (widget.bestWave > 0)
          _PremiumStatChip(imageAsset: 'assets/images/ui/stat_wave.png', icon: Icons.waves, label: 'En İyi Dalga', value: '${widget.bestWave}'),
        if (widget.totalKills > 0)
          _PremiumStatChip(imageAsset: 'assets/images/ui/stat_kills.png', icon: Icons.dangerous, label: 'Toplam Öldürülen', value: '${widget.totalKills}'),
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
    if (size.width <= 0 || size.height <= 0) return;
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
  final String? imageAsset;

  const _PremiumStatChip({required this.icon, required this.label, required this.value, this.imageAsset});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return SizedBox(
      width: h * 0.35,
      height: h * 0.10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageAsset != null)
            Image.asset(
              imageAsset!,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                '$label: $value',
                style: TextStyle(
                  color: const Color(0xFFF0E6D0),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black.withAlpha(180), blurRadius: 3, offset: const Offset(0, 1)),
                  ],
                ),
              ),
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
  final String? imageAsset;
  final VoidCallback onPressed;
  final double? widthFactor;
  final double? heightFactor;

  const _PremiumMenuButton({
    required this.label,
    required this.icon,
    this.imageAsset,
    required this.onPressed,
    this.widthFactor,
    this.heightFactor,
  });

  @override
  State<_PremiumMenuButton> createState() => _PremiumMenuButtonState();
}

class _PremiumMenuButtonState extends State<_PremiumMenuButton> {
  bool _pressed = false;

  static const _gold = Color(0xFFD4A843);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: MediaQuery.of(context).size.height * (widget.widthFactor ?? 0.52),
            height: MediaQuery.of(context).size.height * (widget.heightFactor ?? 0.18),
            decoration: BoxDecoration(
              boxShadow: _pressed
                  ? []
                  : [
                      BoxShadow(color: _gold.withAlpha(40), blurRadius: 16, spreadRadius: 2, offset: const Offset(0, 4)),
                      BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
            ),
            child: Image.asset(
              widget.imageAsset ?? 'assets/images/ui/button_normal.png',
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4A843), Color(0xFFBA7517)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8C878)),
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF0D0D15),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
