import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );
    _anim.forward();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft white base + green wash
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF3FBF6),
                  Color(0xFFE8F5EE),
                ],
              ),
            ),
          ),
          // Subtle green geometric texture (matches the hex logo language)
          CustomPaint(
            painter: _GreenTexturePainter(),
            size: Size.infinite,
          ),
          // Soft vignette so the center stays clean for the logo
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Image.asset(
                        'assets/images/logo_full.png',
                        height: 58,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          'whoseNearby',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Skilled hands, right around you',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: AppColors.inkSoft,
                      ),
                    ),
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

/// Light green dots + faint hex grid for texture without fighting the logo.
class _GreenTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..color = const Color(0xFF2A9468).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final ring = Paint()
      ..color = const Color(0xFF1A5C42).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const spacing = 28.0;
    for (double y = 0; y < size.height + spacing; y += spacing) {
      final offset = ((y / spacing).floor() % 2) * (spacing / 2);
      for (double x = -spacing; x < size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x + offset, y), 2.2, dot);
      }
    }

    // A few soft hex outlines in the corners (brand motif)
    void hex(Offset c, double r) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ring);
    }

    hex(Offset(size.width * 0.12, size.height * 0.18), 36);
    hex(Offset(size.width * 0.88, size.height * 0.22), 28);
    hex(Offset(size.width * 0.18, size.height * 0.82), 32);
    hex(Offset(size.width * 0.85, size.height * 0.78), 40);
    hex(Offset(size.width * 0.5, size.height * 0.12), 22);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
