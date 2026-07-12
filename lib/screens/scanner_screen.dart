import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:prize_bond_checking_app/widgets/bond_number_extractor.dart';
import 'package:prize_bond_checking_app/widgets/input_image_converter.dart';

/// Result of checking a scanned bond number against completed draws.
enum _BondCheckStatus { won, lost, invalid }

/// Real-time OCR scanner for 6-digit Pakistan Prize Bond numbers.
///
/// The camera preview streams frames continuously; frames are throttled
/// and run through Google ML Kit text recognition until a valid 6-digit
/// number is found. As soon as a number is detected, it is immediately
/// checked against completed draws (for the selected denomination) and
/// the result — Won / No Win / Wrong Number — is shown right here,
/// before the caller even receives the scanned value back.
class ScannerScreen extends StatefulWidget {
  /// Optional denomination to check against. If the calling screen
  /// already has one selected (e.g. Check Bond screen), pass it in so
  /// the scanner checks against the right draw set. Defaults to
  /// 'Rs. 1500' if not provided; the user can still change it on this
  /// screen via the denomination picker.
  final String? initialDenomination;

  const ScannerScreen({super.key, this.initialDenomination});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  // --- Camera / OCR state -------------------------------------------------
  List<CameraDescription>? _cameras;
  CameraDescription? _backCamera;
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Throttle: only process one frame per this interval, so OCR doesn't
  /// run on every single camera frame (which would lag the UI).
  static const Duration _frameThrottle = Duration(milliseconds: 300);
  DateTime? _lastFrameProcessedAt;

  /// Guards against overlapping OCR calls while one frame is still
  /// being processed.
  bool _isProcessingFrame = false;

  /// Set the instant a valid bond number is found, so any in-flight or
  /// queued frame callbacks become no-ops (scan-once behaviour).
  bool _isDetected = false;

  // --- UI state (kept from the original implementation) ------------------
  bool _isScanning = false;
  bool _isInitializingCamera = false;
  String? _scannedNumber;
  bool _isFlashOn = false;
  String? _errorMessage;

  // --- Win/loss checking state --------------------------------------------
  final DrawService _drawService = DrawService();
  late String _selectedDenomination;
  _BondCheckStatus? _checkStatus;
  DrawResult? _matchedDraw;

