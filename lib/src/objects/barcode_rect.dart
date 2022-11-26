import 'dart:ui';

import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeRect {
  final List<Barcode> Function(List<Barcode>)? selectedBarcodes;
  final Color? selectedRectColor;
  final Color? rectColor;
  final void Function(Barcode)? onRectTap;

  BarcodeRect({
    this.selectedBarcodes,
    this.selectedRectColor,
    this.rectColor,
    this.onRectTap,
  });
}
