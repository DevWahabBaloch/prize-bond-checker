import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
import '../models/draw_result_model.dart';
import 'auth_service.dart';
import 'draw_catalog.dart';
import 'draw_service.dart';
import 'notification_service.dart';

enum ReminderMode { exact, approximate }

enum ReminderStatus {
  none,
  scheduled,
  alreadyScheduled,
  cancelled,
  suspended,
  muted,
  permissionDenied,
  channelUnavailable,
  exactUnavailable,
  expired,
  invalidDraw,
  failed,
}

class ReminderResult {
  const ReminderResult(this.status, {this.mode, this.cancellationPending = false});

  final ReminderStatus status;
  final ReminderMode? mode;
  final bool cancellationPending;

  String get message => switch (status) {
    ReminderStatus.none => 'Remind me at 8:00 a.m. on the sample draw date.',
    ReminderStatus.scheduled =>
      mode == ReminderMode.approximate
          ? 'Approximate reminder scheduled for around 8:00 a.m. on draw day.'
          : 'Reminder scheduled for 8:00 a.m. on draw day.',
    ReminderStatus.alreadyScheduled =>
      mode == ReminderMode.approximate
          ? 'An approximate reminder is already scheduled for around 8:00 a.m. on draw day.'
          : 'A reminder is already scheduled for 8:00 a.m. on draw day.',
    ReminderStatus.cancelled => 'Reminder cancelled.',
    ReminderStatus.suspended => 'Reminder paused. If the account is unlocked, retry to restore it.',
    ReminderStatus.muted => 'Enable device notifications and draw alerts in Profile to schedule this reminder.',
    ReminderStatus.permissionDenied => 'Allow device notifications in system settings, then retry.',
    ReminderStatus.channelUnavailable =>
      'Enable the Draw Announcements notification channel in system settings, then retry.',
    ReminderStatus.exactUnavailable =>
      'Exact alarms are unavailable. Enable them in settings or choose an approximate reminder.',
    ReminderStatus.expired => 'The 8:00 a.m. reminder time for this sample draw has passed.',
    ReminderStatus.invalidDraw => 'This sample draw could not be verified.',
    ReminderStatus.failed when cancellationPending =>
      'Cancellation could not be confirmed. Retry before relying on it.',
    ReminderStatus.failed => 'Could not confirm the reminder. Please try again.',
  };
}

/// The operations the app needs from the installed local notification plugin.
abstract interface class ReminderPlatform {
  Future<bool> prepare();
  Future<bool> canNotify();
  Future<bool> isDrawChannelEnabled();
  Future<bool> canUseExactTiming();
  Future<String> localTimeZone();
  Future<List<NotificationModel>> pending();
  Future<bool> schedule(NotificationContent content, NotificationCalendar calendar);
  Future<void> cancel(int id);
  Future<void> openSettings({required bool exactAlarms});
}

class _DeviceReminderPlatform implements ReminderPlatform {
  static const _androidNotifications = MethodChannel('prize_bond/android_notifications');
  AwesomeNotifications get _device => AwesomeNotifications();

  @override
  Future<bool> prepare() => NotificationService().prepareDeviceNotifications();

  @override
  Future<bool> canNotify() async =>
      await _device.isNotificationAllowed() &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (await _device.checkPermissionList(
            channelKey: 'draw_channel',
            permissions: [NotificationPermission.Alert],
          )).contains(NotificationPermission.Alert));

  @override
  Future<bool> isDrawChannelEnabled() async =>
      defaultTargetPlatform != TargetPlatform.android ||
      await _androidNotifications.invokeMethod<bool>('isDrawChannelEnabled') == true;

  @override
  Future<bool> canUseExactTiming() async =>
      defaultTargetPlatform != TargetPlatform.android ||
      (await _device.checkPermissionList(
        permissions: [NotificationPermission.PreciseAlarms],
      )).contains(NotificationPermission.PreciseAlarms);

  @override
  Future<String> localTimeZone() => _device.getLocalTimeZoneIdentifier();

  @override
  Future<List<NotificationModel>> pending() => _device.listScheduledNotifications();

  @override
  Future<bool> schedule(NotificationContent content, NotificationCalendar calendar) =>
      _device.createNotification(content: content, schedule: calendar);

  @override
  Future<void> cancel(int id) => _device.cancelSchedule(id);

  @override
  Future<void> openSettings({required bool exactAlarms}) async {
    if (exactAlarms) {
      await _device.requestPermissionToSendNotifications(permissions: [NotificationPermission.PreciseAlarms]);
    } else {
      await _device.showNotificationConfigPage(channelKey: 'draw_channel');
    }
  }
}

