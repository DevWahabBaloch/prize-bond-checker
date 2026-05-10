import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/widgets/app_nav_screen.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _enteredPin = '';
  bool _hasError = false;
  String? _savedPin;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await AuthService.getPin();
    setState(() => _savedPin = pin);
  }

  void _onKey(String key) {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += key;
      _hasError = false;
    });

    if (_enteredPin.length == 4) {
      _verify();
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verify() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      final correct = _savedPin ?? '1234';

      if (_enteredPin == correct) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
      } else {
        setState(() {
          _hasError = true;
          _enteredPin = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    // Responsive values
    final horizontalPadding = width * 0.06;
    final keySize = width * 0.2 > 80 ? 80.0 : width * 0.2;
    final spacing = width * 0.03;
    final pinDotSize = width * 0.045;
    final titleSize = width * 0.065;
    final subtitleSize = width * 0.036;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height - MediaQuery.of(context).padding.top),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: height * 0.02),

                  // Logo
                  Container(
                    width: width * 0.22 > 90 ? 90 : width * 0.22,
                    height: width * 0.22 > 90 ? 90 : width * 0.22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF2D5BFF).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Icon(Icons.account_balance_wallet, color: Colors.white, size: width * 0.1),
                  ),

                  SizedBox(height: height * 0.04),

                  // Title
                  Text(
                    'Enter Your PIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                    child: Text(
                      'Enter your 4-digit PIN to access the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: subtitleSize, color: Colors.grey[500]),
                    ),
                  ),

                  SizedBox(height: height * 0.05),

                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _enteredPin.length;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: spacing * 0.5),
                        width: pinDotSize,
                        height: pinDotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _hasError
                              ? Colors.red[400]
                              : filled
                              ? const Color(0xFF2D5BFF)
                              : Colors.transparent,
                          border: Border.all(
                            color: _hasError
                                ? Colors.red[400]!
                                : filled
                                ? const Color(0xFF2D5BFF)
                                : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),

                  if (_hasError) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Incorrect PIN. Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[400], fontSize: width * 0.033, fontWeight: FontWeight.w500),
                    ),
                  ],

                  SizedBox(height: height * 0.05),

                  // Keypad
                  _buildPad(keySize: keySize, spacing: spacing, fontSize: width * 0.06),

                  SizedBox(height: height * 0.03),

                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot PIN?',
                      style: TextStyle(color: Colors.grey[500], fontSize: width * 0.036),
                    ),
                  ),

                  SizedBox(height: height * 0.02),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPad({required double keySize, required double spacing, required double fontSize}) {
    return Column(
      children: [
        _row(['1', '2', '3'], keySize, spacing, fontSize),
        SizedBox(height: spacing),
        _row(['4', '5', '6'], keySize, spacing, fontSize),
        SizedBox(height: spacing),
        _row(['7', '8', '9'], keySize, spacing, fontSize),
        SizedBox(height: spacing),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: keySize, height: keySize),
            SizedBox(width: spacing),

            _key('0', keySize: keySize, fontSize: fontSize),

            SizedBox(width: spacing),

            _delKey(keySize),
          ],
        ),
      ],
    );
  }

  Widget _row(List<String> keys, double keySize, double spacing, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        return Row(
          children: [
            _key(k, keySize: keySize, fontSize: fontSize),
            if (k != keys.last) SizedBox(width: spacing),
          ],
        );
      }).toList(),
    );
  }

  Widget _key(String label, {required double keySize, required double fontSize}) {
    return GestureDetector(
      onTap: () => _onKey(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(keySize * 0.28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
          ),
        ),
      ),
    );
  }

  Widget _delKey(double keySize) {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(keySize * 0.28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Icon(Icons.backspace_outlined, color: Colors.grey[600], size: keySize * 0.3),
        ),
      ),
    );
  }
}
