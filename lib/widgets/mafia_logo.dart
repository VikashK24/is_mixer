import 'package:flutter/material.dart';

/// A drawn fedora, the same icon used on the event poster.
class FedoraLogo extends StatelessWidget {
  final double size;
  final Color color;

  const FedoraLogo({super.key, this.size = 32, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FedoraPainter(color)),
    );
  }
}

class _FedoraPainter extends CustomPainter {
  final Color color;

  _FedoraPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // brim
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, w * 0.69),
        width: w * 0.92,
        height: w * 0.26,
      ),
      stroke,
    );

    // crown
    final crown = Path()
      ..moveTo(w * 0.27, w * 0.64)
      ..lineTo(w * 0.27, w * 0.41)
      ..cubicTo(w * 0.27, w * 0.26, w * 0.38, w * 0.17, w * 0.5, w * 0.17)
      ..cubicTo(w * 0.62, w * 0.17, w * 0.73, w * 0.26, w * 0.73, w * 0.41)
      ..lineTo(w * 0.73, w * 0.64);
    canvas.drawPath(crown, stroke);

    // hat band
    final band = Path()
      ..moveTo(w * 0.27, w * 0.54)
      ..quadraticBezierTo(w * 0.5, w * 0.62, w * 0.73, w * 0.54);
    canvas.drawPath(band, stroke);
  }

  @override
  bool shouldRepaint(covariant _FedoraPainter oldDelegate) =>
      oldDelegate.color != color;
}