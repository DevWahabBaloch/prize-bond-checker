import 'package:flutter/widgets.dart';

class IosPrivacyCover {
  static final _proofPattern = RegExp(r'^[89ab][a-f0-9]{15}$');

  int _latestGeneration = 0;
  String? _proof;

  String? get proof => _proof;

  bool request(int generation, String proof) {
    if (generation <= _latestGeneration || !_proofPattern.hasMatch(proof)) return false;
    _latestGeneration = generation;
    _proof = proof;
    return true;
  }

  bool presentationConfirmed(int generation) {
    if (generation != _latestGeneration || _proof == null) return false;
    _proof = null;
    return true;
  }
}

/// Only this opaque, non-sensitive frame is rendered during the native handoff.
class IosPrivacyFrame extends StatelessWidget {
  const IosPrivacyFrame({required this.proof, super.key});

  final String proof;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ProofPainter(proof));
}

class _ProofPainter extends CustomPainter {
  _ProofPainter(this.proof);

  final String proof;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    final left = size.width / 8;
    final barWidth = size.width * 0.75 / 64;
    final top = size.height * 0.4975;
    final barHeight = size.height * 0.005;
    final paint = Paint()..isAntiAlias = false;
    // SceneDelegate samples the center of each bar in the presented IOSurface.
    for (var i = 0; i < 64; i++) {
      final digit = int.parse(proof[i ~/ 4], radix: 16);
      final isWhite = digit & (1 << (3 - i % 4)) != 0;
      paint.color = isWhite ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
      canvas.drawRect(Rect.fromLTWH(left + i * barWidth, top, barWidth, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(_ProofPainter oldDelegate) => oldDelegate.proof != proof;
}
