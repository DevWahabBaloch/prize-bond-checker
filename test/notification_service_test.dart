import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/notification_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the preference persistence failure at the plugin boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _channel = MethodChannel('awesome_notifications');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory data;
  late List<Map<Object?, Object?>> sent;
  late bool permission;
  late Future<bool> Function()? permissionProbe;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AwesomeNotificationsPlatform.operatingSystem = 'android';
    AwesomeNotificationsPlatform.resetInstance();
    sent = [];
    permission = true;
    permissionProbe = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      return switch (call.method) {
        'initialize' => true,
        'getLocalTimeZoneIdentifier' || 'getUtcTimeZoneIdentifier' => 'UTC',
        'dismissNotificationsByChannelKey' => null,
        'isNotificationAllowed' => await permissionProbe?.call() ?? permission,
        'createNewNotification' => _record(sent, call),
        _ => throw MissingPluginException(call.method),
      };
    });
    SharedPreferences.setMockInitialValues({'device_notification_permission_requested': true});
    FlutterSecureStorage.setMockInitialValues({});
    data = await Directory.systemTemp.createTemp('device-notification-preferences-');
    Hive.init(data.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BondAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CheckRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationModelAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
    await AuthService.openAccounts();
    AuthService.resumeFromBackground();
    await AuthService.restoreSelection();
    await NotificationService().initializeDeviceNotifications();
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    AwesomeNotificationsPlatform.operatingSystem = Platform.operatingSystem;
    AwesomeNotificationsPlatform.resetInstance();
    debugDefaultTargetPlatformOverride = null;
    await AuthService.logout();
    await Hive.close();
    await data.delete(recursive: true);
  });

  test('Master and category switches control device alerts while the inbox keeps account-specific notices', () async {
    final alice = await _member('alice');
    final bob = await _member('bob');
    final a = await _unlock(alice);
    await AuthService.setNotifPref(a, 'all', false);
    await _win(a, 'muted-win');
    await _draw(a, 'muted-draw');
    expect(sent, isEmpty);
    expect(a.notifications.length, 2);

    await AuthService.setNotifPref(a, 'all', true);
    await AuthService.setNotifPref(a, 'win', false);
    await _win(a, 'win-switch-off');
    await _draw(a, 'draw-switch-on');
    expect(sent.map(_channelKey), ['draw_channel']);

    await AuthService.setNotifPref(a, 'draw', false);
    await AuthService.setNotifPref(a, 'win', true);
    await _win(a, 'win-switch-on');
    await _draw(a, 'draw-switch-off');
    await NotificationService().showResultsAvailableNotification(
      a,
      denomination: 'Rs. 200',
      city: 'Lahore',
      date: 'December 1, 2026',
      eventId: 'muted-results',
    );
    expect(sent.map(_channelKey), ['draw_channel', 'win_channel']);
    expect(a.notifications.length, 7);

    final b = await _unlock(bob);
    expect(b.notifications.isEmpty, isTrue);
    await _draw(b, 'draw-switch-off');
    await _win(a, 'stale-owner');
    expect(sent.map(_channelKey), ['draw_channel', 'win_channel', 'draw_channel']);
    expect(b.notifications.length, 1);
    final restored = await _unlock(alice);
    expect(restored.notifications.length, 7);
  });

  test('Device permission denial preserves the inbox and recovery does not replay old alerts', () async {
    final account = await _unlock(await _member('permission'));
    permission = false;
    await _win(account, 'missed');
    expect(sent, isEmpty);
    expect(account.notifications.length, 1);

    permission = true;
    await _win(account, 'missed');
    expect(sent, isEmpty);
    await _win(account, 'new-win');
    expect(sent.map(_channelKey), ['win_channel']);
    final content = sent.single['content']! as Map;
    expect(content['title'], 'Saved bond update');
    expect(content['body'], 'Unlock the app to view your account notification.');
    expect(account.notifications.length, 2);
  });

  test('Locking while a permission check is in flight does not send a device alert', () async {
    final account = await _unlock(await _member('revoked'));
    final started = Completer<void>();
    final gate = Completer<bool>();
    permissionProbe = () {
      started.complete();
      return gate.future;
    };
    final operation = _win(account, 'pending');
    await started.future;
    AuthService.lockForBackground();
    gate.complete(true);
    await operation;

    expect(sent, isEmpty);
    expect(account.notifications.isEmpty, isTrue);
    final stored = Hive.box<NotificationModel>('notifications_${account.accountId}');
    expect(stored.length, 1);
  });

  test('A failed preference write restores the persisted value used by delivery', () async {
    final account = await _unlock(await _member('preference-write'));
    final original = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _RejectingPreferenceStore({'flutter.notif_${account.accountId}_win': true});
    try {
      await expectLater(AuthService.setNotifPref(account, 'win', false), throwsA(isA<AccountException>()));
      expect((await AuthService.getAllNotifPrefs(account))['win'], isTrue);
      await _win(account, 'after-rejected-write');
      expect(sent.map(_channelKey), ['win_channel']);
    } finally {
      SharedPreferencesStorePlatform.instance = original;
    }
  });
}

class _RejectingPreferenceStore extends InMemorySharedPreferencesStore {
  _RejectingPreferenceStore(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;
}

bool _record(List<Map<Object?, Object?>> sent, MethodCall call) {
  sent.add(call.arguments as Map<Object?, Object?>);
  return true;
}

String _channelKey(Map<Object?, Object?> notice) => (notice['content']! as Map)['channelKey']! as String;

Future<void> _win(AccountStorage account, String event) => NotificationService().showWinNotification(
  account,
  bondNumber: '001234',
  denomination: 'Rs. 200',
  city: 'Lahore',
  eventId: event,
);

Future<void> _draw(AccountStorage account, String event) => NotificationService().showNewDrawNotification(
  account,
  denomination: 'Rs. 200',
  city: 'Lahore',
  date: 'December 1, 2026',
  eventId: event,
);

Future<AccountSummary> _member(String name) async {
  final account = (await AuthService.registerUser(
    firstName: 'Preference',
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
