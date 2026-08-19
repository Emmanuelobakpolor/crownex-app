import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Full-screen hourglass processing state after PIN confirmation.
class AirtimeProcessingScreen extends StatefulWidget {
  const AirtimeProcessingScreen({super.key, this.future});

  /// When provided, this screen waits for the real purchase call to finish
  /// and pops with its result. Omit to keep the legacy fixed-delay placeholder.
  final Future<bool>? future;

  @override
  State<AirtimeProcessingScreen> createState() =>
      _AirtimeProcessingScreenState();
}

class _AirtimeProcessingScreenState extends State<AirtimeProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    final future = widget.future;
    if (future != null) {
      future.then((result) {
        if (mounted) Navigator.of(context).pop(result);
      });
    } else {
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Transform.rotate(
                angle: t * 0.15,
                child: child,
              );
            },
            child: const _HourglassIcon(size: 72),
          ),
        ),
      ),
    );
  }
}

class _HourglassIcon extends StatelessWidget {
  const _HourglassIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.15),
      painter: _HourglassPainter(),
    );
  }
}

class _HourglassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final glassPaint = Paint()
      ..color = const Color(0xFFD6E4FF)
      ..style = PaintingStyle.fill;

    final outline = Paint()
      ..color = const Color(0xFFB8C9F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final sandPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    // Glass body — hourglass silhouette
    final glass = Path()
      ..moveTo(w * 0.22, h * 0.08)
      ..lineTo(w * 0.78, h * 0.08)
      ..lineTo(w * 0.78, h * 0.14)
      ..quadraticBezierTo(w * 0.72, h * 0.28, cx, h * 0.48)
      ..quadraticBezierTo(w * 0.28, h * 0.28, w * 0.22, h * 0.14)
      ..close()
      ..moveTo(w * 0.22, h * 0.92)
      ..lineTo(w * 0.78, h * 0.92)
      ..lineTo(w * 0.78, h * 0.86)
      ..quadraticBezierTo(w * 0.72, h * 0.72, cx, h * 0.52)
      ..quadraticBezierTo(w * 0.28, h * 0.72, w * 0.22, h * 0.86)
      ..close();

    canvas.drawPath(glass, glassPaint);
    canvas.drawPath(glass, outline);

    // Top caps
    final capPaint = Paint()..color = const Color(0xFFC5D4F5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.04, w * 0.64, h * 0.07),
        const Radius.circular(4),
      ),
      capPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.89, w * 0.64, h * 0.07),
        const Radius.circular(4),
      ),
      capPaint,
    );

    // Sand top (triangle pouring)
    final topSand = Path()
      ..moveTo(w * 0.32, h * 0.18)
      ..lineTo(w * 0.68, h * 0.18)
      ..lineTo(cx, h * 0.46)
      ..close();
    canvas.drawPath(topSand, sandPaint);

    // Sand stream
    final stream = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, h * 0.46), Offset(cx, h * 0.72), stream);

    // Dots falling
    final dots = Paint()..color = AppColors.primary.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(cx - 3, h * 0.58), 1.4, dots);
    canvas.drawCircle(Offset(cx + 2, h * 0.64), 1.2, dots);
    canvas.drawCircle(Offset(cx - 1, h * 0.70), 1.3, dots);

    // Sand bottom pile
    final bottomSand = Path()
      ..moveTo(cx, h * 0.72)
      ..lineTo(w * 0.38, h * 0.86)
      ..lineTo(w * 0.62, h * 0.86)
      ..close();
    canvas.drawPath(bottomSand, sandPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
