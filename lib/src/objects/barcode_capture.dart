import 'dart:typed_data';
import 'dart:ui';

import 'package:mobile_scanner/src/objects/barcode.dart';

/// The return object after a frame is scanned.
///
/// [barcodes] A list with barcodes. A scanned frame can contain multiple
/// barcodes.
/// [image] If enabled, an image of the scanned frame.
class BarcodeCapture {
  final List<Barcode> barcodes;

  final Uint8List? image;

  final Size? imageSize;

  BarcodeCapture({
    required this.barcodes,
    required this.imageSize,
    this.image,
  });
}
