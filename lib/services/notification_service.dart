import 'package:awesome_notifications/awesome_notifications.dart' hide NotificationModel;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/notification_model.dart';

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
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  Box<NotificationModel> get _box => Hive.box<NotificationModel>('notifications');

  static NotificationType _typeFromIndex(int i) {
    switch (i) {
      case 0:
        return NotificationType.win;
      case 1:
        return NotificationType.newDraw;
      case 2:
        return NotificationType.resultsAvailable;
      default:
        return NotificationType.general;
    }
  }

  static int _indexFromType(NotificationType t) {
    switch (t) {
      case NotificationType.win:
        return 0;
      case NotificationType.newDraw:
        return 1;
      case NotificationType.resultsAvailable:
        return 2;
      case NotificationType.general:
        return 3;
    }
  }

  AppNotification _toApp(NotificationModel m) => AppNotification(
    id: m.id,
    type: _typeFromIndex(m.typeIndex),
    title: m.title,
    body: m.body,
    timestamp: m.timestamp,
    isRead: m.isRead,
  );

  List<AppNotification> get notifications => _box.values.map(_toApp).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int get unreadCount => _box.values.where((n) => !n.isRead).length;

  void markAsRead(String id) {
    try {
      final entry = _box.values.firstWhere((n) => n.id == id);

      entry.isRead = true;
      entry.save();
    } catch (e) {
      debugPrint('Notification not found');
    }
  }

  void markAllAsRead() {
    for (final n in _box.values) {
      n.isRead = true;
      n.save();
    }
  }

  void deleteNotification(String id) {
    final entries = _box.values.where((n) => n.id == id).toList();

    for (final e in entries) {
      e.delete();
    }
  }

  void clearAll() {
    _box.clear();
  }

  void _seedDemoIfEmpty() {
    if (_box.isNotEmpty) return;

    final demos = [
      NotificationModel()
        ..id = '1'
        ..typeIndex = 0
        ..title = '🎉 Congratulations! You Won!'
        ..body = 'Your bond #123456 (Rs. 1500) matched the 1st prize in the January 2026 draw held in Lahore.'
        ..timestamp = DateTime.now().subtract(const Duration(hours: 2))
        ..isRead = false,

      NotificationModel()
        ..id = '2'
        ..typeIndex = 1
        ..title = '📅 New Draw Announced'
        ..body = 'Rs. 750 prize bond draw is scheduled for February 15, 2026 in Karachi. Make sure your bonds are registered!'
        ..timestamp = DateTime.now().subtract(const Duration(hours: 5))
        ..isRead = false,

      NotificationModel()
        ..id = '3'
        ..typeIndex = 2
        ..title = '📋 Results Available'
        ..body = 'Rs. 200 prize bond draw results for January 5, 2026 (Islamabad) are now available. Tap to check your bonds.'
        ..timestamp = DateTime.now().subtract(const Duration(days: 1))
        ..isRead = true,

      NotificationModel()
        ..id = '4'
        ..typeIndex = 2
        ..title = '📋 Results Available'
        ..body = 'Rs. 1500 prize bond draw results for December 15, 2025 (Rawalpindi) are now available.'
        ..timestamp = DateTime.now().subtract(const Duration(days: 3))
        ..isRead = true,

      NotificationModel()
        ..id = '5'
        ..typeIndex = 1
        ..title = '📅 Upcoming Draw Reminder'
        ..body = 'Rs. 25000 prize bond draw is tomorrow (Jan 20, 2026) in Quetta. Check your saved bonds now.'
        ..timestamp = DateTime.now().subtract(const Duration(days: 4))
        ..isRead = true,
    ];

    for (final d in demos) {
      _box.add(d);
    }
  }

  Future<void> init() async {
    _seedDemoIfEmpty();

    await AwesomeNotifications().initialize(null, [
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

      NotificationChannel(
        channelKey: 'general_channel',
        channelName: 'Account Updates',
        channelDescription: 'General account and app status notifications',
        defaultColor: const Color(0xFF2D5BFF),
        importance: NotificationImportance.Default,
        channelShowBadge: true,
      ),
    ], debug: false);

    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    debugPrint('Notification permission granted: $isAllowed');
  }

  Future<void> showWinNotification({required String bondNumber, required String denomination, required String city}) async {
    final body = 'Bond #$bondNumber ($denomination) won a prize in the draw held in $city!';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'win_channel',
        title: '🎉 Congratulations! You Won!',
        body: body,
        notificationLayout: NotificationLayout.BigText,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
      ),
    );

    final model = NotificationModel()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..typeIndex = _indexFromType(NotificationType.win)
      ..title = '🎉 Congratulations! You Won!'
      ..body = body
      ..timestamp = DateTime.now()
      ..isRead = false;

    _box.add(model);
  }

  Future<void> showNewDrawNotification({required String denomination, required String date, required String city}) async {
    final body = '$denomination prize bond draw scheduled for $date in $city.';

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (isAllowed) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'draw_channel',
          title: '📅 New Draw Announced',
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Event,
        ),
      );
    } else {
      debugPrint('Notification permission not granted');
    }

    final model = NotificationModel()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..typeIndex = _indexFromType(NotificationType.newDraw)
      ..title = '📅 New Draw Announced'
      ..body = body
      ..timestamp = DateTime.now()
      ..isRead = false;

    _box.add(model);
  }

  Future<void> showScheduledDrawReminder({
    required String denomination,
    required String date,
    required String city,
    required DateTime drawDateTime,
  }) async {
    final body = '$denomination prize bond draw is today in $city! Check your bonds now.';

    final scheduleDate = DateTime(drawDateTime.year, drawDateTime.month, drawDateTime.day, 8, 0, 0);

    if (scheduleDate.isAfter(DateTime.now())) {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();

      if (isAllowed) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: drawDateTime.millisecondsSinceEpoch ~/ 1000,
            channelKey: 'draw_channel',
            title: '📅 Draw Day Reminder',
            body: body,
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            wakeUpScreen: true,
          ),
          schedule: NotificationCalendar(
            year: scheduleDate.year,
            month: scheduleDate.month,
            day: scheduleDate.day,
            hour: scheduleDate.hour,
            minute: scheduleDate.minute,
            second: 0,
            allowWhileIdle: true,
            preciseAlarm: true,
          ),
        );
      } else {
        debugPrint('Notification permission not granted — reminder not scheduled');
      }
    } else {
      debugPrint('Draw date is not in the future — skipping system notification schedule');
    }

    final model = NotificationModel()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..typeIndex = _indexFromType(NotificationType.newDraw)
      ..title = '📅 Draw Reminder Set'
      ..body = 'Reminder set for $denomination draw on $date in $city'
      ..timestamp = DateTime.now()
      ..isRead = false;

    _box.add(model);
  }

  Future<void> showResultsAvailableNotification({
    required String denomination,
    required String date,
    required String city,
  }) async {
    final body = '$denomination draw results for $date ($city) are now available. Tap to check your bonds.';

    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    if (isAllowed) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'results_channel',
          title: '📋 Results Available',
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Status,
        ),
      );
    }

    final model = NotificationModel()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..typeIndex = _indexFromType(NotificationType.resultsAvailable)
      ..title = '📋 Results Available'
      ..body = body
      ..timestamp = DateTime.now()
      ..isRead = false;

    _box.add(model);
  }

  Future<void> showApprovalNotification({required String userName}) async {
    final body = '$userName, your account has been approved. You can now sign in with your PIN.';

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (isAllowed) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'general_channel',
          title: 'Account Approved',
          body: body,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Status,
        ),
      );
    }

    final model = NotificationModel()
      ..id = DateTime.now().millisecondsSinceEpoch.toString()
      ..typeIndex = _indexFromType(NotificationType.general)
      ..title = 'Account Approved'
      ..body = body
      ..timestamp = DateTime.now()
      ..isRead = false;

    _box.add(model);
  }
}
