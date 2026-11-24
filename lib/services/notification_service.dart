import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:awesome_notifications/awesome_notifications.dart' hide NotificationModel;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/notification_model.dart';
import '../models/draw_result_model.dart';
import 'auth_service.dart';

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

  List<AppNotification> notifications(AccountStorage account) {
    if (!AuthService.canUseStorage(account)) return [];
    return account.notifications.values.map(_toApp).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int unreadCount(AccountStorage account) {
    if (!AuthService.canUseStorage(account)) return 0;
    return account.notifications.values.where((n) => !n.isRead).length;
  }

  Future<void> markAsRead(AccountStorage account, String id) async {
    if (!AuthService.canUseStorage(account)) return;
    for (final entry in account.notifications.values.where((n) => n.id == id && !n.isRead)) {
      entry.isRead = true;
      if (!AuthService.canUseStorage(account)) return;
      await account.notifications.update(entry);
    }
  }

  Future<void> markAllAsRead(AccountStorage account) async {
    if (!AuthService.canUseStorage(account)) return;
    for (final entry in account.notifications.values.where((n) => !n.isRead)) {
      entry.isRead = true;
      if (!AuthService.canUseStorage(account)) return;
      await account.notifications.update(entry);
    }
  }

  Future<void> deleteNotification(AccountStorage account, String id) async {
    if (!AuthService.canUseStorage(account)) return;
    await account.notifications.deleteWhere((notification) => notification.id == id);
  }

  Future<void> clearAll(AccountStorage account) async {
    if (!AuthService.canUseStorage(account)) return;
    await account.notifications.clear();
  }

  bool _deviceNotificationsReady = false;
  Future<bool>? _deviceInitialization;

  Future<bool> prepareDeviceNotifications({bool refresh = false}) {
    if (_deviceInitialization case final pending?) return pending;
    if (_deviceNotificationsReady && !refresh) return Future.value(true);
    return _deviceInitialization = _initializeChannels().whenComplete(() => _deviceInitialization = null);
  }

  Future<void> initializeDeviceNotifications() async {
    try {
      await _initializeDeviceNotifications();
    } catch (error, stackTrace) {
      debugPrint('Device notifications could not start: $error\n$stackTrace');
    }
  }

  Future<bool> _initializeChannels() async {
    _deviceNotificationsReady = await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'win_channel',
        channelName: 'Prize Bond Wins',
        channelDescription: 'Notifications when your bond wins a prize',
        defaultPrivacy: NotificationPrivacy.Private,
        defaultColor: const Color(0xFF2D5BFF),
        importance: NotificationImportance.High,
        channelShowBadge: true,
        ledColor: Colors.yellow,
      ),

      NotificationChannel(
        channelKey: 'draw_channel',
        channelName: 'Draw Announcements',
        channelDescription: 'Upcoming draw schedules and reminders',
        defaultPrivacy: NotificationPrivacy.Private,
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
    return _deviceNotificationsReady;
  }

  Future<void> _initializeDeviceNotifications() async {
    if (!await prepareDeviceNotifications(refresh: true)) return;
    final device = AwesomeNotifications();
    final prefs = await SharedPreferences.getInstance();
    await _dismissLegacyPrivateAlerts(device, prefs);

    const permissionKey = 'device_notification_permission_requested';
    final alreadyRequested = prefs.getBool(permissionKey) ?? prefs.getBool('draw_notif_seeded') ?? false;
    if (!alreadyRequested && !await device.isNotificationAllowed() && await prefs.setBool(permissionKey, true)) {
      await device.requestPermissionToSendNotifications();
    }
  }

  Future<void> _dismissLegacyPrivateAlerts(AwesomeNotifications device, SharedPreferences prefs) async {
    const migrationKey = 'legacy_private_device_alerts_dismissed_v2';
    if (prefs.getBool(migrationKey) == true) return;

    try {
      await device.dismissNotificationsByChannelKey('win_channel');
      await device.dismissNotificationsByChannelKey('general_channel');
      await prefs.setBool(migrationKey, true);
    } catch (error) {
      debugPrint('Could not dismiss the legacy device alerts: $error');
    }
  }

  Future<void> _deliverToDevice(AccountStorage account, NotificationType type, NotificationContent content) async {
    if (!_deviceNotificationsReady) return;
    final device = AwesomeNotifications();
    try {
      if (!await device.isNotificationAllowed() || !AuthService.canUseStorage(account)) return;
      final preferences = await AuthService.getAllNotifPrefs(account);
      final allowed = switch (type) {
        NotificationType.win => preferences['win'] == true,
        NotificationType.newDraw || NotificationType.resultsAvailable => preferences['draw'] == true,
        NotificationType.general => true,
      };
      if (preferences['all'] == true && allowed && AuthService.canUseStorage(account)) {
        await device.createNotification(content: content);
      }
    } catch (error, stackTrace) {
      debugPrint('Device notification could not be delivered: $error\n$stackTrace');
    }
  }

  Future<void> _publishDrawNotice(
    AccountStorage account, {
    required NotificationType type,
    required String title,
    required String body,
    required String channel,
    required String deviceTitle,
    required String deviceBody,
    required NotificationCategory category,
    required String? eventId,
  }) async {
    if (!AuthService.canUseStorage(account)) return;
    final model = NotificationModel()
      ..id = eventId ?? const Uuid().v4()
      ..typeIndex = _indexFromType(type)
      ..title = title
      ..body = body
      ..timestamp = DateTime.now()
      ..isRead = false;

    if (eventId == null) {
      await account.notifications.add(model);
    } else if (!await account.notifications.addIfAbsent(eventId, model)) {
      return;
    }
    if (!AuthService.canUseStorage(account)) return;
    final digest = sha256.convert(utf8.encode('${account.accountId}|${model.id}')).toString();
    await _deliverToDevice(
      account,
      type,
      NotificationContent(
        id: int.parse(digest.substring(0, 7), radix: 16),
        channelKey: channel,
        title: deviceTitle,
        body: deviceBody,
        notificationLayout: type == NotificationType.win ? NotificationLayout.BigText : NotificationLayout.Default,
        category: category,
      ),
    );
  }

  Future<void> showWinNotification(
    AccountStorage account, {
    required String bondNumber,
    required String denomination,
    required String city,
    String? drawNumber,
    String? eventId,
  }) async {
    if (!AuthService.canUseStorage(account)) return;
    if (eventId != null) {
      final legacyBody = 'Bond #$bondNumber ($denomination) won a prize in the draw held in $city!';
      if (account.notifications.values.any(
        (notice) => notice.typeIndex == _indexFromType(NotificationType.win) && notice.body == legacyBody,
      )) {
        return;
      }
    }
    final draw = drawNumber == null ? 'a draw' : 'Draw #$drawNumber';
    await _publishDrawNotice(
      account,
      type: NotificationType.win,
      title: '🎉 Congratulations! You Won!',
      body: 'Bond #$bondNumber ($denomination) matched a prize in $draw held in $city. ${AppConfig.simulatedResultsLabel}.',
      channel: 'win_channel',
      deviceTitle: 'Saved bond update',
      deviceBody: 'Unlock the app to view your account notification.',
      category: NotificationCategory.Reminder,
      eventId: eventId,
    );
  }

  Future<void> showNewDrawNotification(
    AccountStorage account, {
    required String denomination,
    required String date,
    required String city,
    String? eventId,
  }) {
    final body = 'Sample $denomination draw scheduled for $date in $city.';
    return _publishDrawNotice(
      account,
      type: NotificationType.newDraw,
      title: '📅 New Draw Announced',
      body: body,
      channel: 'draw_channel',
      deviceTitle: '📅 New Draw Announced',
      deviceBody: body,
      category: NotificationCategory.Event,
      eventId: eventId,
    );
  }

  Future<void> recordDrawReminder(AccountStorage account, DrawResult draw, int notificationId) async {
    if (!AuthService.canUseStorage(account)) return;
    final key = 'draw-reminder:$notificationId';
    await account.notifications.addIfAbsent(
      key,
      NotificationModel()
        ..id = key
        ..typeIndex = _indexFromType(NotificationType.newDraw)
        ..title = '📅 Draw Reminder Set'
        ..body = 'Reminder set for the sample ${draw.denomination} draw on ${draw.drawDate} in ${draw.city}.'
        ..timestamp = DateTime.now()
        ..isRead = false,
    );
  }

  Future<void> showResultsAvailableNotification(
    AccountStorage account, {
    required String denomination,
    required String date,
    required String city,
    String? eventId,
  }) {
    final body = 'Simulated $denomination results for $date ($city) are available. Tap to check your bonds.';
    return _publishDrawNotice(
      account,
      type: NotificationType.resultsAvailable,
      title: '📋 Results Available',
      body: body,
      channel: 'results_channel',
      deviceTitle: '📋 Results Available',
      deviceBody: body,
      category: NotificationCategory.Status,
      eventId: eventId,
    );
  }
}
