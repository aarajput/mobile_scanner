import 'dart:ui';

import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeRect {
  final List<String> selectedBarcodes;
  final Color? selectedRectColor;
  final Color? rectColor;
  final void Function(Barcode)? onRectTap;

  BarcodeRect({
    required this.selectedBarcodes,
    this.selectedRectColor,
    this.rectColor,
    this.onRectTap,
  });
}