class DrawReminderService {
  factory DrawReminderService() => _instance;

  DrawReminderService.withPlatform(this._device, {DrawService? draws, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _draws = draws ?? DrawService(clock: clock);

  static final _instance = DrawReminderService.withPlatform(_DeviceReminderPlatform());
  static const _firstId = 1 << 28; // Separate from the immediate notice identifiers.
  static const _lastId = (1 << 30) - 1;
  static const _tagPrefix = 'fyp-reminder-v1-';
  static const _channel = 'draw_channel';
  static const _hour = 8;
  static final _legacyZones = _loadLegacyZones();
  static Future<void> _operations = Future.value();

  final ReminderPlatform _device;
  final DrawService _draws;
  final DateTime Function() _clock;
  bool _prepared = false;

  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static String _ownerTag(String accountId) => '$_tagPrefix${sha256.convert(utf8.encode(accountId))}';

  // Invalidate cold-start requests before the first authenticated restoration. A retry
  // can safely repeat this sweep if the plugin could not confirm cancellation.
  Future<bool> start() => _serialize(() => _tryMaintenance(_prepare));

  Future<bool> suspend(AccountStorage previous) => _serialize(() async {
    if (AuthService.unlockedStorage?.accountId == previous.accountId) return true;
    final tag = _ownerTag(previous.accountId);
    return _tryMaintenance(() => _removeWhere((notice) => notice.content?.groupKey == tag));
  });

  Future<bool> _tryMaintenance(Future<void> Function() action) async {
    try {
      if (!await _device.prepare()) return false;
      await action();
      return true;
    } catch (error) {
      debugPrint('Draw reminder reconciliation failed (${error.runtimeType}).');
      return false;
    }
  }

  Future<void> _prepare() async {
    if (_prepared) return;
    if (!await _device.prepare()) throw StateError('Local notifications are unavailable.');
    await _removeWhere((notice) => (notice.content?.groupKey?.startsWith(_tagPrefix) ?? false) || _isLegacy(notice));
    _prepared = true;
  }

  bool _isLegacy(NotificationModel notice) {
    final content = notice.content;
    final schedule = notice.schedule;
    if (content == null ||
        content.channelKey != _channel ||
        content.category != NotificationCategory.Reminder ||
        content.title != '📅 Draw Day Reminder' ||
        (content.groupKey?.isNotEmpty ?? false) ||
        (content.payload?.isNotEmpty ?? false) ||
        schedule is! NotificationCalendar ||
        schedule.repeats ||
        schedule.hour != _hour ||
        schedule.minute != 0 ||
        schedule.second != 0) {
      return false;
    }

    final body = content.body;
    final hasLegacyBody = AppConfig.denominations.any(
      (denomination) => AppConfig.drawCities.any(
        (city) =>
            body == 'Sample $denomination draw is today in $city.' ||
            body == '$denomination prize bond draw is today in $city! Check your bonds now.',
      ),
    );
    final year = schedule.year;
    final month = schedule.month;
    final day = schedule.day;
    if (!hasLegacyBody || year == null || month == null || day == null) return false;

    // Both old producers used the draw date's local midnight in epoch seconds.
    // Use the saved time zone even if the device has since changed zones.
    final zone = switch (schedule.timeZone) {
      'UTC' || 'GMT' => tz.UTC,
      final name => _legacyZones[name],
    };
    if (zone == null) return false;
    final midnight = tz.TZDateTime(zone, year, month, day);
    return midnight.year == year &&
        midnight.month == month &&
        midnight.day == day &&
        content.id == midnight.millisecondsSinceEpoch ~/ 1000;
  }

  static Map<String, tz.Location> _loadLegacyZones() {
    tzdata.initializeTimeZones();
    return tz.timeZoneDatabase.locations;
  }

  Future<void> _removeWhere(bool Function(NotificationModel) matches) async {
    for (final notice in (await _device.pending()).where(matches)) {
      if (notice.content?.id case final id?) {
        try {
          await _device.cancel(id);
        } catch (_) {
          // Try every matching request and report the actual pending state below.
        }
      }
    }
    if ((await _device.pending()).any(matches)) throw StateError('A draw reminder is still pending.');
  }

  static bool _owns(NotificationModel notice, String tag, int id) => notice.content?.groupKey == tag && notice.content?.id == id;

  Future<void> _remove(String tag, int id) => _removeWhere((notice) => _owns(notice, tag, id));

  Future<void> _removeOtherOwners(String tag) => _removeWhere((notice) {
    final group = notice.content?.groupKey;
    return group != null && group.startsWith(_tagPrefix) && group != tag;
  });

  Future<Box<String>> _store(AccountStorage account) async {
    _requireActive(account);
    final box = await Hive.openBox<String>('draw_reminders_v1_${account.accountId}', crashRecovery: false);
    _requireActive(account);
    return box;
  }

  static void _requireActive(AccountStorage account) {
    if (!AuthService.canUseStorage(account)) throw const AccountException('Unlock this account to manage reminders.');
  }

  Future<bool> _allowed(AccountStorage account) async {
    final settings = await AuthService.getAllNotifPrefs(account);
    return settings['all'] == true && settings['draw'] == true;
  }

  DateTime _target(DrawResult draw) {
    final day = CatalogDraw.parseDay(draw.drawDate);
    return DateTime(day.year, day.month, day.day, _hour);
  }

  DrawResult? _verified(String? id) => _draws.getAll().where((draw) => CatalogDraw.identityOf(draw) == id).firstOrNull;

  Future<ReminderStatus?> _deviceBlock(ReminderMode mode) async {
    if (!await _device.canNotify()) return ReminderStatus.permissionDenied;
    if (!await _device.isDrawChannelEnabled()) return ReminderStatus.channelUnavailable;
    if (mode == ReminderMode.exact && !await _device.canUseExactTiming()) return ReminderStatus.exactUnavailable;
    return null;
  }

  Future<ReminderResult> status(AccountStorage account, DrawResult draw) => _forDraw(account, draw, (
    box,
    key,
    verified,
  ) async {
    final request = _Request.read(box.get(key));
    if (!_target(verified).isAfter(_clock())) return ReminderResult(ReminderStatus.expired, mode: request?.mode);
    if (request == null) return const ReminderResult(ReminderStatus.none);
    if (request.cancelled) return ReminderResult(ReminderStatus.failed, mode: request.mode, cancellationPending: true);
    if (!await _allowed(account)) return ReminderResult(ReminderStatus.muted, mode: request.mode);
    await _prepare();
    final blocked = await _deviceBlock(request.mode);
    if (blocked != null) return ReminderResult(blocked, mode: request.mode);
    final calendar = await _calendar(_target(verified), request.mode);
    final pending = await _device.pending();
    _requireActive(account);
    final registered = pending.any(
      (item) => _owns(item, _ownerTag(account.accountId), request.id) && _sameCalendar(item.schedule, calendar),
    );
    return ReminderResult(registered ? ReminderStatus.scheduled : ReminderStatus.suspended, mode: request.mode);
  });

  Future<ReminderResult> schedule(AccountStorage account, DrawResult draw, {ReminderMode? mode}) =>
      _forDraw(account, draw, (box, key, verified) async {
        final previous = _Request.read(box.get(key));
        if (previous?.cancelled == true) {
          return ReminderResult(ReminderStatus.failed, mode: previous?.mode, cancellationPending: true);
        }
        final chosen = mode ?? previous?.mode ?? ReminderMode.exact;
        final result = await _schedule(account, box, key, verified, chosen, previous, retrySuspensions: true);
        if (result.status == ReminderStatus.scheduled) {
          final saved = _Request.read(box.get(key))!;
          try {
            await NotificationService().recordDrawReminder(account, verified, saved.id);
          } catch (error) {
            // The native reminder has already been confirmed.
            debugPrint('Could not write reminder confirmation to the inbox (${error.runtimeType}).');
          }
        }
        return result;
      });

  Future<ReminderResult> cancel(AccountStorage account, DrawResult draw) => _forDraw(account, draw, (box, key, _) async {
    final request = _Request.read(box.get(key));
    if (request == null) return const ReminderResult(ReminderStatus.cancelled);
    try {
      _requireActive(account);
      await box.put(key, _Request(request.id, request.mode, cancelled: true).encode());
      await box.flush();
      await _prepare();
      await _remove(_ownerTag(account.accountId), request.id);
      _requireActive(account);
      await box.delete(key);
      return const ReminderResult(ReminderStatus.cancelled);
    } on AccountException {
      rethrow;
    } catch (_) {
      return ReminderResult(ReminderStatus.failed, mode: request.mode, cancellationPending: true);
    }
  });

  Future<ReminderResult> _forDraw(
    AccountStorage account,
    DrawResult draw,
    Future<ReminderResult> Function(Box<String>, String, DrawResult) action,
  ) => _serialize(() async {
    Box<String>? box;
    String? key;
    try {
      _requireActive(account);
      key = CatalogDraw.identityOf(draw);
      final verified = key == null ? null : _verified(key);
      if (key == null || verified == null) return const ReminderResult(ReminderStatus.invalidDraw);
      box = await _store(account);
      final result = await action(box, key, verified);
      _requireActive(account);
      return result;
    } on AccountException {
      return const ReminderResult(ReminderStatus.suspended);
    } catch (error) {
      debugPrint('Draw reminder operation failed (${error.runtimeType}).');
      if (box == null || !AuthService.canUseStorage(account)) return const ReminderResult(ReminderStatus.failed);
      try {
        final saved = _Request.read(box.get(key));
        return ReminderResult(ReminderStatus.failed, mode: saved?.mode, cancellationPending: saved?.cancelled == true);
      } catch (_) {
        return const ReminderResult(ReminderStatus.failed);
      }
    }
  });

  Future<int> _allocateId(List<NotificationModel> pending) async {
    final counter = await Hive.openBox<int>('draw_reminder_ids_v1', crashRecovery: false);
    final inUse = pending.map((notice) => notice.content?.id).toSet();
    var id = counter.get('next') ?? _firstId;
    while (inUse.contains(id)) {
      id++;
    }
    if (id < _firstId || id > _lastId) throw StateError('No reminder identifiers are available.');
    await counter.put('next', id + 1);
    await counter.flush();
    return id;
  }

  Future<_Request> _save(
    AccountStorage account,
    Box<String> box,
    String key,
    ReminderMode mode,
    _Request? previous,
    List<NotificationModel> pending, {
    bool replaceConflictingId = false,
  }) async {
    if (!replaceConflictingId && previous?.mode == mode) return previous!;
    final previousId = replaceConflictingId ? null : previous?.id;
    final request = _Request(previousId ?? await _allocateId(pending), mode);
    _requireActive(account);
    await box.put(key, request.encode());
    await box.flush();
    return request;
  }

  Future<ReminderResult> _schedule(
    AccountStorage account,
    Box<String> box,
    String key,
    DrawResult draw,
    ReminderMode mode,
    _Request? existing, {
    bool retrySuspensions = false,
  }) async {
    final target = _target(draw);
    final tag = _ownerTag(account.accountId);
    if (!target.isAfter(_clock())) return ReminderResult(ReminderStatus.expired, mode: existing?.mode);
    // Keep an explicitly accepted approximate mode even when the plugin is unavailable.
    if (mode == ReminderMode.approximate && existing?.mode != mode) {
      existing = await _save(account, box, key, mode, existing, const []);
    }
    if (!await _allowed(account)) return ReminderResult(ReminderStatus.muted, mode: existing?.mode);

    await _prepare();
    _requireActive(account);
    if (retrySuspensions) await _removeOtherOwners(tag);
    final blocked = await _deviceBlock(mode);
    if (blocked != null) {
      if (existing != null) await _remove(tag, existing.id);
      return ReminderResult(blocked, mode: existing?.mode);
    }

    final calendar = await _calendar(target, mode);
    final pending = await _device.pending();
    var request = await _save(account, box, key, mode, existing, pending);
    if (pending.any((notice) => notice.content?.id == request.id && !_owns(notice, tag, request.id))) {
      request = await _save(account, box, key, mode, request, pending, replaceConflictingId: true);
    }
    _requireActive(account);
    final current = pending.where((notice) => _owns(notice, tag, request.id)).firstOrNull;
    if (current != null && _sameCalendar(current.schedule, calendar)) {
      return ReminderResult(ReminderStatus.alreadyScheduled, mode: mode);
    }
    if (current != null) await _remove(tag, request.id);
    if (!await _allowed(account)) return ReminderResult(ReminderStatus.muted, mode: mode);
    if (!target.isAfter(_clock())) return ReminderResult(ReminderStatus.expired, mode: mode);
    _requireActive(account);

    final content = NotificationContent(
      id: request.id,
      channelKey: _channel,
      groupKey: tag,
      title: 'Prize Bond Checker reminder',
      body: 'Unlock the app to view your reminder.',
      category: NotificationCategory.Reminder,
    );
    var accepted = false;
    try {
      accepted = await _device.schedule(content, calendar);
    } catch (error) {
      debugPrint('Native draw scheduling returned an error (${error.runtimeType}).');
    } finally {
      if (!AuthService.canUseStorage(account)) await _remove(tag, request.id);
    }
    _requireActive(account);
    if (!await _allowed(account)) {
      await _remove(tag, request.id);
      return ReminderResult(ReminderStatus.muted, mode: mode);
    }
    final blockedAfterSchedule = await _deviceBlock(mode);
    if (blockedAfterSchedule != null) {
      await _remove(tag, request.id);
      return ReminderResult(blockedAfterSchedule, mode: mode);
    }
    final installed = (await _device.pending()).where((notice) => _owns(notice, tag, request.id)).firstOrNull;
    final confirmed = _sameCalendar(installed?.schedule, calendar);
    if (installed != null && !confirmed) await _remove(tag, request.id);
    if (!AuthService.canUseStorage(account)) {
      await _remove(tag, request.id);
      return ReminderResult(ReminderStatus.suspended, mode: mode);
    }
    if (!accepted && confirmed) debugPrint('The pending list confirmed a draw reminder despite the native error result.');
    return ReminderResult(confirmed ? ReminderStatus.scheduled : ReminderStatus.failed, mode: mode);
  }

  Future<NotificationCalendar> _calendar(DateTime target, ReminderMode mode) async => NotificationCalendar(
    year: target.year,
    month: target.month,
    day: target.day,
    hour: target.hour,
    minute: 0,
    second: 0,
    repeats: false,
    allowWhileIdle: true,
    preciseAlarm: mode == ReminderMode.exact,
    timeZone: await _device.localTimeZone(),
  );

  static bool _sameCalendar(NotificationSchedule? left, NotificationCalendar right) =>
      left is NotificationCalendar &&
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day &&
      left.hour == right.hour &&
      left.minute == right.minute &&
      left.second == right.second &&
      left.repeats == right.repeats &&
      left.timeZone == right.timeZone &&
      left.preciseAlarm == right.preciseAlarm;

  Future<bool> reconcile(AccountStorage account) => _serialize(() async {
    try {
      _requireActive(account);
      await _prepare();
      final tag = _ownerTag(account.accountId);
      await _removeOtherOwners(tag);
      if (!await _allowed(account)) {
        await _removeWhere((notice) => notice.content?.groupKey == tag);
        return true;
      }
      final box = await _store(account);
      final draws = {for (final draw in _draws.getAll()) CatalogDraw.identityOf(draw): draw};
      var complete = true;
      for (final key in box.keys.cast<String>().toList()) {
        _requireActive(account);
        try {
          final request = _Request.read(box.get(key))!;
          final draw = draws[key];
          if (request.cancelled || (draw != null && !_target(draw).isAfter(_clock()))) {
            await _remove(tag, request.id);
            _requireActive(account);
            await box.delete(key);
          } else if (draw == null) {
            // Temporarily unavailable draws may be repaired. Keep the saved mode.
            await _remove(tag, request.id);
          } else {
            final result = await _schedule(account, box, key, draw, request.mode, request);
            if (result.status == ReminderStatus.failed) complete = false;
          }
        } on AccountException {
          rethrow;
        } catch (_) {
          complete = false;
        }
      }
      return complete;
    } on AccountException {
      return false;
    } catch (error) {
      debugPrint('Could not restore draw reminders (${error.runtimeType}).');
      return false;
    }
  });

  Future<void> openSettings(AccountStorage account, {required bool exactAlarms}) async {
    _requireActive(account);
    await _device.openSettings(exactAlarms: exactAlarms);
  }
}

class _Request {
  const _Request(this.id, this.mode, {this.cancelled = false});

  final int id;
  final ReminderMode mode;
  final bool cancelled;

  String encode() => jsonEncode([id, mode.name, cancelled]);

  static _Request? read(String? raw) {
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded case [
      final int id,
      final String mode,
      final bool cancelled,
    ] when id >= DrawReminderService._firstId && id <= DrawReminderService._lastId) {
      return _Request(id, ReminderMode.values.byName(mode), cancelled: cancelled);
    }
    throw const FormatException('Invalid draw reminder request.');
  }
}
