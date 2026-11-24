import 'dart:async';

import 'package:prize_bond_checking_app/models/bond_check_result.dart';
import 'package:prize_bond_checking_app/services/bond_checking_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/widgets/bond_number_extractor.dart';
import 'package:prize_bond_checking_app/widgets/input_image_converter.dart';

class BondScanResult {
  const BondScanResult({required this.number, required this.denomination, this.check});

  final String number;
  final String denomination;
  final BondCheckResult? check;
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.initialDenomination, this.captureOnly = false});

  final String? initialDenomination;
  final bool captureOnly;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

enum _ScanPhase { idle, starting, scanning, checking }

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  static const _frameThrottle = Duration(milliseconds: 300);
  // The installed camera plugins share native state even between scanner routes.
  static Future<void> _cameraWork = Future.value();

  late final AccountStorage _storage;
  final _checking = BondCheckingService();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  CameraController? _cameraController;
  Future<RecognizedText>? _recognition;
  DateTime? _lastFrameProcessedAt;
  int _attempt = 0;
  bool _foreground = true;
  bool _leaving = false;
  bool _isFlashOn = false;
  var _phase = _ScanPhase.idle;
  String? _errorMessage;
  late String _selectedDenomination;
  BondScanResult? _scanResult;

  bool get _isScanning => _phase == _ScanPhase.scanning;
  bool get _isInitializingCamera => _phase == _ScanPhase.starting;
  bool get _isChecking => _phase == _ScanPhase.checking;

  @override
  void initState() {
    super.initState();
    _storage = AuthService.requireStorage();
    _selectedDenomination = widget.initialDenomination ?? AppConfig.defaultDenomination;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  bool _isCurrent(int attempt) => mounted && !_leaving && attempt == _attempt && AuthService.canUseStorage(_storage);

  static Future<void> _withCamera(Future<void> Function() operation) {
    final next = _cameraWork.then((_) => operation());
    _cameraWork = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        debugPrint('Camera operation failed (${error.runtimeType}).');
      },
    );
    return _cameraWork;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leave();
    unawaited(_closeRecognizer());
    super.dispose();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    _attempt++;
    unawaited(_withCamera(_closeCamera));
  }

  Future<void> _closeRecognizer() async {
    try {
      await _recognition;
    } catch (_) {
      // The frame handler already handles recognition errors.
    }
    try {
      await _textRecognizer.close();
    } catch (error) {
      debugPrint('Could not close text recognition (${error.runtimeType}).');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      final attempt = _attempt;
      // Permission prompts can leave an initialized camera waiting for the app to become active.
      if (_isInitializingCamera && _cameraController?.value.isInitialized == true) {
        unawaited(_withCamera(() => _startStream(attempt)));
      }
      return;
    }

    // The first camera permission prompt may make the app inactive during initialization.
    if (state == AppLifecycleState.inactive && _isInitializingCamera && _cameraController?.value.isInitialized != true) {
      return;
    }
    if (_phase != _ScanPhase.idle) {
      _stopScanning();
    }
  }

  Future<void> _startScanning() async {
    if (_phase != _ScanPhase.idle || !_foreground || !_isCurrent(_attempt)) return;

    final attempt = ++_attempt;
    setState(() {
      _phase = _ScanPhase.starting;
      _errorMessage = null;
      _scanResult = null;
      _lastFrameProcessedAt = null;
    });

    await _withCamera(() async {
      if (!_isCurrent(attempt)) return;
      try {
        final cameras = await availableCameras();
        if (!_isCurrent(attempt)) return;
        if (cameras.isEmpty) {
          _failScan(attempt, 'No camera was found on this device.');
          return;
        }

        final camera = cameras.firstWhere((item) => item.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
        final controller = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: defaultTargetPlatform == TargetPlatform.android ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );
        _cameraController = controller;
        controller.addListener(() {
          if (controller.value.hasError) _failScan(attempt, 'The camera stopped unexpectedly. Please scan again.');
        });
        await controller.initialize();

        if (!_isCurrent(attempt)) {
          await _closeCamera();
          return;
        }
        await _startStream(attempt);
      } on CameraException catch (error) {
        _failScan(attempt, _cameraErrorMessage(error));
      } catch (_) {
        _failScan(attempt, 'Failed to initialize the camera. Please try again.');
      }
    });
  }

  String _cameraErrorMessage(CameraException error) => switch (error.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' => 'Camera permission was denied. Enable it in your device settings to scan your bond.',
    'cameraNotFound' => 'No usable camera was found on this device.',
    _ => 'Unable to access the camera. Please try again.',
  };

  Future<void> _startStream(int attempt) async {
    final controller = _cameraController;
    if (controller == null || !_foreground || !_isCurrent(attempt) || !_isInitializingCamera) return;
    try {
      // Some cameras do not support focus or torch control, but can still scan.
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      if (!_foreground || !_isCurrent(attempt)) return;
      try {
        await controller.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      } catch (_) {}
      if (!_foreground || !_isCurrent(attempt)) return;
      if (!controller.supportsImageStreaming()) {
        _failScan(attempt, 'This camera cannot stream images for scanning.');
        return;
      }
      await _listenForFrames(controller, attempt);
      if (_foreground && _isCurrent(attempt)) setState(() => _phase = _ScanPhase.scanning);
    } catch (_) {
      _failScan(attempt, 'Could not start the camera stream. Please try again.');
    }
  }

  Future<void> _listenForFrames(CameraController controller, int attempt) {
    final started = Completer<void>();
    final appZone = Zone.current;
    // Both mobile plugins can fail in an asynchronous stream onListen callback.
    // Keep those errors in this attempt, and deliver frame handling back to the app's zone.
    runZonedGuarded(() async {
      try {
        await controller.startImageStream((image) {
          appZone.run(() => unawaited(_processCameraImage(image, controller, attempt)));
        });
        started.complete();
      } catch (error, stackTrace) {
        started.completeError(error, stackTrace);
      }
    }, (error, _) => _failScan(attempt, 'The camera stream stopped. Please try again.'));
    return started.future;
  }

  Future<void> _closeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
    } catch (error) {
      debugPrint('Could not stop the camera stream (${error.runtimeType}).');
    } finally {
      try {
        await controller.dispose();
      } catch (error) {
        debugPrint('Could not release the camera (${error.runtimeType}).');
      }
    }
  }

  void _stopScanning() {
    _attempt++;
    setState(() => _phase = _ScanPhase.idle);
    unawaited(_withCamera(_closeCamera));
  }

  void _failScan(int attempt, String message) {
    if (!_isCurrent(attempt)) return;
    setState(() => _errorMessage = message);
    _stopScanning();
  }

  Future<void> _processCameraImage(CameraImage image, CameraController controller, int attempt) async {
    if (!_foreground || !_isCurrent(attempt) || !_isScanning || _recognition != null) return;

    final now = DateTime.now();
    final lastFrame = _lastFrameProcessedAt;
    if (lastFrame != null && now.difference(lastFrame) < _frameThrottle) return;
    _lastFrameProcessedAt = now;

    final input = InputImageConverter.fromCameraImage(
      image: image,
      controller: controller,
      cameraDescription: controller.description,
    );
    if (input == null) {
      _failScan(attempt, 'The camera sent an unsupported image. Please scan again.');
      return;
    }

    String? number;
    try {
      final recognition = _textRecognizer.processImage(input);
      _recognition = recognition;
      number = BondNumberExtractor.extract((await recognition).text);
    } catch (_) {
      _failScan(attempt, 'Could not read the bond number. Please scan again.');
    } finally {
      _recognition = null;
    }

    if (number != null && _foreground && _isCurrent(attempt)) {
      await _finishScan(number, _selectedDenomination, attempt);
    }
  }

  Future<void> _finishScan(String number, String denomination, int attempt) async {
    setState(() => _phase = _ScanPhase.checking);
    await _withCamera(_closeCamera);
    if (!_foreground || !_isCurrent(attempt)) return;

    try {
      final check = widget.captureOnly ? null : await _checking.check(_storage, number, denomination);
      if (!_foreground || !_isCurrent(attempt)) return;
      setState(() {
        _scanResult = BondScanResult(number: number, denomination: denomination, check: check);
        _phase = _ScanPhase.idle;
      });
    } catch (_) {
      _failScan(attempt, 'Could not save the check. Please scan again.');
    }
  }

  Future<void> _toggleFlash() async {
    final attempt = _attempt;
    if (!_foreground || !_isCurrent(attempt)) return;
    final newValue = !_isFlashOn;
    if (_cameraController == null) {
      setState(() => _isFlashOn = newValue);
      return;
    }
    await _withCamera(() async {
      final controller = _cameraController;
      if (controller == null || !_foreground || !_isCurrent(attempt)) return;
      try {
        await controller.setFlashMode(newValue ? FlashMode.torch : FlashMode.off);
        if (_foreground && _isCurrent(attempt)) setState(() => _isFlashOn = newValue);
      } catch (_) {
        if (_foreground && _isCurrent(attempt)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flash is unavailable on this camera.')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<BondScanResult>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Scan Prize Bond', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
              onPressed: _toggleFlash,
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDenominationPicker(),
                      const SizedBox(height: 16),
                      Container(
                        width: 300,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: _isScanning ? const Color(0xFF2D5BFF) : Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: (_isScanning || _isInitializingCamera || _errorMessage != null)
                              ? _buildScanningView()
                              : const Center(child: Icon(Icons.document_scanner_outlined, size: 80, color: Colors.white54)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _errorMessage ??
                            (_isScanning ? 'Point at the bond number to scan...' : 'Position bond number within frame'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      if (_isScanning) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _stopScanning,
                          icon: const Icon(Icons.stop_circle_outlined, color: Colors.white60),
                          label: const Text('Cancel Scan', style: TextStyle(color: Colors.white60)),
                        ),
                      ],
                      if (_scanResult != null) ...[const SizedBox(height: 24), _buildResultCard()],
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(bottom: 40, left: 0, right: 0, child: Center(child: _buildBottomAction())),
          ],
        ),
      ),
    );
  }

  Widget _buildDenominationPicker() {
    final locked = _isScanning || _isInitializingCamera || _isChecking || _scanResult != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_outlined, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(widget.captureOnly ? 'Denomination:' : 'Checking:', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: _selectedDenomination,
            dropdownColor: const Color(0xFF1F2937),
            underline: const SizedBox.shrink(),
            iconEnabledColor: Colors.white70,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            items: AppConfig.denominations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: locked
                ? null
                : (val) {
                    if (val != null) setState(() => _selectedDenomination = val);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildScanningView() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    final controller = _cameraController;
    if (_isInitializingCamera || controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth * controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final scan = _scanResult!;
    final result = scan.check;
    final win = result?.win;
    return switch (result?.outcome) {
      BondCheckOutcome.win => _resultContainer(
        color: const Color(0xFF10B981),
        icon: Icons.emoji_events,
        title: '🎉 This Bond Won!',
        number: result!.number,
        subtitleLines: [
          '${win!.position} • ${win.amount}',
          'Draw #${win.drawNumber} • ${win.drawDate}',
          AppConfig.simulatedResultsLabel,
        ],
      ),
      BondCheckOutcome.noWin || BondCheckOutcome.resultsUnavailable => _resultContainer(
        color: const Color(0xFF92400E),
        icon: Icons.info_outline,
        title: result!.outcome.label,
        number: result.number,
        subtitleLines: [AppConfig.simulatedResultsLabel, result.coverage.summary],
      ),
      null => _resultContainer(
        color: const Color(0xFF2D5BFF),
        icon: Icons.check_circle_outline,
        title: 'Number captured',
        number: scan.number,
        subtitleLines: [scan.denomination],
      ),
    };
  }

  Widget _resultContainer({
    required Color color,
    required IconData icon,
    required String title,
    required String number,
    required List<String> subtitleLines,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          for (final line in subtitleLines) ...[
            const SizedBox(height: 6),
            Text(
              line,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final scan = _scanResult;
    if (scan == null) {
      final busy = _isScanning || _isInitializingCamera || _isChecking;
      final label = _isChecking
          ? 'Checking...'
          : _isInitializingCamera
          ? 'Starting camera...'
          : _isScanning
          ? 'Scanning...'
          : 'Scan Now';
      return FloatingActionButton.extended(
        onPressed: busy ? null : _startScanning,
        backgroundColor: Colors.white,
        icon: Icon(busy ? Icons.hourglass_empty : Icons.camera),
        label: Text(label),
      );
    }

    return ElevatedButton(
      onPressed: () {
        if (_foreground && _isCurrent(_attempt)) Navigator.pop(context, scan);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(widget.captureOnly ? 'Use scanned number' : 'Back', style: const TextStyle(color: Colors.white)),
    );
  }
}
