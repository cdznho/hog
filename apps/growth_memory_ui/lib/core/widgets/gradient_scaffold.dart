import 'dart:math' as math;

import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.9),
                  radius: 1.4,
                  colors: [
                    scheme.primary.withValues(alpha: 0.28),
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.20,
              child: CustomPaint(painter: _NoisePainter(color: scheme.onSurface)),
            ),
          ),
          SafeArea(child: body),
        ],
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.04);
    final rand = math.Random(42);
    const dots = 14000;
    for (var i = 0; i < dots; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}