  static const List<String> _denominations = [
    'Rs. 100',
    'Rs. 200',
    'Rs. 750',
    'Rs. 1500',
    'Rs. 7500',
    'Rs. 15000',
    'Rs. 25000',
    'Rs. 40000',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDenomination = widget.initialDenomination ?? 'Rs. 1500';
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
      controller.dispose();
    }
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopImageStream();
    } else if (state == AppLifecycleState.resumed && _isScanning && !_isDetected) {
      _startImageStream();
    }
  }

  // ---------------------------------------------------------------------
  // Camera lifecycle
  // ---------------------------------------------------------------------

  Future<bool> _ensureCameraInitialized() async {
    final existing = _cameraController;
    if (existing != null && existing.value.isInitialized) {
      return true;
    }

    try {
      _cameras ??= await availableCameras();
      final cameras = _cameras;
      if (cameras == null || cameras.isEmpty) {
        _setError('No camera was found on this device.');
        return false;
      }

      _backCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);

      final controller = CameraController(
        _backCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        // Single-plane formats keep the InputImage conversion simple
        // and fast: nv21 on Android, bgra8888 on iOS.
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();

      // Continuous autofocus so the user never has to tap the screen.
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {
        // Not all devices support programmatic focus mode changes.
      }

      try {
        await controller.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      } catch (_) {
        // Some devices (or the front camera) don't support flash.
      }

      _cameraController = controller;
      return true;
    } on CameraException catch (e) {
      debugPrint(
        'CameraException while initializing camera: '
        '${e.code} — ${e.description}',
      );
      _setError(_cameraErrorMessage(e));
      return false;
    } catch (e, stackTrace) {
      debugPrint('Unexpected error while initializing camera: $e');
      debugPrint('$stackTrace');
      _setError(
        'Failed to initialize the camera. Please try again.\n'
        '(${e.runtimeType})',
      );
      return false;
    }
  }

  String _cameraErrorMessage(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission was denied. Please enable it in your '
            'device Settings to scan your bond.';
      case 'cameraNotFound':
        return 'No usable camera was found on this device.';
      default:
        return 'Unable to access the camera. Please try again.';
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;
    await controller.startImageStream(_processCameraImage);
  }

  Future<void> _stopImageStream() async {
    final controller = _cameraController;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  // ---------------------------------------------------------------------
  // OCR pipeline
  // ---------------------------------------------------------------------

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isScanning || _isDetected || _isProcessingFrame) return;

    final now = DateTime.now();
    if (_lastFrameProcessedAt != null && now.difference(_lastFrameProcessedAt!) < _frameThrottle) {
      return;
    }
    _lastFrameProcessedAt = now;

    _isProcessingFrame = true;
    try {
      final controller = _cameraController;
      final backCamera = _backCamera;
      if (controller == null || backCamera == null) return;

      final inputImage = InputImageConverter.fromCameraImage(image: image, controller: controller, cameraDescription: backCamera);
      if (inputImage == null) return;

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final bondNumber = BondNumberExtractor.extract(recognizedText.text);
      if (bondNumber != null) {
        await _handleBondNumberDetected(bondNumber);
      }
    } catch (e) {
      debugPrint('OCR frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _handleBondNumberDetected(String number) async {
    if (_isDetected) return; // Already handled by another in-flight frame.
    _isDetected = true;

    await _stopImageStream();
    if (!mounted) return;

    setState(() => _isScanning = false);

    await _evaluateAndRecordBond(number);
  }

  // ---------------------------------------------------------------------
  // Win / loss / invalid checking
  // ---------------------------------------------------------------------

  /// Very small sanity check to catch obvious OCR misreads that still
  /// happen to be 6 digits (e.g. picking up noise/borders as
  /// "000000" or "111111"). Real printed bond numbers won't look like
  /// this, so we flag it instead of silently treating it as "No Win".
  bool _looksLikeInvalidNumber(String number) {
    if (number.length != 6) return true;
    return RegExp(r'^(\d)\1{5}$').hasMatch(number); // all 6 digits identical
  }

  Future<void> _evaluateAndRecordBond(String number) async {
    if (_looksLikeInvalidNumber(number)) {
      if (!mounted) return;
      setState(() {
        _scannedNumber = number;
        _checkStatus = _BondCheckStatus.invalid;
        _matchedDraw = null;
      });
      return;
    }

    final result = _drawService.checkBond(number, _selectedDenomination);

    try {
      if (Hive.isBoxOpen('check_history')) {
        final record = CheckRecord()
          ..bondNumber = number
          ..denomination = _selectedDenomination
          ..checkedAt = DateTime.now()
          ..resultStatus = result != null ? 'Won' : 'No Win'
          ..drawNumber = result?.drawNumber ?? 'N/A'
          ..drawDate = result?.drawDate ?? 'N/A';
        await Hive.box<CheckRecord>('check_history').add(record);
      }
    } catch (e) {
      debugPrint('Failed to save scan result to check history: $e');
    }

    if (result != null) {
      try {
        await NotificationService().showWinNotification(
          bondNumber: number,
          denomination: _selectedDenomination,
          city: result.city,
        );
      } catch (e) {
        debugPrint('Failed to show win notification: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _scannedNumber = number;
      _checkStatus = result != null ? _BondCheckStatus.won : _BondCheckStatus.lost;
      _matchedDraw = result;
    });
  }

  // ---------------------------------------------------------------------
  // User actions
  // ---------------------------------------------------------------------

  Future<void> _startScanning() async {
    if (_isScanning || _isInitializingCamera) return;

    setState(() {
      _errorMessage = null;
      _scannedNumber = null;
      _checkStatus = null;
      _matchedDraw = null;
      _isDetected = false;
      _isInitializingCamera = true;
    });

    final initialized = await _ensureCameraInitialized();
    if (!mounted) return;

    if (!initialized) {
      setState(() => _isInitializingCamera = false);
      return;
    }

    await _startImageStream();
    if (!mounted) return;

    setState(() {
      _isInitializingCamera = false;
      _isScanning = true;
    });
  }

  Future<void> _stopScanning() async {
    await _stopImageStream();
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  void _resetAndRescan() {
    setState(() {
      _scannedNumber = null;
      _checkStatus = null;
      _matchedDraw = null;
      _isDetected = false;
    });
    _startScanning();
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    final newValue = !_isFlashOn;

    if (controller == null || !controller.value.isInitialized) {
      setState(() => _isFlashOn = newValue);
      return;
    }

    try {
      await controller.setFlashMode(newValue ? FlashMode.torch : FlashMode.off);
      setState(() => _isFlashOn = newValue);
    } catch (e) {
      debugPrint('Unable to toggle flash: $e');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isScanning = false;
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    if (_scannedNumber != null) ...[const SizedBox(height: 24), _buildResultCard()],
                    const SizedBox(height: 90), // keeps content clear of the bottom action button
                  ],
                ),
              ),
            ),
          ),
          Positioned(bottom: 40, left: 0, right: 0, child: Center(child: _buildBottomAction())),
        ],
      ),
    );
  }

  Widget _buildDenominationPicker() {
    final locked = _isScanning || _isInitializingCamera;
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
          const Text('Checking:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: _selectedDenomination,
            dropdownColor: const Color(0xFF1F2937),
            underline: const SizedBox.shrink(),
            iconEnabledColor: Colors.white70,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            items: _denominations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
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

  /// Renders either the live camera preview (cropped/covered to fill the
  /// scanning box, same visual footprint as the old MobileScanner view)
  /// or an error/loading state.
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
    switch (_checkStatus) {
      case _BondCheckStatus.won:
        final draw = _matchedDraw;
        final position = draw != null ? _drawService.getPrizePosition(draw, _scannedNumber!) : null;
        final amount = draw != null ? _drawService.getPrizeAmount(draw, _scannedNumber!) : null;
        return _resultContainer(
          color: const Color(0xFF10B981),
          icon: Icons.emoji_events,
          title: '🎉 This Bond Won!',
          number: _scannedNumber!,
          subtitleLines: [
            if (position != null) '$position${amount != null ? ' — $amount' : ''}',
            if (draw != null) 'Draw #${draw.drawNumber} • ${draw.drawDate}',
          ],
        );

      case _BondCheckStatus.lost:
        return _resultContainer(
          color: const Color(0xFFF59E0B),
          icon: Icons.sentiment_neutral_rounded,
          title: 'No Win',
          number: _scannedNumber!,
          subtitleLines: const ['Checked against completed draws — no match found.'],
        );

      case _BondCheckStatus.invalid:
        return _resultContainer(
          color: const Color(0xFFEF4444),
          icon: Icons.error_outline_rounded,
          title: 'Wrong / Unreadable Number',
          number: _scannedNumber!,
          subtitleLines: const ["This doesn't look like a valid bond number. Please rescan."],
        );

      case null:
        return const SizedBox.shrink();
    }
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
    if (_scannedNumber == null) {
      return FloatingActionButton.extended(
        onPressed: (_isScanning || _isInitializingCamera) ? null : _startScanning,
        backgroundColor: Colors.white,
        icon: Icon((_isScanning || _isInitializingCamera) ? Icons.hourglass_empty : Icons.camera),
        label: Text(_isInitializingCamera ? 'Starting camera...' : (_isScanning ? 'Scanning...' : 'Scan Now')),
      );
    }

    if (_checkStatus == _BondCheckStatus.invalid) {
      return ElevatedButton.icon(
        onPressed: _resetAndRescan,
        icon: const Icon(Icons.refresh),
        label: const Text('Scan Again'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D5BFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => Navigator.pop(context, _scannedNumber),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10B981),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Back', style: TextStyle(color: Colors.white)),
    );
  }
}
