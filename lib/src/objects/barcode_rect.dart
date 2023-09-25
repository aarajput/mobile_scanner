import 'dart:ui';

import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeRect {
  final Color? Function(Barcode)? getBarcodeColor;
  final void Function(Barcode)? onRectTap;

  BarcodeRect({
    this.getBarcodeColor,
    this.onRectTap,
  });
}
