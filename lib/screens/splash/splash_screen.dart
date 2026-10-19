import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';

/// Animated intro: a homeless woman in torn clothes eating beside a garbage
/// heap at night, the "human shelter" slogan, and a themed progress bar.
/// When the progress completes the app moves on to the login screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _loadTime = Duration(milliseconds: 5200);

  /// Loops forever: drives eating, breathing, steam, flies and stars.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  /// 0 -> 1 once; drives the progress bar and the text reveal.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _loadTime,
  );

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _progress
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      })
      ..forward();
  }

  void _next() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _loop.dispose();
    _progress.dispose();
    super.dispose();
  }

  static String _status(double p) {
    if (p < 0.3) return 'Finding people who need help…';
    if (p < 0.6) return 'Opening doors and beds…';
    if (p < 0.9) return 'Connecting kind hearts…';
    return 'Welcome to Shelter Connect';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF062A28),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF062A28), Color(0xFF0F766E)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxHeight < 640;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    SizedBox(height: compact ? 8 : 20),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 360 / 300,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: AnimatedBuilder(
                              animation: _loop,
                              builder: (_, _) => CustomPaint(
                                painter: _ScenePainter(_loop.value),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (_, _) {
                        final p = _progress.value;
                        final reveal = Curves.easeOut.transform(
                          (p / 0.25).clamp(0.0, 1.0),
                        );
                        return Column(
                          children: [
                            Opacity(
                              opacity: reveal,
                              child: Transform.translate(
                                offset: Offset(0, (1 - reveal) * 14),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.home_rounded,
                                          color: AppColors.accent,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Shelter Connect',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: compact ? 24 : 28,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'A roof is not a privilege.\nIt is every human’s right.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Human shelter · Food · Dignity · Hope',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12.5,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 16 : 26),
                            _ProgressBar(value: p),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _status(p),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(p * 100).round()}%',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: compact ? 14 : 28),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (_, c) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF5EEAD4)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Night scene drawn in a 360 x 300 design space and scaled to fit.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.t);

  /// Loop position 0..1.
  final double t;

  static const _skin = Color(0xFFC68E6B);
  static const _dress = Color(0xFF6B5B4E);
  static const _hair = Color(0xFF2A1B14);

  double get _tau => t * math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 300);
    _sky(canvas);
    _wall(canvas);
    _garbage(canvas);
    _woman(canvas);
    _flies(canvas);
    canvas.restore();
  }

  void _sky(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 360, 300);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1F2E), Color(0xFF17384A)],
        ).createShader(rect),
    );
    // Moon with glow.
    canvas.drawCircle(
      const Offset(300, 48),
      34,
      Paint()
        ..color = const Color(0xFFFDE68A).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      const Offset(300, 48),
      15,
      Paint()..color = const Color(0xFFFEF3C7),
    );
    // Twinkling stars.
    const stars = [
      Offset(40, 30),
      Offset(95, 62),
      Offset(150, 24),
      Offset(215, 50),
      Offset(250, 20),
      Offset(70, 96),
      Offset(330, 100),
    ];
    for (var i = 0; i < stars.length; i++) {
      final a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(_tau + i * 1.7));
      canvas.drawCircle(
        stars[i],
        1.6,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
  }

  void _wall(Canvas canvas) {
    final wall = Rect.fromLTWH(0, 120, 360, 130);
    canvas.drawRect(wall, Paint()..color = const Color(0xFF22404A));
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var y = 136.0; y < 250; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(360, y), line);
      final off = ((y - 136) / 18).round().isEven ? 0.0 : 20.0;
      for (var x = off; x < 360; x += 40) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 18), line);
      }
    }
    // Ground.
    canvas.drawRect(
      const Rect.fromLTWH(0, 250, 360, 50),
      Paint()..color = const Color(0xFF101C24),
    );
    // Streetlamp glow falling on the woman.
    canvas.drawOval(
      const Rect.fromLTWH(110, 232, 170, 36),
      Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _garbage(Canvas canvas) {
    // Bin.
    final bin = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 170, 62, 82),
      const Radius.circular(5),
    );
    canvas.drawRRect(bin, Paint()..color = const Color(0xFF3F5B57));
    for (var x = 30.0; x < 76; x += 12) {
      canvas.drawLine(
        Offset(x, 180),
        Offset(x, 246),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..strokeWidth = 2,
      );
    }
    canvas.save();
    canvas.translate(14, 172);
    canvas.rotate(-0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, -10, 70, 12),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF516F6A),
    );
    canvas.restore();
    // Bags piled up.
    final bag = Paint()..color = const Color(0xFF0B1316);
    canvas.drawCircle(const Offset(98, 234), 20, bag);
    canvas.drawCircle(const Offset(66, 244), 16, bag);
    canvas.drawCircle(const Offset(120, 244), 14, bag);
    final tie = Path()
      ..moveTo(92, 216)
      ..lineTo(98, 206)
      ..lineTo(104, 216)
      ..close();
    canvas.drawPath(tie, bag);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawOval(const Rect.fromLTWH(86, 224, 10, 6), shine);
    // Litter on the ground.
    final litter = [
      (const Rect.fromLTWH(135, 254, 9, 6), const Color(0xFFD6D3D1)),
      (const Rect.fromLTWH(262, 258, 12, 5), const Color(0xFF9A7B4F)),
      (const Rect.fromLTWH(290, 252, 7, 7), const Color(0xFFB91C1C)),
      (const Rect.fromLTWH(32, 258, 10, 5), const Color(0xFFE7E5E4)),
      (const Rect.fromLTWH(320, 260, 9, 5), const Color(0xFF64748B)),
    ];
    for (final (r, c) in litter) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1.5)),
        Paint()..color = c,
      );
    }
  }

  /// 0 = bowl, 1 = mouth, one eating cycle per loop.
  double get _reach {
    final p = t;
    if (p < 0.35) return Curves.easeInOut.transform(p / 0.35);
    if (p < 0.6) return 1;
    if (p < 0.9) return 1 - Curves.easeInOut.transform((p - 0.6) / 0.3);
    return 0;
  }

  bool get _chewing => t >= 0.35 && t < 0.62;

  void _woman(Canvas canvas) {
    final breathe = math.sin(_tau * 2) * 1.2;
    final bob = _chewing ? math.sin(_tau * 14) * 0.9 : 0.0;

    // Cardboard she sits on.
    canvas.drawPath(
      Path()
        ..moveTo(122, 252)
        ..lineTo(268, 252)
        ..lineTo(278, 266)
        ..lineTo(112, 266)
        ..close(),
      Paint()..color = const Color(0xFF8B6B3E),
    );
    canvas.drawLine(
      const Offset(122, 252),
      const Offset(112, 266),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..strokeWidth = 1,
    );

    // Torn dress: seated body shape with a ragged hem.
    final dress = Path()
      ..moveTo(168, 140 + breathe)
      ..quadraticBezierTo(190, 132 + breathe, 214, 140 + breathe)
      ..quadraticBezierTo(244, 190, 250, 246)
      ..lineTo(240, 240)
      ..lineTo(232, 252)
      ..lineTo(222, 243)
      ..lineTo(212, 253)
      ..lineTo(200, 244)
      ..lineTo(188, 254)
      ..lineTo(176, 244)
      ..lineTo(164, 253)
      ..lineTo(152, 243)
      ..lineTo(142, 251)
      ..lineTo(134, 244)
      ..quadraticBezierTo(140, 190, 168, 140 + breathe)
      ..close();
    canvas.drawPath(dress, Paint()..color = _dress);
    // Folds.
    final fold = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(176, 170)
        ..quadraticBezierTo(166, 205, 164, 240),
      fold,
    );
    canvas.drawPath(
      Path()
        ..moveTo(206, 176)
        ..quadraticBezierTo(214, 210, 220, 242),
      fold,
    );

    // Patches with stitches.
    _patch(
      canvas,
      const Rect.fromLTWH(150, 205, 26, 22),
      const Color(0xFF4F6B73),
    );
    _patch(
      canvas,
      const Rect.fromLTWH(212, 196, 22, 26),
      const Color(0xFF8A6F5A),
    );
    _patch(
      canvas,
      const Rect.fromLTWH(188, 224, 18, 14),
      const Color(0xFF7A4B4B),
    );
    // Holes showing skin.
    canvas.drawOval(
      const Rect.fromLTWH(192, 168, 12, 9),
      Paint()..color = _skin.withValues(alpha: 0.85),
    );
    canvas.drawOval(
      const Rect.fromLTWH(172, 190, 9, 7),
      Paint()..color = _skin.withValues(alpha: 0.85),
    );

    // Tattered shawl on the shoulders.
    final shawl = Path()
      ..moveTo(160, 148 + breathe)
      ..quadraticBezierTo(190, 136 + breathe, 220, 148 + breathe)
      ..lineTo(226, 166)
      ..lineTo(218, 162)
      ..lineTo(212, 172)
      ..lineTo(204, 163)
      ..lineTo(196, 174)
      ..lineTo(188, 164)
      ..lineTo(180, 173)
      ..lineTo(172, 163)
      ..lineTo(164, 170)
      ..lineTo(156, 162)
      ..close();
    canvas.drawPath(shawl, Paint()..color = const Color(0xFF4A4036));

    // Head.
    final headC = Offset(190, 112 + breathe + bob);
    // Hair behind.
    canvas.drawPath(
      Path()
        ..moveTo(headC.dx - 24, headC.dy + 6)
        ..quadraticBezierTo(
          headC.dx - 30,
          headC.dy - 34,
          headC.dx,
          headC.dy - 28,
        )
        ..quadraticBezierTo(
          headC.dx + 30,
          headC.dy - 34,
          headC.dx + 24,
          headC.dy + 8,
        )
        ..lineTo(headC.dx + 26, headC.dy + 30)
        ..lineTo(headC.dx + 18, headC.dy + 22)
        ..lineTo(headC.dx - 18, headC.dy + 22)
        ..lineTo(headC.dx - 26, headC.dy + 30)
        ..close(),
      Paint()..color = _hair,
    );
    canvas.drawCircle(headC, 19, Paint()..color = _skin);
    // Messy fringe and loose strands.
    canvas.drawPath(
      Path()
        ..moveTo(headC.dx - 20, headC.dy - 4)
        ..quadraticBezierTo(
          headC.dx - 6,
          headC.dy - 30,
          headC.dx + 20,
          headC.dy - 6,
        )
        ..quadraticBezierTo(
          headC.dx + 4,
          headC.dy - 14,
          headC.dx - 20,
          headC.dy - 4,
        )
        ..close(),
      Paint()..color = _hair,
    );
    final strand = Paint()
      ..color = _hair
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(headC.dx - 22, headC.dy - 12),
      Offset(headC.dx - 30, headC.dy - 20),
      strand,
    );
    canvas.drawLine(
      Offset(headC.dx + 20, headC.dy - 16),
      Offset(headC.dx + 28, headC.dy - 24),
      strand,
    );
    // Dirt smudge on cheek.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headC.dx + 10, headC.dy + 7),
        width: 8,
        height: 4,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    // Face: tired eyes look down; blink now and then.
    final blink = (t > 0.72 && t < 0.78);
    final eye = Paint()
      ..color = const Color(0xFF2B1A12)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final dx in [-7.0, 7.0]) {
      final c = Offset(headC.dx + dx, headC.dy + 1);
      if (blink || _chewing) {
        canvas.drawArc(
          Rect.fromCenter(center: c, width: 7, height: 4),
          0.1,
          math.pi - 0.2,
          false,
          eye,
        );
      } else {
        canvas.drawCircle(
          c.translate(0, 0.8),
          1.7,
          Paint()..color = const Color(0xFF2B1A12),
        );
      }
      // Sad brow.
      canvas.drawLine(
        c.translate(-3.5 * dx.sign, -5.2),
        c.translate(3.5 * dx.sign, -7),
        eye..strokeWidth = 1.3,
      );
    }
    // Mouth: opens while taking a bite, otherwise a small tired line.
    final mouth = Offset(headC.dx, headC.dy + 12);
    final mouthOpen = _reach > 0.85;
    if (mouthOpen) {
      canvas.drawOval(
        Rect.fromCenter(center: mouth, width: 8, height: 5),
        Paint()..color = const Color(0xFF5B1F1F),
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: mouth.translate(0, 2), width: 8, height: 5),
        math.pi,
        math.pi,
        false,
        eye..strokeWidth = 1.4,
      );
    }

    // Left arm (viewer's left) holds the bowl on her lap.
    final bowlC = Offset(172, 214 + breathe * 0.4);
    final armPaint = Paint()
      ..color = _dress
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(166, 152 + breathe)
        ..quadraticBezierTo(150, 190, bowlC.dx - 8, bowlC.dy - 4),
      armPaint,
    );
    // Torn sleeve edge.
    canvas.drawCircle(
      Offset(160, 168 + breathe),
      2.6,
      Paint()..color = _skin.withValues(alpha: 0.9),
    );
    _bowl(canvas, bowlC);
    canvas.drawCircle(bowlC.translate(-10, -4), 5.2, Paint()..color = _skin);

    // Right arm: bowl <-> mouth.
    final shoulder = Offset(214, 154 + breathe);
    final mouthTarget = Offset(headC.dx + 11, headC.dy + 14);
    final hand = Offset.lerp(
      Offset(bowlC.dx + 14, bowlC.dy - 8),
      mouthTarget,
      _reach,
    )!;
    final elbow = Offset(
      math.max(shoulder.dx, hand.dx) + 14 - 6 * _reach,
      (shoulder.dy + hand.dy) / 2 + 6,
    );
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..quadraticBezierTo(elbow.dx, elbow.dy, hand.dx, hand.dy),
      armPaint,
    );
    canvas.drawCircle(
      Offset.lerp(shoulder, hand, 0.55)!.translate(4, 2),
      2.2,
      Paint()..color = _skin.withValues(alpha: 0.9),
    );
    // Bread in her hand, with a bite taken.
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(-0.5 + _reach * 0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -6, 17, 11),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFD9A55B),
    );
    canvas.drawCircle(
      const Offset(13, -2),
      3.2,
      Paint()..color = const Color(0xFF17384A),
    );
    canvas.restore();
    canvas.drawCircle(hand, 4.6, Paint()..color = _skin);

    // Steam rising from the bowl.
    for (var i = 0; i < 3; i++) {
      final ph = (t + i / 3) % 1;
      final x = bowlC.dx - 8 + i * 8 + math.sin(ph * math.pi * 3 + i) * 3;
      canvas.drawCircle(
        Offset(x, bowlC.dy - 10 - ph * 26),
        2.4 + ph * 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28 * (1 - ph))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  void _bowl(Canvas canvas, Offset c) {
    final path = Path()
      ..moveTo(c.dx - 18, c.dy - 6)
      ..lineTo(c.dx + 18, c.dy - 6)
      ..quadraticBezierTo(c.dx + 16, c.dy + 14, c.dx, c.dy + 14)
      ..quadraticBezierTo(c.dx - 16, c.dy + 14, c.dx - 18, c.dy - 6)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFA8B3B3));
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -6), width: 36, height: 8),
      Paint()..color = const Color(0xFFD97706),
    );
    // Dent.
    canvas.drawCircle(
      c.translate(9, 4),
      2.4,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  void _patch(Canvas canvas, Rect r, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(2)),
      Paint()..color = color,
    );
    final stitch = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final inner = r.deflate(2.5);
    for (var x = inner.left; x < inner.right; x += 4) {
      canvas.drawLine(Offset(x, inner.top), Offset(x + 2, inner.top), stitch);
      canvas.drawLine(
        Offset(x, inner.bottom),
        Offset(x + 2, inner.bottom),
        stitch,
      );
    }
    for (var y = inner.top; y < inner.bottom; y += 4) {
      canvas.drawLine(Offset(inner.left, y), Offset(inner.left, y + 2), stitch);
      canvas.drawLine(
        Offset(inner.right, y),
        Offset(inner.right, y + 2),
        stitch,
      );
    }
  }

  void _flies(Canvas canvas) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 3; i++) {
      final a = _tau * (1 + i) + i * 2.1;
      canvas.drawCircle(
        Offset(98 + math.cos(a) * (16 + i * 5), 196 + math.sin(a * 1.3) * 10),
        1.1,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.t != t;
}
