import 'package:flutter/material.dart';

/// Custom painter for drawing signature strokes
class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color strokeColor;
  final double strokeWidth;

  SignaturePainter({
    required this.strokes,
    this.strokeColor = Colors.black,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw each stroke
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      if (stroke.length == 1) {
        // Draw a dot for single-point strokes
        canvas.drawCircle(
          stroke.first,
          strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke; // Reset to stroke style
      } else {
        // Draw a path for multi-point strokes
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);

        for (int i = 1; i < stroke.length; i++) {
          // Use quadratic bezier for smoother lines
          if (i < stroke.length - 1) {
            final current = stroke[i];
            final next = stroke[i + 1];
            final controlPoint = Offset(
              (current.dx + next.dx) / 2,
              (current.dy + next.dy) / 2,
            );
            path.quadraticBezierTo(
              current.dx,
              current.dy,
              controlPoint.dx,
              controlPoint.dy,
            );
          } else {
            // Last point
            path.lineTo(stroke[i].dx, stroke[i].dy);
          }
        }

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    // Repaint if strokes have changed
    return strokes.length != oldDelegate.strokes.length ||
        strokeColor != oldDelegate.strokeColor ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}