import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/models/notification_model.dart' as inbox;
import 'package:prize_bond_checking_app/models/prize_entry_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/draw_catalog.dart';
import 'package:prize_bond_checking_app/services/draw_reminder_service.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory data;
  late DateTime now;
  late _Platform platform;
  late DrawService draws;
  late DrawReminderService service;
  late DrawResult first;
  late DrawResult second;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    data = await Directory.systemTemp.createTemp('draw-reminders-');
    Hive.init(data.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(DrawResultAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BondAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CheckRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(inbox.NotificationModelAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(PrizeEntryAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
    await Hive.openBox<DrawResult>('draws');
    final catalog = DrawCatalog.parse(jsonEncode([_row('81', 'Rs. 100'), _row('82', 'Rs. 200')]), version: 1, expectedCount: 2);
    now = DateTime(2026, 11, 24);
    draws = DrawService(catalog: catalog, clock: () => now);
    await draws.importCatalog(catalog);
    first = draws.getAll().singleWhere((draw) => draw.drawNumber == '81');
    second = draws.getAll().singleWhere((draw) => draw.drawNumber == '82');
    platform = _Platform();
    service = DrawReminderService.withPlatform(platform, draws: draws, clock: () => now);
    await AuthService.openAccounts();
    AuthService.resumeFromBackground();
    await AuthService.restoreSelection();
  });

  tearDown(() async {
    await AuthService.logout();
    await Hive.close();
    await data.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });

  test('Same-day draws have distinct identities and repeat requests use one native schedule', () async {
    final account = await _unlock(await _member('same-day'));
    final results = await Future.wait([service.schedule(account, first), service.schedule(account, first)]);
    expect(results.map((result) => result.status), [ReminderStatus.scheduled, ReminderStatus.alreadyScheduled]);
    expect((await service.schedule(account, second)).status, ReminderStatus.scheduled);
    expect(platform.models, hasLength(2));
    expect(platform.requests, hasLength(2));
    expect(account.notifications.length, 2);
    for (final model in platform.models.values) {
      expect(model.content!.body, 'Unlock the app to view your reminder.');
      expect(model.content!.title, 'Prize Bond Checker reminder');
      expect(model.content!.groupKey, isNot(contains(account.accountId)));
      expect(model.content!.payload, isNull);
      final schedule = model.schedule! as NotificationCalendar;
      expect([schedule.year, schedule.month, schedule.day, schedule.hour], [2026, 12, 1, 8]);
      expect(schedule.repeats, isFalse);
    }
    expect((await service.cancel(account, first)).status, ReminderStatus.cancelled);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, hasLength(1));
    expect(account.notifications.length, 2);
    await NotificationService().clearAll(account);
    expect((await service.schedule(account, second)).status, ReminderStatus.alreadyScheduled);
    expect(account.notifications.isEmpty, isTrue);
  });

  test('Approximate consent survives a failed native request, reopening the store, and restart', () async {
    final account = await _unlock(await _member('approximate'));
    platform.exact = false;
    expect((await service.schedule(account, first)).status, ReminderStatus.exactUnavailable);
    expect(platform.requests, isEmpty);

    platform.scheduleAllowed = false;
    final failed = await service.schedule(account, first, mode: ReminderMode.approximate);
    expect(failed.status, ReminderStatus.failed);
    expect(failed.mode, ReminderMode.approximate);
    expect(account.notifications.isEmpty, isTrue);
    await Hive.box<String>('draw_reminders_v1_${account.accountId}').close();
    final restarted = DrawReminderService.withPlatform(platform, draws: draws, clock: () => now);
    platform.scheduleAllowed = true;
    platform.exact = true;
    expect(await restarted.reconcile(account), isTrue);
    final id = platform.models.keys.single;
    expect(platform.models[id]!.schedule!.preciseAlarm, isFalse);
    expect((await restarted.status(account, first)).mode, ReminderMode.approximate);
    expect(account.notifications.isEmpty, isTrue); // Restoration does not create inbox confirmations.

    platform.zone = 'Asia/Karachi';
    expect(await restarted.reconcile(account), isTrue);
    expect(platform.models.keys.single, id);
    expect(platform.models[id]!.schedule!.timeZone, 'Asia/Karachi');
    expect(platform.models[id]!.schedule!.preciseAlarm, isFalse);
  });

  test('Exact mode is suspended on capability loss and restored unchanged on permission recovery', () async {
    final account = await _unlock(await _member('exact'));
    expect((await service.schedule(account, first)).status, ReminderStatus.scheduled);
    final id = platform.models.keys.single;
    platform.exact = false;
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
    final blocked = await service.status(account, first);
    expect(blocked.status, ReminderStatus.exactUnavailable);
    expect(blocked.mode, ReminderMode.exact);
    expect((await service.schedule(account, first)).status, ReminderStatus.exactUnavailable);
    expect(platform.requests, hasLength(1));
    platform.exact = true;
    expect(await service.reconcile(account), isTrue);
    expect(platform.models.keys.single, id);
    expect(platform.models.values.single.schedule!.preciseAlarm, isTrue);
  });

  test('Device denial and muted preferences suspend pending reminders and leave the inbox', () async {
    final account = await _unlock(await _member('permission'));
    platform.notify = false;
    expect((await service.schedule(account, first)).status, ReminderStatus.permissionDenied);
    expect(platform.requests, isEmpty);
    expect(account.notifications.isEmpty, isTrue);
    platform.notify = true;

    await AuthService.setNotifPref(account, 'draw', false);
    expect((await service.schedule(account, first)).status, ReminderStatus.muted);
    expect(platform.requests, isEmpty);
    await AuthService.setNotifPref(account, 'draw', true);
    expect((await service.schedule(account, first)).status, ReminderStatus.scheduled);
    final id = platform.models.keys.single;

    await AuthService.setNotifPref(account, 'all', false);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
    expect(account.notifications.length, 1);
    await AuthService.setNotifPref(account, 'all', true);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models.keys.single, id);

    platform.notify = false;
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
    expect(account.notifications.length, 1);
    platform.notify = true;
    expect(await service.reconcile(account), isTrue);
    expect(platform.models.keys.single, id);
  });

  test('A disabled draw channel is separate from app and exact-alarm permission', () async {
    final account = await _unlock(await _member('channel-disabled'));
    platform.notify = false;
    platform.channelEnabled = false;
    platform.exact = false;
    expect((await service.schedule(account, first)).status, ReminderStatus.permissionDenied);
    platform.notify = true;
    expect((await service.schedule(account, first)).status, ReminderStatus.channelUnavailable);
    platform.channelEnabled = true;
    expect((await service.schedule(account, first)).status, ReminderStatus.exactUnavailable);
    expect(platform.requests, isEmpty);

    expect((await service.schedule(account, first, mode: ReminderMode.approximate)).status, ReminderStatus.scheduled);
    final id = platform.models.keys.single;
    platform.channelEnabled = false;
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
    final blocked = await service.status(account, first);
    expect(blocked.status, ReminderStatus.channelUnavailable);
    expect(blocked.mode, ReminderMode.approximate);
    platform.channelEnabled = true;
    platform.exact = true;
    expect(await service.reconcile(account), isTrue);
    expect(platform.models.keys.single, id);
    expect(platform.models[id]!.schedule!.preciseAlarm, isFalse);
    expect((await service.cancel(account, first)).status, ReminderStatus.cancelled);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
  });

  test('A channel disabled during scheduling removes the native request and keeps exact mode', () async {
    final account = await _unlock(await _member('channel-disabled-during-schedule'));
    platform.beforeSchedule = () async => platform.channelEnabled = false;
    final result = await service.schedule(account, first);
    expect(result.status, ReminderStatus.channelUnavailable);
    expect(result.mode, ReminderMode.exact);
    expect(platform.models, isEmpty);
    expect(account.notifications.isEmpty, isTrue);
    platform.beforeSchedule = null;
    platform.channelEnabled = true;
    expect(await service.reconcile(account), isTrue);
    expect(platform.models.values.single.schedule!.preciseAlarm, isTrue);
  });

  test('A cancellation failure is retryable and the saved cancellation is not rearmed', () async {
    final account = await _unlock(await _member('cancel'));
    await service.schedule(account, first);
    final id = platform.models.keys.single;
    platform.cancelFails = true;
    final failed = await service.cancel(account, first);
    expect(failed.cancellationPending, isTrue);
    expect(platform.models.containsKey(id), isTrue);
    expect(await service.reconcile(account), isFalse);
    expect(platform.requests, hasLength(1));
    platform.cancelFails = false;
    expect((await service.cancel(account, first)).status, ReminderStatus.cancelled);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
    expect(platform.requests, hasLength(1));
  });

  test('Startup cancels both legacy formats while signed out and preserves native schedules and both inboxes', () async {
    final member = await _member('legacy-reminders');
    final account = await _unlock(member);
    final ownerless = await Hive.openBox<inbox.NotificationModel>('notifications');
    final privateInbox = Hive.box<inbox.NotificationModel>('notifications_${member.id}');
    await ownerless.put('older-reminder', _inboxReminder('older-reminder', isRead: true));
    await account.notifications.addIfAbsent('sample-reminder', _inboxReminder('sample-reminder', isRead: false));
    final beforeOwnerless = _inboxContents(ownerless);
    final beforePrivate = _inboxContents(privateInbox);
    await AuthService.logout();
    expect(AuthService.unlockedStorage, isNull);

    final utcId = DateTime.utc(2026, 12, 1).millisecondsSinceEpoch ~/ 1000;
    final karachiId = DateTime.utc(2026, 11, 30, 19).millisecondsSinceEpoch ~/ 1000;
    final unrelatedTitleId = DateTime.utc(2026, 12, 2).millisecondsSinceEpoch ~/ 1000;
    final unrelatedBodyId = DateTime.utc(2026, 12, 3).millisecondsSinceEpoch ~/ 1000;
    final unrelatedTimingId = DateTime.utc(2026, 12, 4).millisecondsSinceEpoch ~/ 1000;
    const unrelatedId = 42;
    final unrelated = {
      unrelatedTitleId: _legacyNotice(unrelatedTitleId, day: 2, title: 'Other scheduled event'),
      unrelatedBodyId: _legacyNotice(unrelatedBodyId, day: 3, body: 'Sample class is today in Lahore.'),
      unrelatedTimingId: _legacyNotice(unrelatedTimingId, day: 4, minute: 30),
      unrelatedId: _legacyNotice(unrelatedId),
    };
    platform.models.addAll({
      utcId: _legacyNotice(utcId),
      karachiId: _legacyNotice(
        karachiId,
        timeZone: 'Asia/Karachi',
        body: 'Rs. 200 prize bond draw is today in Islamabad! Check your bonds now.',
      ),
      ...unrelated,
    });

    expect(await service.start(), isTrue);
    expect(platform.cancellations, unorderedEquals([utcId, karachiId]));
    expect(platform.models, unrelated);
    expect(platform.requests, isEmpty);
    expect(AuthService.unlockedStorage, isNull);
    expect(Hive.isBoxOpen('draw_reminders_v1_${member.id}'), isFalse);
    expect(_inboxContents(ownerless), beforeOwnerless);
    expect(_inboxContents(privateInbox), beforePrivate);
    expect((await _unlock(member)).notifications.values.single.id, 'sample-reminder');
  });

  test('Elapsed reminders do not rearm', () async {
    final account = await _unlock(await _member('elapsed'));
    expect((await service.schedule(account, first)).status, ReminderStatus.scheduled);
    now = DateTime(2026, 12, 1, 8);
    expect((await service.schedule(account, first)).status, ReminderStatus.expired);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
  });

  test('A failed old-owner suspension is retried without reading or cancelling the new owner’s reminders', () async {
    final alice = await _member('alice');
    final bob = await _member('bob');
    final a = await _unlock(alice);
    await service.schedule(a, first);
    final oldId = platform.models.keys.single;
    platform.cancelFails = true;
    final b = await _unlock(bob);
    expect(await service.suspend(a), isFalse);
    expect(await service.reconcile(b), isFalse);
    expect((await service.cancel(a, first)).status, ReminderStatus.suspended);
    expect(platform.models.keys, [oldId]);
    platform.cancelFails = false;
    expect(await service.reconcile(b), isTrue);
    expect(platform.models, isEmpty);
    expect((await service.status(b, first)).status, ReminderStatus.none);
    await service.schedule(b, first);
    final bobId = platform.models.keys.single;
    expect(bobId, isNot(oldId));
    expect(await service.suspend(a), isTrue);
    expect(platform.models.keys, [bobId]);

    final restored = await _unlock(alice);
    expect(await service.reconcile(restored), isTrue);
    expect(platform.models.keys, [oldId]);
    expect(restored.notifications.length, 1);
  });

  test('Native success arriving after lock is cancelled before the request can report success', () async {
    final owner = await _member('in-flight');
    final account = await _unlock(owner);
    final gate = Completer<void>();
    final started = Completer<void>();
    platform.beforeSchedule = () {
      started.complete();
      return gate.future;
    };
    final operation = service.schedule(account, first);
    await started.future;
    AuthService.lockForBackground();
    gate.complete();
    expect((await operation).status, ReminderStatus.suspended);
    expect(platform.models, isEmpty);
    expect(platform.cancellations, hasLength(1));

    platform.beforeSchedule = null;
    AuthService.resumeFromBackground();
    final restored = await _unlock(owner);
    expect(restored.notifications.isEmpty, isTrue);
    expect(await service.reconcile(restored), isTrue);
    expect(platform.models, hasLength(1));
  });

  test('Cold startup removes a stale native schedule before the owner can restore it', () async {
    final owner = await _member('restart');
    final account = await _unlock(owner);
    await service.schedule(account, first, mode: ReminderMode.approximate);
    final id = platform.models.keys.single;
    await AuthService.logout(); // Simulate termination before the platform received cancellation.
    expect(platform.models.keys, [id]);

    await Hive.box<String>('draw_reminders_v1_${account.accountId}').close();
    final restarted = DrawReminderService.withPlatform(platform, draws: draws, clock: () => now);
    expect(await restarted.start(), isTrue);
    expect(platform.models, isEmpty);
    final restored = await _unlock(owner);
    expect(await restarted.reconcile(restored), isTrue);
    expect(platform.models.keys, [id]);
    expect(platform.models[id]!.schedule!.preciseAlarm, isFalse);
    expect(restored.notifications.length, 1);
  });

  test('Retry uses the pending list to distinguish a native acknowledgment failure from a missing schedule', () async {
    final account = await _unlock(await _member('native-ack'));
    platform.acknowledge = false;
    expect((await service.schedule(account, first)).status, ReminderStatus.scheduled);
    expect(platform.models, hasLength(1));
    expect(account.notifications.length, 1);
    expect((await service.schedule(account, first)).status, ReminderStatus.alreadyScheduled);
    expect(platform.requests, hasLength(1));
  });

  test('An approximate request with a conflicting provisional ID leaves the existing native schedule intact', () async {
    final account = await _unlock(await _member('id-collision'));
    const occupiedId = 1 << 28;
    final unrelated = _legacyNotice(occupiedId, title: 'Other scheduled event');
    platform.models[occupiedId] = unrelated;
    final result = await service.schedule(account, first, mode: ReminderMode.approximate);
    expect(result.status, ReminderStatus.scheduled);
    expect(platform.models[occupiedId], same(unrelated));
    expect(platform.requests.single, isNot(occupiedId));
    expect((await service.schedule(account, first)).status, ReminderStatus.alreadyScheduled);
    expect(platform.requests, hasLength(1));
  });

  test('A temporarily missing sample draw suspends its reminder without losing the accepted mode', () async {
    final account = await _unlock(await _member('missing-draw'));
    await service.schedule(account, first, mode: ReminderMode.approximate);
    final id = platform.models.keys.single;
    final box = Hive.box<DrawResult>('draws');
    final drawKey = first.key;
    await box.delete(drawKey);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models, isEmpty);
    expect((await service.schedule(account, first)).status, ReminderStatus.invalidDraw);

    await box.put(drawKey, first);
    expect(await service.reconcile(account), isTrue);
    expect(platform.models.keys.single, id);
    expect(platform.models[id]!.schedule!.preciseAlarm, isFalse);
  });
}

