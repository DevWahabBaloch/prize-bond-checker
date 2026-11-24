import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/screens/admin/admin_screen.dart';
import 'package:prize_bond_checking_app/screens/auth/register_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'pending_approval_screen.dart';
import 'pin_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _showAdminPasswordDialog(BuildContext context) async {
    final passphrase = await _readCredential(context, admin: true);
    if (passphrase == null || !context.mounted) return;
    try {
      final access = await AuthService.authenticateAdmin(passphrase);
      if (!context.mounted) {
        access?.close();
        return;
      }
      if (access == null) {
        _showError(context, 'Incorrect passphrase.');
        return;
      }
      if (!access.isOpen) return;
      try {
        await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => AdminScreen(access: access)));
      } finally {
        access.close();
      }
    } on AccountException catch (error) {
      if (context.mounted) _showError(context, error.message);
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not open Admin Access.');
    }
  }

  Future<void> _signIn(BuildContext context) async {
    final email = await _readCredential(context, admin: false);
    if (email == null || !context.mounted) return;
    try {
      final account = await AuthService.selectAccount(email);
      if (!context.mounted) return;
      if (account == null) {
        _showError(context, 'No local account uses that email.');
        return;
      }
      final destination = account.isApproved && !account.isRejected
          ? PinScreen(accountId: account.id)
          : PendingApprovalScreen(accountId: account.id, email: account.email);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destination));
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not open the account. Please try again.');
    }
  }

  Future<String?> _readCredential(BuildContext context, {required bool admin}) {
    var value = '';
    var obscure = admin;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(admin ? 'Admin Access' : 'Sign in'),
          content: TextField(
            autofocus: true,
            obscureText: obscure,
            keyboardType: admin ? TextInputType.visiblePassword : TextInputType.emailAddress,
            autocorrect: false,
            onChanged: (text) => value = text,
            onSubmitted: (text) => Navigator.pop(context, text),
            decoration: InputDecoration(
              labelText: admin ? 'Admin passphrase' : 'Registered email',
              prefixIcon: Icon(admin ? Icons.lock_outline : Icons.email_outlined, color: const Color(0xFF2D5BFF)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: admin
                  ? IconButton(
                      tooltip: obscure ? 'Show passphrase' : 'Hide passphrase',
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    )
                  : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('Continue')),
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => _signIn(context), child: const Text('Sign in')),

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
