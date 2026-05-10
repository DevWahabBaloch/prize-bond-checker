import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _service = NotificationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AppNotification> _filtered(NotificationType? type) {
    if (type == null) return _service.notifications.toList();
    return _service.notifications.where((n) => n.type == type).toList();
  }

  void _markAllRead() {
    setState(() => _service.markAllAsRead());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: Color(0xFF2D5BFF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All'),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              setState(() => _service.clearAll());
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(_filtered(null)),
                _buildList(_filtered(NotificationType.win)),
                _buildList(_filtered(NotificationType.newDraw)..addAll(_filtered(NotificationType.resultsAvailable))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final unread = _service.unreadCount;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 50, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              // Mark all read
              if (unread > 0)
                TextButton(
                  onPressed: _markAllRead,
                  child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              // Clear all menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (v) {
                  if (v == 'clear') _clearAll();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                        SizedBox(width: 8),
                        Text('Clear all'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Summary chip
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    unread > 0 ? '$unread unread notification${unread > 1 ? 's' : ''}' : 'All caught up!',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF2D5BFF),
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: const Color(0xFF2D5BFF),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('All'),
                if (_service.unreadCount > 0) ...[const SizedBox(width: 6), _badge(_service.unreadCount)],
              ],
            ),
          ),
          const Tab(text: 'Wins 🎉'),
          const Tab(text: 'Draws 📅'),
        ],
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(List<AppNotification> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)]),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(Icons.notifications_none, size: 40, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications here',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 6),
            const Text('We\'ll notify you when something happens', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final n = items[index];
        return _NotificationCard(
          notification: n,
          onTap: () => setState(() => _service.markAsRead(n.id)),
          onDismiss: () => setState(() => _service.deleteNotification(n.id)),
        );
      },
    );
  }
}

// ─── Notification Card ─────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({required this.notification, required this.onTap, required this.onDismiss});

  // Visual config per type
  _TypeConfig get _config {
    switch (notification.type) {
      case NotificationType.win:
        return _TypeConfig(
          icon: Icons.emoji_events_rounded,
          gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
          badgeText: 'WIN',
          badgeColor: const Color(0xFFF59E0B),
          badgeBg: const Color(0xFFFEF3C7),
        );
      case NotificationType.newDraw:
        return _TypeConfig(
          icon: Icons.calendar_today_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
          badgeText: 'DRAW',
          badgeColor: const Color(0xFF2D5BFF),
          badgeBg: const Color(0xFFEFF6FF),
        );
      case NotificationType.resultsAvailable:
        return _TypeConfig(
          icon: Icons.checklist_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
          badgeText: 'RESULTS',
          badgeColor: const Color(0xFF059669),
          badgeBg: const Color(0xFFD1FAE5),
        );
      default:
        return _TypeConfig(
          icon: Icons.notifications_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)]),
          badgeText: 'INFO',
          badgeColor: const Color(0xFF6B7280),
          badgeBg: const Color(0xFFF3F4F6),
        );
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isUnread ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isUnread ? const Color(0xFF2D5BFF).withOpacity(0.2) : const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(gradient: cfg.gradient, borderRadius: BorderRadius.circular(14)),
                child: Icon(cfg.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6, top: 4),
                            decoration: const BoxDecoration(color: Color(0xFF2D5BFF), shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Body
                    Text(notification.body, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4)),
                    const SizedBox(height: 8),
                    // Footer
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: cfg.badgeBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            cfg.badgeText,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cfg.badgeColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_timeAgo(notification.timestamp), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeConfig {
  final IconData icon;
  final LinearGradient gradient;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;

  _TypeConfig({
    required this.icon,
    required this.gradient,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
  });
}
