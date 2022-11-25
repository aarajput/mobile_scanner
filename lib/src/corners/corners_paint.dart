import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CornersPaint extends StatelessWidget {
  final Stream<BarcodeCapture> barcodeCapture;
  final Widget child;

  const CornersPaint({
    required this.barcodeCapture,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BarcodeCapture>(
      stream: barcodeCapture,
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return child;
        }
        return CustomPaint(
          foregroundPainter: CornersPainter(snapshot.data!),
          child: child,
        );
      },
    );
  }
}

class CornersPainter extends CustomPainter {
  final BarcodeCapture barcodeCapture;
  final Paint redPaint;

  CornersPainter(this.barcodeCapture)
      : redPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, 0);

    canvas.drawPath(path, redPaint);
    final imageSize = barcodeCapture.imageSize;
    final widthFactor = imageSize == null ? 1 : size.height / imageSize.height;
    final heightFactor = imageSize == null ? 1 : size.width / imageSize.width;
    final barcodes = barcodeCapture.barcodes;
    for (int i = 0; i < barcodes.length; i++) {
      final corners = barcodes[i].corners;
      if (corners != null && corners.length == 4) {
        print('corner_0: ${corners[0]}');
        final path = Path()
          ..moveTo(corners[0].dy * widthFactor, corners[0].dx * heightFactor)
          ..lineTo(corners[1].dy * widthFactor, corners[1].dx * heightFactor)
          ..lineTo(corners[2].dy * widthFactor, corners[2].dx * heightFactor)
          ..lineTo(corners[3].dy * widthFactor, corners[3].dx * heightFactor)
          ..lineTo(corners[0].dy * widthFactor, corners[0].dx * heightFactor);
        canvas.drawPath(path, redPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
