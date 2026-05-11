import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, String>? _realUser;
  bool _realUserApproved = false;
  bool _loading = true;
  bool _sendingEmail = false;

  final List<Map<String, dynamic>> _dummyApproved = [
    {'name': 'Ahmed Khan', 'email': 'ahmed@example.com', 'role': 'Normal User', 'city': 'Lahore', 'date': 'Feb 10, 2025'},
    {'name': 'Fatima Malik', 'email': 'fatima@example.com', 'role': 'Normal User', 'city': 'Faisalabad', 'date': 'Feb 05, 2025'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRealUser();
  }

  Future<void> _loadRealUser() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) {
      setState(() => _loading = false);
      return;
    }

    final profile = await AuthService.getUserProfile();
    final approved = await AuthService.isApproved();

    setState(() {
      _realUser = profile;
      _realUserApproved = approved;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _pendingList {
    if (_realUser == null || _realUserApproved) return [];

    return [
      {
        'name': _realUser!['name'] ?? 'Unknown',
        'email': _realUser!['email'] ?? '',
        'role': _realUser!['role'] ?? 'Normal User',
        'city': _realUser!['city'] ?? '',
        'date': 'Just registered',
        'isReal': true,
      },
    ];
  }

  List<Map<String, dynamic>> get _approvedList {
    final list = List<Map<String, dynamic>>.from(_dummyApproved);

    if (_realUser != null && _realUserApproved) {
      list.insert(0, {
        'name': _realUser!['name'] ?? 'Unknown',
        'email': _realUser!['email'] ?? '',
        'role': _realUser!['role'] ?? 'Normal User',
        'city': _realUser!['city'] ?? '',
        'date': 'Just approved',
      });
    }

    return list;
  }

  Future<void> _sendApprovalEmail(String toEmail, String userName) async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('Approval email would be sent to $toEmail');
  }

  Future<void> _approve() async {
    setState(() => _sendingEmail = true);

    await AuthService.setApproved(true);

    final userEmail = _realUser!['email'] ?? '';
    final userName = _realUser!['name'] ?? 'User';

    if (userEmail.isNotEmpty) {
      await _sendApprovalEmail(userEmail, userName);
    }

    setState(() {
      _realUserApproved = true;
      _sendingEmail = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$userName approved! Approval email sent.'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    _tabController.animateTo(1);
  }

  Future<void> _reject() async {
    await AuthService.setApproved(false);
    await AuthService.setLoggedIn(false);

    setState(() {
      _realUser = null;
      _realUserApproved = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Registration rejected. User must re-register.'),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildApprovedTab(List<Map<String, dynamic>> approved) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2D5BFF).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF2D5BFF), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Demo mode: Ahmed Khan and Fatima Malik are sample records for demonstration purposes.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF2D5BFF)),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: approved.isEmpty
              ? const _EmptyState(icon: Icons.people_outline, message: 'No approved users yet')
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: approved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ApprovedCard(user: approved[i]),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFBFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2D5BFF))),
      );
    }

    final pending = _pendingList;
    final approved = _approvedList;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2D5BFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2D5BFF),
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Approved (${approved.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          pending.isEmpty
              ? const _EmptyState(icon: Icons.check_circle_outline, message: 'No pending registrations')
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _PendingCard(
                    user: pending[i],
                    isSendingEmail: _sendingEmail,
                    onApprove: pending[i]['isReal'] == true ? _approve : () {},
                    onReject: pending[i]['isReal'] == true ? _reject : () {},
                  ),
                ),

          _buildApprovedTab(approved),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isSendingEmail;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({required this.user, required this.isSendingEmail, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFFBBF24).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'],
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
                    ),
                    Text(user['email'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _Tag(Icons.badge_outlined, user['role'].isNotEmpty ? user['role'] : 'N/A'),
              const SizedBox(width: 8),
              _Tag(Icons.location_city_outlined, user['city'].isNotEmpty ? user['city'] : 'N/A'),
              const SizedBox(width: 8),
              _Tag(Icons.calendar_today_outlined, user['date']),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: isSendingEmail ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      side: BorderSide(color: Colors.red[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isSendingEmail ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isSendingEmail
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Approve ✓', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovedCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _ApprovedCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Color(0xFF10B981)),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
                ),

                Text(user['email'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),

                const SizedBox(height: 4),

                Row(
                  children: [
                    _Tag(Icons.badge_outlined, user['role'].isNotEmpty ? user['role'] : 'N/A'),
                    const SizedBox(width: 6),
                    _Tag(Icons.location_city_outlined, user['city'].isNotEmpty ? user['city'] : 'N/A'),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'Approved',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        ],
      ),
    );
  }
}
