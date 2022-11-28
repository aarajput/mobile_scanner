import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/src/corners/corners_paint.dart';
import 'package:mobile_scanner/src/mobile_scanner_controller.dart';
import 'package:mobile_scanner/src/objects/barcode_capture.dart';
import 'package:mobile_scanner/src/objects/barcode_rect.dart';
import 'package:mobile_scanner/src/objects/mobile_scanner_arguments.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

typedef MobileScannerCallback = void Function(BarcodeCapture barcodes);
typedef MobileScannerArgumentsCallback = void Function(
  MobileScannerArguments? arguments,
);

/// A widget showing a live camera preview.
class MobileScanner extends StatefulWidget {
  /// The controller of the camera.
  final MobileScannerController? controller;

  /// Calls the provided [onPermissionSet] callback when the permission is set.
  // @Deprecated('Use the [onPermissionSet] paremeter in the [MobileScannerController] instead.')
  // ignore: deprecated_consistency
  final Function(bool permissionGranted)? onPermissionSet;

  /// Function that gets called when a Barcode is detected.
  ///
  /// [barcode] The barcode object with all information about the scanned code.
  /// [startInternalArguments] Information about the state of the MobileScanner widget
  final MobileScannerCallback? onDetect;

  /// Function that gets called when the scanner is started.
  ///
  /// [arguments] The start arguments of the scanner. This contains the size of
  /// the scanner which can be used to draw a box over the scanner.
  final MobileScannerArgumentsCallback? onStart;

  /// Handles how the widget should fit the screen.
  final BoxFit fit;

  /// Whether to automatically resume the camera when the application is resumed
  final bool autoResume;

  final BarcodeRect? barcodeRect;

  /// Create a [MobileScanner] with a [controller], the [controller] must has been initialized.
  const MobileScanner({
    super.key,
    this.onDetect,
    this.onStart,
    this.controller,
    this.autoResume = true,
    this.fit = BoxFit.cover,
    this.barcodeRect,
    @Deprecated('Use the [onPermissionSet] paremeter in the [MobileScannerController] instead.')
        this.onPermissionSet,
  });

  @override
  State<MobileScanner> createState() => _MobileScannerState();
}

class _MobileScannerState extends State<MobileScanner>
    with WidgetsBindingObserver {
  late MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = widget.controller ??
        MobileScannerController(onPermissionSet: widget.onPermissionSet);
    if (!controller.isStarting) {
      _startScanner();
    }
  }

  Future<void> _startScanner() async {
    final arguments = await controller.start();
    widget.onStart?.call(arguments);
  }

  bool resumeFromBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before it is initialized.
    if (controller.isStarting) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        resumeFromBackground = false;
        _startScanner();
        break;
      case AppLifecycleState.paused:
        resumeFromBackground = true;
        break;
      case AppLifecycleState.inactive:
        if (!resumeFromBackground) controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.startArguments,
      builder: (context, value, child) {
        value = value as MobileScannerArguments?;
        if (value == null) {
          return const ColoredBox(color: Colors.black);
        } else {
          controller.barcodes.listen((barcode) {
            widget.onDetect?.call(barcode);
          });
          return ClipRect(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: FittedBox(
                fit: widget.fit,
                child: SizedBox(
                  width: value.size.width,
                  height: value.size.height,
                  child: kIsWeb
                      ? HtmlElementView(viewType: value.webId!)
                      : StreamBuilder<NativeDeviceOrientation>(
                          stream: NativeDeviceOrientationCommunicator()
                              .onOrientationChanged(),
                          builder: (_, snapshot) {
                            final v = value as MobileScannerArguments?;
                            final orientation = snapshot.data;
                            if (v == null || orientation == null) {
                              return const ColoredBox(color: Colors.black);
                            }
                            return Transform.rotate(
                              angle: () {
                                    switch (orientation) {
                                      case NativeDeviceOrientation.portraitUp:
                                        return 0;
                                      case NativeDeviceOrientation.portraitDown:
                                        return 180;
                                      case NativeDeviceOrientation
                                          .landscapeLeft:
                                        return -90;
                                      case NativeDeviceOrientation
                                          .landscapeRight:
                                        return 90;
                                      case NativeDeviceOrientation.unknown:
                                        return 0;
                                    }
                                  }() *
                                  math.pi /
                                  180,
                              child: CornersPaint(
                                barcodeCapture: controller.barcodes,
                                barcodeRect: widget.barcodeRect,
                                previewSize: v.size,
                                child: Texture(
                                  textureId: v.textureId!,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant MobileScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == null) {
      if (widget.controller != null) {
        controller.dispose();
        controller = widget.controller!;
      }
    } else {
      if (widget.controller == null) {
        controller =
            MobileScannerController(onPermissionSet: widget.onPermissionSet);
      } else if (oldWidget.controller != widget.controller) {
        controller = widget.controller!;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
