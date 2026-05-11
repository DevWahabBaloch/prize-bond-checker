import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/screens/admin/admin_screen.dart';
import 'package:prize_bond_checking_app/screens/auth/register_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const String _adminPassword = AppConfig.adminPassword;

  void _showAdminPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF2D5BFF)),
              SizedBox(width: 10),
              Text('Admin Access'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter the admin password to continue.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Admin Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2D5BFF)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey[400]),
                    onPressed: () {
                      setDialogState(() => obscure = !obscure);
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
                ),
                onSubmitted: (_) => _verifyAndNavigate(context, passwordController.text),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _verifyAndNavigate(context, passwordController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );
  }

  void _verifyAndNavigate(BuildContext context, String entered) {
    if (entered == _adminPassword) {
      Navigator.pop(context);

      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
    } else {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Incorrect password'),
          backgroundColor: Colors.red[400],
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _showAdminPasswordDialog(context),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFF6B7280)),
            label: const Text('Admin', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),

              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2D5BFF).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 52),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                AppConfig.appName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), height: 1.2),
              ),

              const SizedBox(height: 16),

              Text(
                'Manage and check your prize bonds\nquickly and securely',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[500], height: 1.5),
              ),

              const SizedBox(height: 48),

              _FeatureCard(
                icon: Icons.search_rounded,
                title: 'Check Instantly',
                subtitle: 'Verify your prize bonds in seconds',
                color: const Color(0xFF2D5BFF),
              ),

              const SizedBox(height: 12),

              _FeatureCard(
                icon: Icons.notifications_active_outlined,
                title: 'Get Notified',
                subtitle: 'Receive alerts on winning results',
                color: const Color(0xFF8B5CF6),
              ),

              const SizedBox(height: 12),

              _FeatureCard(
                icon: Icons.security_outlined,
                title: 'Secure & Private',
                subtitle: 'Your data is protected with PIN security',
                color: const Color(0xFF10B981),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Once approved by admin, open the app\nand enter your PIN to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.5),
              ),

              const SizedBox(height: 20),

              Text(
                AppConfig.dataDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.5),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureCard({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
