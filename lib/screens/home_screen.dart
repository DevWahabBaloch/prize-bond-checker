import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/screens/check_bond_screen.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';
import 'package:prize_bond_checking_app/screens/draws_screen.dart';
import 'package:prize_bond_checking_app/screens/notifications_screen.dart'; // ← NEW
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'User';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await AuthService.getUserProfile();
    if (mounted) {
      setState(() {
        _userName = profile['name'] ?? 'User';
        _isLoading = false;
      });
    }
  }

  /// Opens the dedicated Notifications page.
  void _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    // Refresh badge count when returning from the notifications page.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D5BFF)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  _buildMyBondsSection(context),
                  const SizedBox(height: 24),
                  _buildRecentDrawsSection(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    // Read live unread count from the singleton service
    final unreadCount = NotificationService().unreadCount;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 35.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      _userName,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // ─── Notification bell (navigates to NotificationsScreen) ───────
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: _openNotifications, // ← changed
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search prize bond number...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      if (value.length == 6) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckBondScreen()));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              context: context,
              icon: Icons.search,
              title: 'Check Bond',
              subtitle: 'Search by number',
              gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
              isGradient: false,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckBondScreen()));
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionCard(
              context: context,
              icon: Icons.qr_code_scanner,
              title: 'Scan Bond',
              subtitle: 'Use camera',
              gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
              isGradient: true,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required bool isGradient,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isGradient ? gradient : null,
        color: isGradient ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: isGradient
                        ? LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)])
                        : gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isGradient ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: isGradient ? Colors.white.withOpacity(0.8) : const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyBondsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Bonds',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showAddBondDialog(context),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: Color(0xFF2D5BFF)),
                            SizedBox(width: 4),
                            Text(
                              'Add New',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D5BFF)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBondItem('123456', 'Rs. 1500'),
            const SizedBox(height: 12),
            _buildBondItem('789012', 'Rs. 750'),
          ],
        ),
      ),
    );
  }

  void _showAddBondDialog(BuildContext context) {
    final TextEditingController numberController = TextEditingController();
    String selectedDenom = 'Rs. 1500';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Bond'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedDenom,
              items: const [
                'Rs. 100',
                'Rs. 200',
                'Rs. 750',
                'Rs. 1500',
                'Rs. 7500',
                'Rs. 15000',
                'Rs. 25000',
                'Rs. 40000',
              ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => selectedDenom = val!,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Bond Number', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (numberController.text.length == 6) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bond added successfully!')));
              }
            },
            child: const Text('Add Bond'),
          ),
        ],
      ),
    );
  }

  Widget _buildBondItem(String number, String denomination) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9FAFB), Color(0xFFEFF6FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(denomination, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Active',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDrawsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Draws',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DrawsScreen()));
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D5BFF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDrawItem('Rs. 1500', 'Jan 15, 2026', 'Lahore', '654321'),
            const SizedBox(height: 12),
            _buildDrawItem('Rs. 750', 'Jan 10, 2026', 'Karachi', '987654'),
            const SizedBox(height: 12),
            _buildDrawItem('Rs. 200', 'Jan 05, 2026', 'Islamabad', '456789'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawItem(String denom, String date, String city, String winner) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9FAFB), Color(0xFFFAF5FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    denom,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 4),
                  Text('$city • $date', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Winner',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
            child: Text(
              winner,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace', color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}