NotificationModel _legacyNotice(
  int id, {
  String title = '📅 Draw Day Reminder',
  String body = 'Sample Rs. 100 draw is today in Hyderabad.',
  String timeZone = 'UTC',
  int day = 1,
  int minute = 0,
}) => NotificationModel(
  content: NotificationContent(
    id: id,
    channelKey: 'draw_channel',
    title: title,
    body: body,
    category: NotificationCategory.Reminder,
  ),
  schedule: NotificationCalendar(
    year: 2026,
    month: 12,
    day: day,
    hour: 8,
    minute: minute,
    second: 0,
    timeZone: timeZone,
    allowWhileIdle: true,
  ),
);

inbox.NotificationModel _inboxReminder(String id, {required bool isRead}) => inbox.NotificationModel()
  ..id = id
  ..typeIndex = 1
  ..title = '📅 Draw Day Reminder'
  ..body = 'Saved reminder for $id'
  ..timestamp = DateTime.utc(2026, 11, 24)
  ..isRead = isRead;

Map<Object?, Object> _inboxContents(Box<inbox.NotificationModel> box) => box.toMap().map(
  (key, entry) => MapEntry(key, (entry.id, entry.typeIndex, entry.title, entry.body, entry.timestamp, entry.isRead)),
);

Map<String, Object> _row(String drawNumber, String denomination) => {
  'drawNumber': drawNumber,
  'denomination': denomination,
  'drawDate': 'December 1, 2026',
  'city': 'Lahore',
  'status': 'upcoming',
  'daysLeft': 7,
  'firstPrize': '001234',
  'firstPrizeAmount': 'Rs. 100',
  'totalPrizes': '1',
  'prizeWinners': [
    {'number': '001234', 'position': '1st Prize', 'amount': 'Rs. 100'},
  ],
};

