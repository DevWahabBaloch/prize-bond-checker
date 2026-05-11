import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = false;
  String? _scannedNumber;
  bool _isFlashOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    _controller.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _scannedNumber = null;
    });
  }

  void _stopScanning() {
    _controller.stop();
    setState(() => _isScanning = false);
  }

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 300,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: _isScanning ? const Color(0xFF2D5BFF) : Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _isScanning
                          ? _buildScanningView()
                          : const Center(child: Icon(Icons.qr_code_scanner, size: 80, color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isScanning ? 'Point at bond number to scan...' : 'Position bond number within frame',
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
                  if (_scannedNumber != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'Bond Scanned Successfully!',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _scannedNumber!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _scannedNumber == null
                  ? FloatingActionButton.extended(
                      onPressed: _isScanning ? null : _startScanning,
                      backgroundColor: Colors.white,
                      icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.camera),
                      label: Text(_isScanning ? 'Scanning...' : 'Scan Now'),
                    )
                  : ElevatedButton(
                      onPressed: () => Navigator.pop(context, _scannedNumber),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Use This Number', style: TextStyle(color: Colors.white)),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningView() {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        final barcode = capture.barcodes.firstOrNull;
        if (barcode?.rawValue == null) return;

        final raw = barcode!.rawValue!;
        final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');

        if (digitsOnly.length >= 6) {
          _controller.stop();
          setState(() {
            _isScanning = false;
            _scannedNumber = digitsOnly.substring(0, 6);
          });
        }
      },
    );
  }
}
