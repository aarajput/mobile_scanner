import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CornersPaint extends StatelessWidget {
  final Stream<BarcodeCapture> barcodeCapture;
  final BarcodeRect? barcodeRect;
  final Widget child;
  final Size previewSize;

  const CornersPaint({
    required this.barcodeCapture,
    required this.barcodeRect,
    required this.previewSize,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BarcodeCapture>(
      stream: barcodeCapture,
      builder: (_, snapshot) {
        final barcodeCapture = snapshot.data;
        if (barcodeCapture == null ||
            barcodeCapture.imageSize == null ||
            barcodeRect == null) {
          return child;
        }
        final barcodeRects = barcodeCapture.barcodes
            .where((bc) => bc.rawValue != null && bc.corners != null)
            .map(
              (bc) => _BarcodeRect(
                barcode: bc,
                color: barcodeRect!.selectedBarcodes.contains(bc.rawValue ?? '')
                    ? barcodeRect!.selectedRectColor ?? Colors.green
                    : Colors.red,
                corners: bc.corners!.map((corner) {
                  final widthFactor =
                      previewSize.width / barcodeCapture.imageSize!.width;
                  final heightFactor =
                      previewSize.height / barcodeCapture.imageSize!.height;
                  return Offset(
                    corner.dx * widthFactor,
                    corner.dy * heightFactor,
                  );
                }).toList(),
              ),
            )
            .toList();
        return GestureDetector(
          onTapDown: barcodeRect!.onRectTap == null
              ? null
              : (event) {
                  final tappedBarcodes = barcodeRects.where(
                    (rect) {
                      final qArea = calculatePolygonArea(rect.corners);
                      final x = event.localPosition.dx;
                      final y = event.localPosition.dy;
                      final double tapArea = [
                        calculatePolygonArea([
                          Offset(x, y),
                          rect.corners[0],
                          rect.corners[1],
                        ]),
                        calculatePolygonArea([
                          Offset(x, y),
                          rect.corners[1],
                          rect.corners[2],
                        ]),
                        calculatePolygonArea([
                          Offset(x, y),
                          rect.corners[2],
                          rect.corners[3],
                        ]),
                        calculatePolygonArea([
                          Offset(x, y),
                          rect.corners[3],
                          rect.corners[0],
                        ]),
                      ].fold(
                        0,
                        (previousValue, value) => previousValue + value,
                      );
                      return (qArea - tapArea).abs() < 5;
                    },
                  ).toList();
                  if (tappedBarcodes.isNotEmpty) {
                    barcodeRect!.onRectTap!.call(tappedBarcodes.first.barcode);
                  }
                },
          child: CustomPaint(
            foregroundPainter: CornersPainter(
              imageSize: barcodeCapture.imageSize!,
              barcodeRects: barcodeRects,
            ),
            child: child,
          ),
        );
      },
    );
  }

  double calculatePolygonArea(List<Offset> corners) {
    final xs = corners.map((c) => c.dx).toList();
    final ys = corners.map((c) => c.dy).toList();

    final numPoints = corners.length;
    var area = 0.0;
    var j = numPoints - 1;

    for (int i = 0; i < numPoints; i++) {
      area = area + (xs[j] + xs[i]) * (ys[j] - ys[i]);
      j = i;
    }
    return (area / 2).abs();
  }
}

class CornersPainter extends CustomPainter {
  final Size imageSize;

  // ignore: library_private_types_in_public_api
  final List<_BarcodeRect> barcodeRects;

  CornersPainter({
    required this.imageSize,
    required this.barcodeRects,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < barcodeRects.length; i++) {
      final barcodeRect = barcodeRects[i];
      final corners = barcodeRect.corners;
      final paint = Paint()
        ..color = barcodeRect.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      final path = Path()
        ..moveTo(
          corners[0].dx - 3.5,
          corners[0].dy,
        )
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..lineTo(
          corners[0].dx,
          corners[0].dy - 3.5,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _BarcodeRect {
  final Color color;
  final Barcode barcode;
  final List<Offset> corners;

  _BarcodeRect({
    required this.color,
    required this.corners,
    required this.barcode,
  });
}