Future<AccountSummary> _member(String name) async {
  final account = (await AuthService.registerUser(
    firstName: 'Reminder',
    lastName: 'Fixture',
    mobile: '123',
    email: '$name@example.org',
    pin: '0123',
    address: 'Demo address',
    city: 'Lahore',
  )).account;
  final users = Hive.box<UserProfile>('users');
  await users.put(account.id, users.get(account.id)!.copyWith(isApproved: true));
  return account;
}

Future<AccountStorage> _unlock(AccountSummary account) async {
  await AuthService.selectAccount(account.email);
  return (await AuthService.unlock(account.id, '0123'))!;
}

class _Platform implements ReminderPlatform {
  final models = <int, NotificationModel>{};
  final requests = <int>[];
  final cancellations = <int>[];
  bool notify = true;
  bool channelEnabled = true;
  bool exact = true;
  bool scheduleAllowed = true;
  bool acknowledge = true;
  bool cancelFails = false;
  String zone = 'UTC';
  Future<void> Function()? beforeSchedule;

  @override
  Future<bool> prepare() async => true;
  @override
  Future<bool> canNotify() async => notify;
  @override
  Future<bool> isDrawChannelEnabled() async => channelEnabled;
  @override
  Future<bool> canUseExactTiming() async => exact;
  @override
  Future<String> localTimeZone() async => zone;
  @override
  Future<List<NotificationModel>> pending() async => models.values.toList();
  @override
  Future<bool> schedule(NotificationContent content, NotificationCalendar calendar) async {
    requests.add(content.id!);
    await beforeSchedule?.call();
    if (!scheduleAllowed) return false;
    models[content.id!] = NotificationModel(content: content, schedule: calendar);
    return acknowledge;
  }

  @override
  Future<void> cancel(int id) async {
    cancellations.add(id);
    if (cancelFails) throw StateError('Injected cancellation failure.');
    models.remove(id);
  }

  @override
  Future<void> openSettings({required bool exactAlarms}) async {}
}
