import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a yellow Pac-Man disc facing [headingRadians] (0 = east, CCW
/// positive, matching atan2(-dy, dx) screen convention) with a mouth wedge
/// that opens by [mouthOpen] (0 = closed, 1 = fully open).
class PacmanPainter extends CustomPainter {
  final double headingRadians;
  final double mouthOpen;

  const PacmanPainter({required this.headingRadians, required this.mouthOpen});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()..color = const Color(0xffffff00);

    final halfMouth =
        mouthOpen.clamp(0.0, 1.0) * (math.pi / 4); // up to 45deg half-angle
    // Screen y grows downward, so flip the heading sign to match atan2(-dy, dx).
    final dir = -headingRadians;

    if (halfMouth < 0.02) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        dir + halfMouth,
        2 * math.pi - 2 * halfMouth,
        false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PacmanPainter oldDelegate) =>
      oldDelegate.headingRadians != headingRadians ||
      oldDelegate.mouthOpen != mouthOpen;
}
