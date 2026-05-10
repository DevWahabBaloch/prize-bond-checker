import 'package:flutter/material.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;
  String? _scannedNumber;
  bool _isFlashOn = false;

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _scannedNumber = null;
    });
    // TODO: Integrate real camera/OCR scanning (e.g., mobile_scanner or camera plugin)
    // On successful scan, call _onScanSuccess(scannedNumber)
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
                  // Scanner viewfinder box
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
                    _isScanning ? 'Scanning...' : 'Position bond number within frame',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
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

          // Bottom button
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
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF2D5BFF)),
            SizedBox(height: 16),
            Text('Camera initializing...', style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 8),
            Text('Point at bond number', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
