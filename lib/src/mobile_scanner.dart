import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/corners/corners_paint.dart';
import 'package:mobile_scanner/src/scan_window_calculation.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// The function signature for the error builder.
typedef MobileScannerErrorBuilder = Widget Function(
  BuildContext,
  MobileScannerException,
  Widget?,
);

/// The [MobileScanner] widget displays a live camera preview.
class MobileScanner extends StatefulWidget {
  /// The controller that manages the barcode scanner.
  ///
  /// If this is null, the scanner will manage its own controller.
  final MobileScannerController? controller;

  /// The function that builds an error widget when the scanner
  /// could not be started.
  ///
  /// If this is null, defaults to a black [ColoredBox]
  /// with a centered white [Icons.error] icon.
  final MobileScannerErrorBuilder? errorBuilder;

  /// The [BoxFit] for the camera preview.
  ///
  /// Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// The function that signals when new codes were detected by the [controller].
  final void Function(BarcodeCapture barcodes)? onDetect;

  /// The function that signals when the barcode scanner is started.
  final void Function(MobileScannerArguments? arguments)? onScannerStarted;

  /// The function that builds a placeholder widget when the scanner
  /// is not yet displaying its camera preview.
  ///
  /// If this is null, a black [ColoredBox] is used as placeholder.
  final Widget Function(BuildContext, Widget?)? placeholderBuilder;

  /// if set barcodes will only be scanned if they fall within this [Rect]
  /// useful for having a cut-out overlay for example. these [Rect]
  /// coordinates are relative to the widget size, so by how much your
  /// rectangle overlays the actual image can depend on things like the
  /// [BoxFit]
  final Rect? scanWindow;

  final bool autoDisposeController;
  final bool autoStart;
  final bool autoStop;
  final BarcodeRect? barcodeRect;

  /// Only set this to true if you are starting another instance of mobile_scanner
  /// right after disposing the first one, like in a PageView.
  ///
  /// Default: false
  final bool startDelay;

  /// The overlay which will be painted above the scanner when has started successful.
  /// Will no be pointed when an error occurs or the scanner hasn't been started yet.
  final Widget? overlay;

  /// Create a new [MobileScanner] using the provided [controller]
  /// and [onBarcodeDetected] callback.
  const MobileScanner({
    this.controller,
    this.errorBuilder,
    this.fit = BoxFit.cover,
    this.onDetect,
    this.onScannerStarted,
    this.placeholderBuilder,
    this.scanWindow,
    this.autoDisposeController = true,
    this.autoStart = true,
    this.autoStop = true,
    this.barcodeRect,
    this.startDelay = false,
    this.overlay,
    super.key,
  });

  @override
  State<MobileScanner> createState() => _MobileScannerState();
}

class _MobileScannerState extends State<MobileScanner>
    with WidgetsBindingObserver {
  /// The subscription that listens to barcode detection.
  StreamSubscription<BarcodeCapture>? _barcodesSubscription;

  /// The internally managed controller.
  late MobileScannerController _controller;

  /// Whether the controller should resume
  /// when the application comes back to the foreground.
  bool _resumeFromBackground = false;

  MobileScannerException? _startException;

  Widget _buildPlaceholderOrError(BuildContext context, Widget? child) {
    final error = _startException;

    if (error != null) {
      return widget.errorBuilder?.call(context, error, child) ??
          const ColoredBox(
            color: Colors.black,
            child: Center(child: Icon(Icons.error, color: Colors.white)),
          );
    }

    return widget.placeholderBuilder?.call(context, child) ??
        const ColoredBox(color: Colors.black);
  }

  /// Start the given [scanner].
  Future<void> _startScanner() async {
    try {
      _startException = null;
      final arguments = await _controller.start();
      widget.onScannerStarted?.call(arguments);
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (error is MobileScannerException) {
        _startException = error;
      } else if (error is PlatformException) {
        _startException = MobileScannerException(
          errorCode: MobileScannerErrorCode.genericError,
          errorDetails: MobileScannerErrorDetails(
            code: error.code,
            message: error.message,
            details: error.details,
          ),
        );
      } else {
        _startException = MobileScannerException(
          errorCode: MobileScannerErrorCode.genericError,
          errorDetails: MobileScannerErrorDetails(
            details: error,
          ),
        );
      }

      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.controller ?? MobileScannerController();

    _barcodesSubscription = _controller.barcodes.listen(
      widget.onDetect,
    );

    if (!_controller.isStarting && _controller.autoStart && widget.autoStart) {
      _startScanner();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_resumeFromBackground) {
          _startScanner();
        }
        break;
      case AppLifecycleState.paused:
        _controller.isStarted().then((isStarted) {
          _resumeFromBackground = isStarted;
        });
        _controller.stop();
        break;
      default:
        break;
    }
  }

  Rect? scanWindow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ValueListenableBuilder<MobileScannerArguments?>(
          valueListenable: _controller.startArguments,
          builder: (context, value, child) {
            if (value == null) {
              return _buildPlaceholderOrError(context, child);
            }

            if (widget.scanWindow != null && scanWindow == null) {
              scanWindow = calculateScanWindowRelativeToTextureInPercentage(
                widget.fit,
                widget.scanWindow!,
                textureSize: value.size,
                widgetSize: constraints.biggest,
              );

              _controller.updateScanWindow(scanWindow);
            }
            if (widget.overlay != null) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  _scanner(
                    value.size,
                    value.webId,
                    value.textureId,
                    value.numberOfCameras,
                  ),
                  widget.overlay!,
                ],
              );
            } else {
              return _scanner(
                value.size,
                value.webId,
                value.textureId,
                value.numberOfCameras,
              );
            }
          },
        );
      },
    );
  }

  Widget _scanner(
    Size size,
    String? webId,
    int? textureId,
    int? numberOfCameras,
  ) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (_, constraints) {
          return SizedBox.fromSize(
            size: constraints.biggest,
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: kIsWeb
                    ? HtmlElementView(viewType: webId!)
                    : StreamBuilder<NativeDeviceOrientation>(
                        stream: NativeDeviceOrientationCommunicator()
                            .onOrientationChanged(),
                        builder: (_, snapshot) {
                          final orientation = snapshot.data;
                          return Transform.rotate(
                            angle: () {
                                  switch (orientation) {
                                    case NativeDeviceOrientation.portraitUp:
                                      return 0;
                                    case NativeDeviceOrientation.portraitDown:
                                      return 180;
                                    case NativeDeviceOrientation.landscapeLeft:
                                      return -90;
                                    case NativeDeviceOrientation.landscapeRight:
                                      return 90;
                                    case NativeDeviceOrientation.unknown:
                                      return 0;
                                    case null:
                                      return 0;
                                  }
                                }() *
                                math.pi /
                                180,
                            child: CornersPaint(
                              barcodeCapture: _controller.barcodes,
                              barcodeRect: widget.barcodeRect,
                              previewSize: size,
                              child: Texture(
                                textureId: textureId!,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.updateScanWindow(null);
    WidgetsBinding.instance.removeObserver(this);
    _barcodesSubscription?.cancel();
    _barcodesSubscription = null;
    if (widget.autoDisposeController) {
      _controller.dispose();
    } else if (widget.autoStop) {
      _controller.stop();
    }
    super.dispose();
  }
}
