import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'landing_screen.dart';
import 'pin_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  final String email;
  const PendingApprovalScreen({super.key, required this.email});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _checking = false;
  late String _displayEmail;

  @override
  void initState() {
    super.initState();
    _displayEmail = widget.email;
    if (_displayEmail.isEmpty) _loadEmail();
  }

  Future<void> _loadEmail() async {
    final p = await AuthService.getUserProfile();
    if (mounted) setState(() => _displayEmail = p['email'] ?? '');
  }

  Future<void> _checkApproval() async {
    setState(() => _checking = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final approved = await AuthService.isApproved();
    if (!mounted) return;
    setState(() => _checking = false);

    if (approved) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PinScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Still waiting for admin approval…'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 52),
              ),

              const SizedBox(height: 24),

              const Text(
                'Awaiting Approval',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),

              const SizedBox(height: 10),

              Text(
                'Your registration has been submitted. '
                'An admin will review your account and notify you at:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
              ),

              const SizedBox(height: 12),

              if (_displayEmail.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5BFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined, color: Color(0xFF2D5BFF), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _displayEmail,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF2D5BFF), fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What happens next?',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 14),
                    _Step('1', 'Admin reviews your registration', const Color(0xFF2D5BFF)),
                    const SizedBox(height: 10),
                    _Step('2', 'You receive an approval email', const Color(0xFF8B5CF6)),
                    const SizedBox(height: 10),
                    _Step('3', 'Open the app and enter your PIN', const Color(0xFF10B981)),
                    const SizedBox(height: 10),
                    _Step('4', 'Start checking your prize bonds!', const Color(0xFFF59E0B)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _checking ? null : _checkApproval,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _checking ? 'Checking…' : 'Check Approval Status',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LandingScreen()),
                    (route) => false,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D5BFF),
                    side: const BorderSide(color: Color(0xFF2D5BFF), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String step, text;
  final Color color;
  const _Step(this.step, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(
            child: Text(
              step,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
        ),
      ],
    );
  }
}
