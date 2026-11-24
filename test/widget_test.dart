import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart' as native;
import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/ios_privacy_cover.dart';
import 'package:prize_bond_checking_app/main.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/screens/admin/admin_screen.dart';
import 'package:prize_bond_checking_app/screens/auth/pin_screen.dart';
import 'package:prize_bond_checking_app/screens/bulk_check_screen.dart';
import 'package:prize_bond_checking_app/widgets/app_nav_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:prize_bond_checking_app/screens/auth/landing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixturePassphrase = 'fixture-only-module-2-admin';
final _configuredAdmin =
    const String.fromEnvironment('FYP_ADMIN_VERIFIER') == sha256.convert(utf8.encode(_fixturePassphrase)).toString();
const _notificationsChannel = MethodChannel('awesome_notifications');
const _privacyChannelName = 'prize_bond/session_privacy';
const _bulkImportChannel = MethodChannel('prize_bond/android_bulk_import');
const _ios = TargetPlatformVariant({TargetPlatform.iOS});

void main() {
  late Directory storage;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('prize-bond-test-');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AwesomeNotificationsPlatform.operatingSystem = 'android';
    AwesomeNotificationsPlatform.resetInstance();
  });

  tearDown(() async {
    AwesomeNotificationsPlatform.operatingSystem = Platform.operatingSystem;
    AwesomeNotificationsPlatform.resetInstance();
    await Hive.close();
    await storage.delete(recursive: true);
  });

  testWidgets('Cold start opens the app with device notifications denied', (tester) async {
    final response = Completer<List<String>>();
    final calls = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_notificationsChannel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'initialize' => true,
        'getLocalTimeZoneIdentifier' || 'getUtcTimeZoneIdentifier' => 'UTC',
        'dismissNotificationsByChannelKey' => null,
        'listAllSchedules' => [],
        'isNotificationAllowed' => false,
        'requestNotifications' => response.future,
        _ => throw MissingPluginException(call.method),
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_notificationsChannel, null));

    await tester.runAsync(() async {
      await tester.pumpWidget(PrizeBondApp(initializeHive: () async => Hive.init(storage.path)));
      await _pumpUntil(tester, () => calls.contains('requestNotifications'));
      await tester.pumpAndSettle();

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      final draws = Hive.box<DrawResult>('draws');
      expect(draws.length, 21);
      expect(draws.values.every((draw) => draw.prizeWinners.length == 10), isTrue);
      expect(AuthService.unlockedStorage, isNull);
      expect(Hive.isBoxOpen('notifications'), isFalse);

      response.complete(['Alert']);
      await tester.pumpAndSettle();
      await NotificationService().initializeDeviceNotifications();
      expect(calls.where((method) => method == 'requestNotifications'), hasLength(1));
      expect(calls, isNot(contains('createNewNotification')));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('A storage startup failure shows an actionable retry', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    var initializationFinished = false;
    messenger.setMockMethodCallHandler(_notificationsChannel, (call) async {
      if (call.method == 'getUtcTimeZoneIdentifier') {
        initializationFinished = true;
      }
      return call.method == 'initialize' ? false : 'UTC';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_notificationsChannel, null));
    var attempts = 0;

    await tester.runAsync(() async {
      await tester.pumpWidget(
        PrizeBondApp(
          initializeHive: () async {
            if (++attempts == 1) {
              throw const FileSystemException('Test storage failure');
            }
            Hive.init(storage.path);
          },
        ),
      );
      await _pumpUntil(tester, () => find.text('Retry').evaluate().isNotEmpty);
      expect(find.text('Could not open the app. Please try again.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await _pumpUntil(tester, () => initializationFinished && find.byType(LandingScreen).evaluate().isNotEmpty);
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('Register'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  void mockNotifications(WidgetTester tester, {Map<int, Map<String, dynamic>>? pending}) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_notificationsChannel, (call) async {
      return switch (call.method) {
        'initialize' => true,
        'getLocalTimeZoneIdentifier' || 'getUtcTimeZoneIdentifier' => 'UTC',
        'isNotificationAllowed' => true,
        'dismissNotificationsByChannelKey' => null,
        'createNewNotification' => true,
        'listAllSchedules' => pending?.values.toList() ?? [],
        'cancelSchedule' => pending?.remove(call.arguments as int),
        _ => throw MissingPluginException(call.method),
      };
    });
    const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
    const connectivityStream = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
    messenger.setMockMethodCallHandler(connectivity, (_) async => <String>['wifi']);
    messenger.setMockMethodCallHandler(connectivityStream, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(_notificationsChannel, null);
      messenger.setMockMethodCallHandler(connectivity, null);
      messenger.setMockMethodCallHandler(connectivityStream, null);
    });
  }

  testWidgets(
    'Android picker result restores only after the owning PIN and starts no automatic check',
    (tester) async {
      mockNotifications(tester);
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late AccountSummary alice;
      late AccountSummary bob;
      final receipts = <String, Map<String, Object?>>{};
      final loads = <String>[];
      final cleared = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_bulkImportChannel, (call) async {
        final owner = call.arguments['owner'] as String;
        switch (call.method) {
          case 'open':
            expect(AuthService.requireStorage().accountId, owner);
            receipts[owner] = {
              ...Map<String, Object?>.from(call.arguments['draft'] as Map),
              'request': 41,
              'status': 'picking',
            };
            return 41;
          case 'denomination':
            expect(AuthService.requireStorage().accountId, owner);
            return receipts[owner]?['denomination'];
          case 'load':
            expect(AuthService.requireStorage().accountId, owner);
            loads.add(owner);
            return receipts[owner];
          case 'clear':
            expect(AuthService.requireStorage().accountId, owner);
            expect(call.arguments['request'], 41);
            cleared.add(owner);
            receipts.remove(owner);
            return null;
        }
        throw MissingPluginException(call.method);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_bulkImportChannel, null));

      Future<void> enterPin(String pin) async {
        for (final digit in pin.split('')) {
          await tester.tap(find.text(digit));
        }
      }

      void lifecycle(List<AppLifecycleState> states) {
        for (final state in states) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      await tester.runAsync(() async {
        await tester.pumpWidget(
          PrizeBondApp(
            initializeHive: () async {
              Hive.init(storage.path);
              if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
              await AuthService.openAccounts();
              final previous = debugDefaultTargetPlatformOverride;
              debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
              try {
                alice = (await _createMember()).account;
                bob = (await _createMember(email: 'second-member@example.org')).account;
              } finally {
                debugDefaultTargetPlatformOverride = previous;
              }
              final users = Hive.box<UserProfile>('users');
              for (final account in [alice, bob]) {
                await users.put(account.id, users.get(account.id)!.copyWith(isApproved: true));
              }
              await AuthService.selectAccount(alice.email);
            },
          ),
        );
        await _pumpUntil(tester, () => find.byType(PinScreen).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await enterPin('0123');
        await _pumpUntil(tester, () => find.byType(MainNavigationScreen).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Check Bond'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Upload List'));
        await tester.tap(find.text('Upload List'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '001235');
        await tester.tap(find.text('Pick TXT or CSV File'));
        await _pumpUntil(tester, () => receipts[alice.id] != null);

        lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]);
        await tester.pump();
        expect(AuthService.unlockedStorage, isNull);
        expect(find.byType(BulkCheckScreen), findsNothing);
        receipts[alice.id]!.addAll({
          'status': 'selected',
          'selectedName': 'owner-only.csv',
          'selectedBytes': Uint8List.fromList(utf8.encode('001234\n001235\n001234')),
        });
        lifecycle([AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]);
        await tester.pumpAndSettle();
        expect(find.byType(PinScreen), findsOneWidget);
        expect(find.text('owner-only.csv'), findsNothing);
        final priorLoads = loads.length;

        await AuthService.selectAccount(bob.email);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(PrizeBondApp(initializeHive: () async {}));
        await _pumpUntil(tester, () => find.byType(PinScreen).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await enterPin('0123');
        await _pumpUntil(tester, () => find.byType(MainNavigationScreen).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(AuthService.requireStorage().accountId, bob.id);
        expect(find.byType(BulkCheckScreen), findsNothing);
        expect(loads, hasLength(priorLoads));
        expect(receipts.keys, [alice.id]);

        await tester.pumpWidget(const SizedBox.shrink());
        AuthService.resumeFromBackground();
        await AuthService.selectAccount(alice.email);
        await tester.pumpWidget(PrizeBondApp(initializeHive: () async {}));
        await _pumpUntil(tester, () => find.byType(PinScreen).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        await enterPin('4321');
        await _pumpUntil(tester, () => find.textContaining('Incorrect PIN').evaluate().isNotEmpty);
        expect(find.text('owner-only.csv'), findsNothing);
        await enterPin('0123');
        await _pumpUntil(tester, () => find.text('owner-only.csv').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        final ownerStorage = AuthService.requireStorage();
        expect(ownerStorage.accountId, alice.id);
        expect(ownerStorage.history.isEmpty, isTrue);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '001235');
        await tester.ensureVisible(find.text('Check All'));
        await tester.tap(find.text('Check All'));
        await _pumpUntil(tester, () => ownerStorage.history.length == 2);
        expect(ownerStorage.history.values.map((record) => record.bondNumber), unorderedEquals(['001234', '001235']));
        expect(cleared, [alice.id]);
        expect(receipts, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('Profile keeps saved Marketplace Alerts disabled when another preference changes', (tester) async {
    mockNotifications(tester);
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Finder switchFor(String title) => find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate((widget) => widget is Row && widget.children.any((child) => child is Switch)),
      ),
      matching: find.byType(Switch),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        PrizeBondApp(
          initializeHive: () async {
            Hive.init(storage.path);
            if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
            await AuthService.openAccounts();
            final member = (await _createMember()).account;
            final users = Hive.box<UserProfile>('users');
            await users.put(member.id, users.get(member.id)!.copyWith(isApproved: true));
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notif_${member.id}_marketplace', true);
          },
        ),
      );
      await _pumpUntil(tester, () => find.byType(PinScreen).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      for (final digit in ['0', '1', '2', '3']) {
        await tester.tap(find.text(digit));
      }
      await _pumpUntil(tester, () => find.byType(MainNavigationScreen).evaluate().isNotEmpty);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      final marketplace = switchFor('Marketplace Alerts');
      final win = switchFor('Win Alerts');
      await _pumpUntil(tester, () => marketplace.evaluate().isNotEmpty && tester.widget<Switch>(marketplace).value);
      await tester.ensureVisible(marketplace);
      expect(tester.widget<Switch>(marketplace).onChanged, isNull);
      expect(find.text('Unavailable in the offline demo'), findsOneWidget);
      expect(tester.widget<Switch>(win).value, isTrue);

      await tester.ensureVisible(win);
      await tester.tap(win);
      await _pumpUntil(tester, () => !tester.widget<Switch>(win).value && tester.widget<Switch>(win).onChanged != null);
      final prefs = await AuthService.getAllNotifPrefs(AuthService.requireStorage());
      expect(prefs['win'], isFalse);
      expect(prefs['marketplace'], isTrue);
      expect(tester.widget<Switch>(marketplace).value, isTrue);
      expect(tester.widget<Switch>(marketplace).onChanged, isNull);
    });
  }, variant: _ios);

  testWidgets('Backgrounding locks private screens and suspends the owning account’s reminders', (tester) async {
    final pending = <int, Map<String, dynamic>>{};
    mockNotifications(tester, pending: pending);
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        PrizeBondApp(
          initializeHive: () async {
            Hive.init(storage.path);
            if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
            await AuthService.openAccounts();
            final users = Hive.box<UserProfile>('users');
            final registered = await _createMember();
            final profile = users.get(registered.account.id)!;
            await users.put(profile.key, profile.copyWith(isApproved: true));
          },
        ),
      );
      await _pumpUntil(tester, () => find.byType(PinScreen).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      for (final digit in ['0', '1', '2', '3']) {
        await tester.tap(find.text(digit));
      }
      await _pumpUntil(tester, () => find.byType(MainNavigationScreen).evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      final previous = AuthService.requireStorage();
      await _pumpUntil(tester, () => previous.notifications.length == 21);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      final helper = find.text('In-app inbox notices are still recorded when alerts are off.');
      await tester.ensureVisible(helper);
      expect(helper, findsOneWidget);

      const ownedId = 268435456;
      const unrelatedId = 268435457;
      final tag = 'fyp-reminder-v1-${sha256.convert(utf8.encode(previous.accountId))}';
      for (final (id, group) in [(ownedId, tag), (unrelatedId, 'other_feature')]) {
        pending[id] = native.NotificationModel(
          content: native.NotificationContent(id: id, channelKey: 'draw_channel', groupKey: group, title: 'Reminder'),
          schedule: native.NotificationCalendar.fromDate(date: DateTime.now().add(const Duration(days: 2))),
        ).toMap();
      }

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const ValueKey('session-privacy-cover')), findsOneWidget);
      expect(find.byType(MainNavigationScreen), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(AuthService.unlockedStorage, isNull);
      expect(previous.notifications.values, isEmpty);
      await _pumpUntil(tester, () => !pending.containsKey(ownedId));
      expect(pending.keys, [unrelatedId]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(PinScreen), findsOneWidget);
      expect(find.byType(MainNavigationScreen), findsNothing);
      expect(AuthService.unlockedStorage, isNull);

      for (final digit in ['0', '1', '2', '3']) {
        await tester.tap(find.text(digit));
      }
      await _pumpUntil(tester, () => find.byType(MainNavigationScreen).evaluate().isNotEmpty);
      expect(AuthService.unlockedStorage, isNot(same(previous)));

      // The native notification may reach Dart before the Flutter background event.
      await _nativeBackgroundRequest(tester, 1);
      expect(AuthService.unlockedStorage, isNull);
      await tester.pump();
      expect(find.byType(IosPrivacyFrame), findsOneWidget);
      expect(find.byType(PinScreen), findsNothing);
      await _nativeCoverReleased(tester, 1);
      await tester.pump();
      expect(find.byType(PinScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  testWidgets(
    'Backgrounding Admin Panel revokes authority and requires the passphrase again',
    (tester) async {
      mockNotifications(tester);
      await tester.runAsync(() async {
        await tester.pumpWidget(PrizeBondApp(initializeHive: () async => Hive.init(storage.path)));
        await _pumpUntil(tester, () => find.byType(LandingScreen).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        final user = (await _createMember()).account;

        Future<AdminAccess> openAdmin() async {
          await tester.tap(find.text('Admin'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), _fixturePassphrase);
          await tester.tap(find.text('Continue'));
          await _pumpUntil(tester, () => find.byType(AdminScreen).evaluate().isNotEmpty);
          await tester.pumpAndSettle();
          return tester.widget<AdminScreen>(find.byType(AdminScreen)).access;
        }

        final first = await openAdmin();
        expect(first.accounts.single.id, user.id);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        expect(find.byKey(const ValueKey('session-privacy-cover')), findsOneWidget);
        expect(find.byType(AdminScreen), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(first.isOpen, isFalse);
        expect(first.accounts, isEmpty);
        await expectLater(first.approve(user.id), throwsA(isA<AccountException>()));
        await expectLater(first.resetPin(user.id, '8765'), throwsA(isA<AccountException>()));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(find.byType(LandingScreen), findsOneWidget);
        expect(find.byType(AdminScreen), findsNothing);
        final second = await openAdmin();
        expect(second.isOpen, isTrue);
        await _nativeBackgroundRequest(tester, 1);
        expect(second.isOpen, isFalse);
        await tester.pump();
        expect(find.byType(IosPrivacyFrame), findsOneWidget);
        expect(find.byType(LandingScreen), findsNothing);
        await _nativeCoverReleased(tester, 1);
        await tester.pump();
        expect(find.byType(LandingScreen), findsOneWidget);
        expect(find.byType(AdminScreen), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    },
    skip: !_configuredAdmin,
    variant: _ios,
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for startup');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<RegistrationResult> _createMember({String email = 'member@example.org'}) => AuthService.registerUser(
  firstName: 'Fixture',
  lastName: 'Member',
  mobile: '1234',
  email: email,
  pin: '0123',
  address: 'Test address',
  city: 'Lahore',
);

Future<void> _nativeBackgroundRequest(WidgetTester tester, int generation) => _nativePrivacyEvent(
  tester,
  MethodCall('awaitSafeFrame', {'generation': generation, 'requiresLock': true, 'proof': '8123456789abcdef'}),
);

Future<void> _nativeCoverReleased(WidgetTester tester, int generation) =>
    _nativePrivacyEvent(tester, MethodCall('coverReleased', generation));

Future<void> _nativePrivacyEvent(WidgetTester tester, MethodCall call) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _privacyChannelName,
    const StandardMethodCodec().encodeMethodCall(call),
    null,
  );
}
