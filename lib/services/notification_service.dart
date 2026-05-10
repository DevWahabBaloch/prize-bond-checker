import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

/// Model representing a single in-app notification entry.
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}

enum NotificationType { win, newDraw, resultsAvailable, general }

class NotificationService {
  // ─── Singleton ───────────────────────────────────────────────────────────────
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ─── In-memory notification store ────────────────────────────────────────────
  // In a real app, persist these with shared_preferences / Hive / SQLite.
  final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      type: NotificationType.win,
      title: '🎉 Congratulations! You Won!',
      body: 'Your bond #123456 (Rs. 1500) matched the 1st prize in the January 2026 draw held in Lahore.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    AppNotification(
      id: '2',
      type: NotificationType.newDraw,
      title: '📅 New Draw Announced',
      body: 'Rs. 750 prize bond draw is scheduled for February 15, 2026 in Karachi. Make sure your bonds are registered!',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: false,
    ),
    AppNotification(
      id: '3',
      type: NotificationType.resultsAvailable,
      title: '📋 Results Available',
      body: 'Rs. 200 prize bond draw results for January 5, 2026 (Islamabad) are now available. Tap to check your bonds.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    AppNotification(
      id: '4',
      type: NotificationType.resultsAvailable,
      title: '📋 Results Available',
      body: 'Rs. 1500 prize bond draw results for December 15, 2025 (Peshawar) are now available.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
    AppNotification(
      id: '5',
      type: NotificationType.newDraw,
      title: '📅 Upcoming Draw Reminder',
      body: 'Rs. 25000 prize bond draw is tomorrow (Jan 20, 2026) in Quetta. Check your saved bonds now.',
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
      isRead: true,
    ),
  ];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) _notifications[index].isRead = true;
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
  }

  void clearAll() => _notifications.clear();

  // ─── awesome_notifications setup ─────────────────────────────────────────────

  /// Call once from main() or HomeScreen.initState().
  Future<void> init() async {
    await AwesomeNotifications().initialize(
      null, // use default app icon; replace with 'resource://drawable/res_notification_icon' if you have one
      [
        NotificationChannel(
          channelKey: 'win_channel',
          channelName: 'Prize Bond Wins',
          channelDescription: 'Notifications when your bond wins a prize',
          defaultColor: const Color(0xFF2D5BFF),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          ledColor: Colors.yellow,
        ),
        NotificationChannel(
          channelKey: 'draw_channel',
          channelName: 'Draw Announcements',
          channelDescription: 'Upcoming draw schedules and reminders',
          defaultColor: const Color(0xFF8B5CF6),
          importance: NotificationImportance.Default,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: 'results_channel',
          channelName: 'Results Available',
          channelDescription: 'Notifications when new draw results are published',
          defaultColor: const Color(0xFF059669),
          importance: NotificationImportance.Default,
          channelShowBadge: true,
        ),
      ],
      debug: false,
    );

    // Request permission on first launch
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // ─── Push helpers ─────────────────────────────────────────────────────────────

  Future<void> showWinNotification({required String bondNumber, required String denomination, required String city}) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'win_channel',
        title: '🎉 Congratulations! You Won!',
        body: 'Bond #$bondNumber ($denomination) won a prize in the draw held in $city!',
        notificationLayout: NotificationLayout.BigText,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: NotificationType.win,
        title: '🎉 Congratulations! You Won!',
        body: 'Bond #$bondNumber ($denomination) won a prize in the draw held in $city!',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> showNewDrawNotification({required String denomination, required String date, required String city}) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'draw_channel',
        title: '📅 New Draw Announced',
        body: '$denomination prize bond draw scheduled for $date in $city.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Event,
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: NotificationType.newDraw,
        title: '📅 New Draw Announced',
        body: '$denomination prize bond draw scheduled for $date in $city.',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> showResultsAvailableNotification({
    required String denomination,
    required String date,
    required String city,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'results_channel',
        title: '📋 Results Available',
        body: '$denomination draw results for $date ($city) are now available. Tap to check your bonds.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Status,
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: NotificationType.resultsAvailable,
        title: '📋 Results Available',
        body: '$denomination draw results for $date ($city) are now available.',
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Fires demo push notifications so the tray shows something during testing.
  Future<void> triggerDemoNotifications() async {
    await showWinNotification(bondNumber: '123456', denomination: 'Rs. 1500', city: 'Lahore');
    await Future.delayed(const Duration(milliseconds: 400));
    await showNewDrawNotification(denomination: 'Rs. 750', date: 'Feb 15, 2026', city: 'Karachi');
  }
}
