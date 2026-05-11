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
    Future.delayed(const Duration(milliseconds: 200), () async {
      if (!mounted) return;

      final correct = await AuthService.verifyPin(_enteredPin);

      if (correct) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
      } else {
        setState(() {
          _hasError = true;
          _enteredPin = '';
        });
      }
    });
  }

  void _showForgotPinDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Forgot PIN?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your registered email address to verify your identity.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Registered Email',
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2D5BFF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2D5BFF), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final enteredEmail = emailController.text.trim();

              if (enteredEmail.isEmpty) return;

              final profile = await AuthService.getUserProfile();

              final storedEmail = profile['email'] ?? '';

              if (!mounted) return;

              Navigator.pop(context);

              if (enteredEmail.toLowerCase() == storedEmail.toLowerCase()) {
                _showResetPinDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Email does not match our records'),
                    backgroundColor: Colors.red[400],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showResetPinDialog() {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPinController,
                obscureText: obscureNew,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'New PIN (4 digits)',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2D5BFF)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey[400]),
                    onPressed: () {
                      setDialogState(() {
                        obscureNew = !obscureNew;
                      });
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2D5BFF), width: 2),
                  ),
                  counterText: '',
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: confirmPinController,
                obscureText: obscureConfirm,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2D5BFF)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.grey[400],
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscureConfirm = !obscureConfirm;
                      });
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2D5BFF), width: 2),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newPin = newPinController.text.trim();

                final confirmPin = confirmPinController.text.trim();

                if (newPin.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
                  return;
                }

                if (newPin != confirmPin) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match')));
                  return;
                }

                await AuthService.savePin(newPin);

                if (!mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('PIN has been reset successfully'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reset PIN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final width = size.width;
    final height = size.height;

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

                  _buildPad(keySize: keySize, spacing: spacing, fontSize: width * 0.06),

                  SizedBox(height: height * 0.03),

                  TextButton(
                    onPressed: _showForgotPinDialog,
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
