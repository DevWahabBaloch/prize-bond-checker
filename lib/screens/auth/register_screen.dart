import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prize_bond_checking_app/screens/auth/landing_screen.dart';
import 'package:prize_bond_checking_app/screens/auth/pending_approval_screen.dart';
import 'package:prize_bond_checking_app/services/account_credentials.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept terms and conditions'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final registration = await AuthService.registerUser(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        mobile: _mobileController.text,
        email: _emailController.text,
        pin: _pinController.text,
        address: _addressController.text,
        city: _cityController.text,
      );
      if (!mounted) return;
      final account = registration.account;
      if (!registration.selectionSaved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account created. Sign in with your registered email to continue.')));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute<void>(builder: (_) => const LandingScreen()), (_) => false);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PendingApprovalScreen(accountId: account.id, email: account.email),
        ),
      );
    } on CredentialException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } on AccountException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not register. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[500]),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2D5BFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[300]!),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red[300]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(color: Colors.grey[500]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fill in your details to register', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
                const SizedBox(height: 28),

                const _SectionLabel(label: 'Personal Information'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('First Name', Icons.person_outline),
                  validator: (v) => v!.trim().isEmpty ? 'Enter your first name' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Last Name', Icons.person_outline),
                  validator: (v) => v!.trim().isEmpty ? 'Enter your last name' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: _dec('Mobile No.', Icons.phone_outlined).copyWith(
                    prefixText: '+92 ',
                    prefixStyle: const TextStyle(color: Color(0xFF1F2937), fontSize: 16),
                    counterText: '',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';

                    if (value.isEmpty) {
                      return 'Enter your mobile number';
                    }

                    if (!RegExp(r'^3\d{9}$').hasMatch(value)) {
                      return 'Enter a valid Pakistani mobile number';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Email', Icons.email_outlined),
                  validator: (v) {
                    if (v!.isEmpty) return 'Enter your email';
                    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                const _SectionLabel(label: 'Security PIN'),
                const SizedBox(height: 6),
                Text(
                  'You will enter this 4-digit PIN every time you open the app',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _pinController,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec(
                    'PIN (4 digits)',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.grey[400],
                      ),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'Enter a 4-digit PIN';
                    if (v.length < 4) return 'PIN must be 4 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirmPinController,
                  obscureText: _obscureConfirmPin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec(
                    'Confirm PIN',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirmPin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.grey[400],
                      ),
                      onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                    ),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'Confirm your PIN';
                    if (v != _pinController.text) return 'PINs do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                const _SectionLabel(label: 'Address Details'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: _dec('Address', Icons.home_outlined),
                  validator: (v) => v!.trim().isEmpty ? 'Enter your address' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('City', Icons.location_city_outlined),
                  validator: (v) => v!.trim().isEmpty ? 'Enter your city' : null,
                ),
                const SizedBox(height: 28),

                GestureDetector(
                  onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _acceptTerms ? const Color(0xFF2D5BFF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _acceptTerms ? const Color(0xFF2D5BFF) : const Color(0xFFD1D5DB), width: 1.5),
                        ),
                        child: _acceptTerms ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            children: const [
                              TextSpan(text: 'I accept the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(color: Color(0xFF2D5BFF), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(color: const Color(0xFF2D5BFF), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
        ),
      ],
    );
  }
}
