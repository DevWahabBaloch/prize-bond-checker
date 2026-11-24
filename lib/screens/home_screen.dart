import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/screens/check_bond_screen.dart';
import 'package:prize_bond_checking_app/screens/draws_screen.dart';
import 'package:prize_bond_checking_app/screens/my_bonds_screen.dart';
import 'package:prize_bond_checking_app/screens/notifications_screen.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:prize_bond_checking_app/widgets/connectivity_badge.dart';

class _BP {
  static const double tablet = 600;
  static const double desktop = 900;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _storage = AuthService.requireStorage();

  String _userName = 'User';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = AuthService.profile(_storage);
    if (mounted) {
      setState(() {
        _userName = profile.fullName;
        _isLoading = false;
      });
    }
  }

  void _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D5BFF)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ValueListenableBuilder(valueListenable: _storage.notifications, builder: (_, _, _) => _buildHeader(width)),
                      SizedBox(height: width >= _BP.tablet ? 28 : 20),
                      _buildBody(width),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBody(double width) {
    if (width >= _BP.desktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            _buildQuickActions(width),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildMyBondsSection(width)),
                const SizedBox(width: 24),
                Expanded(child: _buildRecentDrawsSection(width)),
              ],
            ),
          ],
        ),
      );
    } else if (width >= _BP.tablet) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            _buildQuickActions(width),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildMyBondsSection(width)),
                const SizedBox(width: 20),
                Expanded(child: _buildRecentDrawsSection(width)),
              ],
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _buildQuickActions(width),
            const SizedBox(height: 24),
            _buildMyBondsSection(width),
            const SizedBox(height: 24),
            _buildRecentDrawsSection(width),
          ],
        ),
      );
    }
  }

  Widget _buildHeader(double width) {
    final isTablet = width >= _BP.tablet;
    final isDesktop = width >= _BP.desktop;
    final hPad = isDesktop
        ? 32.0
        : isTablet
        ? 28.0
        : 24.0;
    final titleSize = isDesktop
        ? 26.0
        : isTablet
        ? 24.0
        : 22.0;
    final unreadCount = NotificationService().unreadCount(_storage);
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),

      padding: EdgeInsets.fromLTRB(hPad, topInset + 16, hPad, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: titleSize, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Align(alignment: Alignment.centerLeft, child: ConnectivityBadge()),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: _openNotifications,
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
              ),
            ],
          ),
          const SizedBox(height: 18),

          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 560 : double.infinity),
              child: Container(
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
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CheckBondScreen(initialBondNumber: digits.length >= 6 ? digits.substring(0, 6) : digits),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(double width) {
    final isTablet = width >= _BP.tablet;

    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.search,
            title: 'Check Bond',
            subtitle: 'Search by number',
            gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
            isGradient: false,
            isTablet: isTablet,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckBondScreen())),
          ),
        ),
        SizedBox(width: isTablet ? 20 : 16),
        Expanded(
          child: _buildActionCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan Bond',
            subtitle: 'Use camera',
            gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
            isGradient: true,
            isTablet: isTablet,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required bool isGradient,
    required bool isTablet,
    VoidCallback? onTap,
  }) {
    final iconSize = isTablet ? 32.0 : 28.0;
    final iconBoxSize = isTablet ? 64.0 : 56.0;
    final titleSize = isTablet ? 20.0 : 18.0;
    final subtitleSize = isTablet ? 15.0 : 14.0;

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
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    gradient: isGradient
                        ? LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)])
                        : gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: iconSize),
                ),
                SizedBox(height: isTablet ? 20 : 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    color: isGradient ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: isGradient ? Colors.white.withOpacity(0.8) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyBondsSection(double width) {
    final isTablet = width >= _BP.tablet;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Bonds',
                style: TextStyle(fontSize: isTablet ? 22 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
              ),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBondsScreen())),
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
          ValueListenableBuilder(
            valueListenable: _storage.bonds,
            builder: (context, PrivateRecords<Bond> box, _) {
              if (box.isEmpty) {
                return _buildEmptyState(Icons.bookmark_border_rounded, 'No bonds saved yet — tap Add New');
              }
              final bonds = box.values.toList().reversed.take(2).toList();
              return Column(
                children: bonds
                    .map(
                      (bond) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildBondItem(bond.number, bond.denomination, bond.status, isTablet),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBondItem(String number, String denomination, String status, bool isTablet) {
    Color statusColor;
    Color statusBg;

    if (status == 'Won') {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFD1FAE5);
    } else if (status == 'No Win') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFEF3C7);
    } else {
      statusColor = const Color(0xFF2D5BFF);
      statusBg = const Color(0xFFEFF6FF);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF9FAFB), Color(0xFFEFF6FF)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: EdgeInsets.all(isTablet ? 18 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: TextStyle(fontSize: isTablet ? 20 : 18, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              Text(denomination),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              status == 'Active' ? 'Active' : status,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDrawsSection(double width) {
    final isTablet = width >= _BP.tablet;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Recent Sample Draws',
                  style: TextStyle(fontSize: isTablet ? 22 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DrawsScreen())),
                child: const Text(
                  'View All',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D5BFF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder(
            valueListenable: Hive.box<DrawResult>('draws').listenable(),
            builder: (context, Box<DrawResult> box, _) {
              final completed = DrawService().getCompleted().reversed.take(3).toList();

              if (completed.isEmpty) {
                return _buildEmptyState(Icons.history_rounded, 'No completed draws yet');
              }

              return Column(
                children: completed.asMap().entries.map((entry) {
                  final draw = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: entry.key < completed.length - 1 ? 12 : 0),
                    child: _buildDrawItem(draw.denomination, draw.drawDate, draw.city, draw.firstPrize, isTablet: isTablet),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawItem(String denom, String date, String city, String winner, {bool isTablet = false}) {
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
      padding: EdgeInsets.all(isTablet ? 18 : 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      denom,
                      style: TextStyle(fontSize: isTablet ? 17 : 16, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 4),
                    Text('$city • $date', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
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
            width: double.infinity,
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

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
