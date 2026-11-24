import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Test the plugin boundary without a device.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/notification_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/services/account_credentials.dart';
import 'package:prize_bond_checking_app/services/auth_attempts.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Inject a failure in the host preference store after account creation.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:uuid/uuid.dart';

const _androidKeys = MethodChannel('prize_bond/pin_keystore');
const _v1KeyName = 'prize_bond_pin_verifier_key_v1';
const _selectionKey = 'flutter.selected_account_id_v2';
const _fixtureAdminPassphrase = 'fixture-only-module-2-admin';
const _configuredVerifier = String.fromEnvironment('FYP_ADMIN_VERIFIER');
final _fixtureVerifier = sha256.convert(utf8.encode(_fixtureAdminPassphrase)).toString();

void main() {
  late Directory temp;
  late Box<UserProfile> users;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('prize-bond-accounts-');
    Hive.init(temp.path);
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BondAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CheckRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationModelAdapter());
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    AuthService.resumeFromBackground();
    await AuthService.restoreSelection();
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    SharedPreferences.setMockInitialValues({});
    await AuthService.logout();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('Concurrent normalized duplicate registrations leave the first account intact', () async {
    final first = _register('Owner@Example.org', pin: '0123');
    final duplicate = _register(' owner@example.ORG ', pin: '9999');
    final duplicateCheck = expectLater(duplicate, throwsA(isA<AccountException>()));
    final owner = await first;
    await duplicateCheck;

    expect(Uuid.isValidUUID(fromString: owner.id), isTrue);
    expect(users.length, 1);
    expect(users.get(owner.id)?.email, 'Owner@Example.org');
    expect(users.get(owner.id)?.isApproved, isFalse);
    expect(users.get(owner.id)?.pinHash, startsWith('hmac-v2:'));
    expect(AuthService.unlockedStorage, isNull);
    await expectLater(AuthService.unlock(owner.id, '0123'), throwsA(isA<AccountException>()));
  });

  test('Legacy bond rows reopen with blank metadata and account-scoped updates preserve new metadata', () async {
    final alice = await _register('metadata-alice@example.org');
    final bob = await _register('metadata-bob@example.org');
    await _approveFixture(users, alice);
    await _approveFixture(users, bob);

    await AuthService.selectAccount(alice.email);
    final original = (await AuthService.unlock(alice.id, '0123'))!;
    Hive.registerAdapter(_LegacyBondAdapter(), override: true);
    try {
      await original.bonds.add(_bond());
    } finally {
      Hive.registerAdapter(BondAdapter(), override: true);
    }
    await AuthService.logout();
    await Hive.box<Bond>('bonds_${alice.id}').close();

    await AuthService.selectAccount(alice.email);
    final reopened = (await AuthService.unlock(alice.id, '0123'))!;
    final bond = reopened.bonds.values.single;
    expect(bond.number, '001234');
    expect(bond.issueDate, isNull);
    expect(bond.issueCity, isNull);
    final issueDate = DateTime(2024, 7, 3);
    await reopened.bonds.update(
      bond
        ..issueDate = issueDate
        ..issueCity = 'Lahore',
    );
    final edited = reopened.bonds.values.single;
    expect(edited.issueDate, issueDate);
    expect(edited.issueCity, 'Lahore');
    await reopened.bonds.update(edited..issueCity = 'Karachi');

    await AuthService.selectAccount(bob.email);
    final other = (await AuthService.unlock(bob.id, '0123'))!;
    expect(other.bonds.isEmpty, isTrue);
    await expectLater(reopened.bonds.update(edited), throwsA(isA<AccountException>()));
    await Hive.box<Bond>('bonds_${alice.id}').close();

    await AuthService.selectAccount(alice.email);
    final restored = (await AuthService.unlock(alice.id, '0123'))!.bonds.values.single;
    expect(restored.issueDate, issueDate);
    expect(restored.issueCity, 'Karachi');
    expect(restored.number, '001234');
  });

  test('Two accounts keep bonds, check history, inbox, and preferences private', () async {
    final alice = await _register('alice@example.org', pin: '0123');
    final bob = await _register('bob@example.org', pin: '6543');
    await _approveFixture(users, alice);
    await _approveFixture(users, bob);

    await AuthService.selectAccount(alice.email);
    expect(AuthService.unlockedStorage, isNull);
    final aliceStorage = (await AuthService.unlock(alice.id, '0123'))!;
    await aliceStorage.bonds.add(_bond());
    await aliceStorage.history.add(_record());
    await NotificationService().showWinNotification(aliceStorage, bondNumber: '001234', denomination: 'Rs. 1500', city: 'Lahore');
    await AuthService.setNotifPref(aliceStorage, 'all', false);

    await expectLater(
      AuthService.saveUserProfile(
        storage: aliceStorage,
        email: ' BOB@EXAMPLE.ORG ',
        name: 'Alice Updated',
        city: 'Quetta',
        phone: '123',
      ),
      throwsA(isA<AccountException>()),
    );
    expect(AuthService.profile(aliceStorage).email, alice.email);
    await AuthService.saveUserProfile(
      storage: aliceStorage,
      email: 'new-alice@example.org',
      name: 'Alice Updated',
      city: 'Quetta',
      phone: '123',
    );
    expect(AuthService.profile(aliceStorage).id, alice.id);
    expect(AuthService.profile(aliceStorage).address, 'Original address');
    expect(aliceStorage.bonds.values.single.number, '001234');

    await AuthService.logout();
    expect(() => AuthService.requireStorage(), throwsA(isA<AccountException>()));
    await AuthService.selectAccount(bob.email);
    final bobStorage = (await AuthService.unlock(bob.id, '6543'))!;
    expect(bobStorage.bonds.isEmpty, isTrue);
    expect(bobStorage.history.isEmpty, isTrue);
    expect(NotificationService().notifications(bobStorage), isEmpty);
    expect(NotificationService().notifications(aliceStorage), isEmpty);
    expect((await AuthService.getAllNotifPrefs(bobStorage))['all'], isTrue);
    await bobStorage.history.add(_record());
    await bobStorage.history.clear();
    await NotificationService().clearAll(bobStorage);
    await NotificationService().clearAll(aliceStorage);
    await expectLater(
      AuthService.saveUserProfile(storage: aliceStorage, email: alice.email, name: 'Alice', city: '', phone: ''),
      throwsA(isA<AccountException>()),
    );

    await AuthService.logout();
    await AuthService.selectAccount('NEW-ALICE@EXAMPLE.ORG');
    final restored = (await AuthService.unlock(alice.id, '0123'))!;
    expect(restored.bonds.values.single.number, '001234');
    expect(restored.history.values.single.bondNumber, '001234');
    expect(NotificationService().notifications(restored).single.type, NotificationType.win);
    expect((await AuthService.getAllNotifPrefs(restored))['all'], isFalse);
  });

  test('Legacy account and PIN migrate without assigning or modifying ownerless records', () async {
    await users.close();
    Hive.registerAdapter(_LegacyUserProfileAdapter(), override: true);
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    const email = 'legacy@example.org';
    final legacyHash = sha256.convert(utf8.encode('0234')).toString();
    await users.put(
      email,
      UserProfile()
        ..id = email
        ..firstName = 'Legacy'
        ..lastName = 'User'
        ..email = email
        ..mobile = '123'
        ..address = 'Legacy address'
        ..city = 'Karachi'
        ..pinHash = legacyHash
        ..role = 'Normal User'
        ..isApproved = true
        ..registeredAt = DateTime(2025),
    );
    await users.close();
    Hive.registerAdapter(UserProfileAdapter(), override: true);
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    final legacyBonds = await Hive.openBox<Bond>('bonds');
    final legacyHistory = await Hive.openBox<CheckRecord>('check_history');
    final legacyInbox = await Hive.openBox<NotificationModel>('notifications');
    await legacyBonds.add(_bond());
    await legacyHistory.add(_record());
    await legacyInbox.add(
      NotificationModel()
        ..id = 'legacy'
        ..typeIndex = 0
        ..title = 'Legacy'
        ..body = 'Preserve without ownership'
        ..timestamp = DateTime(2025)
        ..isRead = false,
    );
    SharedPreferences.setMockInitialValues({
      'is_logged_in': true,
      'current_user_email': email,
      'user_email': email,
      'user_pin': legacyHash,
    });

    await AuthService.restoreSelection();
    final id = AuthService.selectedAccount!.id;
    expect(Uuid.isValidUUID(fromString: id), isTrue);
    expect(users.get(email)?.isApproved, isTrue);
    expect(users.get(email)?.isRejected, isFalse);
    expect(AuthService.unlockedStorage, isNull);
    await AuthService.restoreSelection();
    expect(AuthService.selectedAccount?.id, id);

    final scoped = (await AuthService.unlock(id, '0234'))!;
    expect(users.get(email)?.pinHash, startsWith('hmac-v2:'));
    expect((await SharedPreferences.getInstance()).getString('user_pin'), isNull);
    expect(scoped.bonds.isEmpty && scoped.history.isEmpty && scoped.notifications.isEmpty, isTrue);
    expect(legacyBonds.values.single.number, '001234');
    expect(legacyHistory.values.single.bondNumber, '001234');
    expect(legacyInbox.values.single.id, 'legacy');

    await AuthService.logout();
    await AuthService.restoreSelection();
    expect(AuthService.selectedAccount, isNull);
  });

  test('PIN attempt limit persists across restart and is scoped to the attempted account', () async {
    final alice = await _register('alice@example.org');
    await _approveFixture(users, alice);
    for (var index = 0; index < 4; index++) {
      expect(await AuthService.unlock(alice.id, '0000'), isNull);
    }
    await expectLater(AuthService.unlock(alice.id, '0000'), throwsA(isA<AccountException>()));
    await AuthService.restoreSelection();
    await expectLater(AuthService.unlock(alice.id, '0123'), throwsA(isA<AccountException>()));

    final bob = await _register('bob@example.org');
    await _approveFixture(users, bob);
    expect((await AuthService.unlock(bob.id, '0123'))?.accountId, bob.id);
  });

  test(
    'Admin approval, reversible decline, and PIN reset require a valid open admin session',
    () async {
      final account = await _register('member@example.org');
      expect(await AuthService.authenticateAdmin('wrong'), isNull);
      final admin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;
      await admin.reject(account.id);
      expect(users.get(account.id)?.isRejected, isTrue);
      expect(users.get(account.id)?.email, account.email);
      await expectLater(AuthService.unlock(account.id, '0123'), throwsA(isA<AccountException>()));

      await admin.approve(account.id);
      final storage = (await AuthService.unlock(account.id, '0123'))!;
      expect(NotificationService().notifications(storage).single.title, 'Account Approved');
      await storage.bonds.add(_bond());
      await admin.resetPin(account.id, '4321');
      expect(AuthService.unlockedStorage, isNull);
      expect(await AuthService.unlock(account.id, '0123'), isNull);
      final recovered = (await AuthService.unlock(account.id, '4321'))!;
      expect(recovered.bonds.values.single.number, '001234');

      admin.close();
      await expectLater(admin.resetPin(account.id, '9999'), throwsA(isA<AccountException>()));
    },
    skip: _configuredVerifier != _fixtureVerifier ? 'Run with the documented fixture verifier to exercise admin access.' : false,
  );

  test('Stale private stores cannot write, and a submitted write finishes for its original account', () async {
    final alice = await _register('alice@example.org');
    final bob = await _register('bob@example.org');
    await _approveFixture(users, alice);
    await _approveFixture(users, bob);
    await AuthService.selectAccount(alice.email);
    final stale = (await AuthService.unlock(alice.id, '0123'))!;
    final first = _bond();
    final pendingWrite = stale.bonds.add(first);
    first.number = '999999';
    await AuthService.logout();
    await pendingWrite;
    await expectLater(stale.bonds.add(_bond()), throwsA(isA<AccountException>()));
    expect(stale.bonds.values, isEmpty);

    await AuthService.selectAccount(alice.email);
    final active = (await AuthService.unlock(alice.id, '0123'))!;
    final detached = active.bonds.values.single;
    expect(detached.number, '001234');
    expect(detached.isInBox, isFalse);
    detached.status = 'Changed in memory';
    expect(active.bonds.values.single.status, 'Active');
    await active.bonds.update(detached);
    expect(active.bonds.values.single.status, 'Changed in memory');

    final switching = AuthService.selectAccount(bob.email);
    await switching;
    final other = (await AuthService.unlock(bob.id, '0123'))!;
    await expectLater(active.bonds.update(detached), throwsA(isA<AccountException>()));
    await expectLater(active.bonds.delete(detached), throwsA(isA<AccountException>()));
    await expectLater(active.history.clear(), throwsA(isA<AccountException>()));
    await expectLater(active.notifications.clear(), throwsA(isA<AccountException>()));
    await expectLater(AuthService.setNotifPref(active, 'all', false), throwsA(isA<AccountException>()));
    expect(other.bonds.values, isEmpty);

    await AuthService.selectAccount(alice.email);
    final reopened = (await AuthService.unlock(alice.id, '0123'))!;
    expect(reopened.bonds.values.single.status, 'Changed in memory');
  });

  test('Registration reports a committed account when selecting it fails and rejects duplicate retries', () async {
    final prefs = _FailingPreferences({_selectionKey: ''});
    SharedPreferencesStorePlatform.instance = prefs;
    await (await SharedPreferences.getInstance()).reload();

    final result = await _registerResult('Created@Example.org', pin: '0123');
    expect(result.selectionSaved, isFalse);
    expect(AuthService.selectedAccount, isNull);
    expect((await prefs.getAll())[_selectionKey], '');
    final created = users.get(result.account.id)!;
    expect(created.isApproved, isFalse);
    expect(created.pinHash, startsWith('hmac-v2:'));
    await expectLater(_register(' CREATED@example.ORG ', pin: '9999'), throwsA(isA<AccountException>()));
    expect(users.length, 1);
    expect(users.get(created.id)?.pinHash, created.pinHash);

    prefs.failWrites = false;
    expect((await AuthService.selectAccount('created@example.org'))?.id, created.id);
  });

  test('PIN attempts persist while preference writes fail', () async {
    final alice = await _register('member@example.org');
    await _approveFixture(users, alice);
    final prefs = _FailingPreferences({_selectionKey: alice.id});
    SharedPreferencesStorePlatform.instance = prefs;
    expect(await (await SharedPreferences.getInstance()).setInt('probe', 0), isFalse);
    for (var index = 0; index < 4; index++) {
      expect(await AuthService.unlock(alice.id, '0000'), isNull);
    }
    await expectLater(AuthService.unlock(alice.id, '0000'), throwsA(isA<AccountException>()));
    await Hive.close();
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    await AuthService.restoreSelection();
    await expectLater(AuthService.unlock(alice.id, '0123'), throwsA(isA<AccountException>()));
  });

  test('Lockout uses monotonic time and re-arms a persisted lock across restart', () async {
    var elapsed = Duration.zero;
    var wall = DateTime(2026, 11, 24);
    final prefs = await SharedPreferences.getInstance();
    var box = await Hive.openBox<String>('attempt_clock_fixture');
    AuthAttempts limiter() => AuthAttempts(box, elapsed: () => elapsed, now: () => wall);

    final beforeRestart = limiter();
    for (var index = 0; index < 5; index++) {
      await beforeRestart.reserve('member', prefs);
    }
    expect(jsonDecode(box.get('member')!), [5, wall.add(const Duration(minutes: 1)).millisecondsSinceEpoch]);
    wall = wall.add(const Duration(days: 2));
    elapsed = const Duration(seconds: 59);
    await expectLater(beforeRestart.reserve('member', prefs), throwsA(isA<AttemptLockout>()));

    await box.close();
    box = await Hive.openBox<String>('attempt_clock_fixture');
    elapsed = Duration.zero;
    final afterRestart = limiter();
    await expectLater(afterRestart.reserve('member', prefs), throwsA(isA<AttemptLockout>()));
    await afterRestart.reserve('other', prefs);
    wall = wall.subtract(const Duration(days: 4));
    elapsed = const Duration(minutes: 1);
    await afterRestart.reserve('member', prefs);
    expect(afterRestart.isLocked('member'), isFalse);
    expect(jsonDecode(box.get('member')!), [1, 0]);
  });

  test('A failed attempt-store write or flush fails closed', () async {
    final prefs = await SharedPreferences.getInstance();
    final box = _FailingAttemptsBox();
    final attempts = AuthAttempts(box);
    await expectLater(attempts.reserve('member', prefs), throwsA(isA<AttemptPersistenceFailure>()));
    expect(box.record, isNull);

    box.allowPut = true;
    await expectLater(attempts.reserve('member', prefs), throwsA(isA<AttemptPersistenceFailure>()));
    expect(box.record, '[1,0]');

    final alice = await _register('member@example.org');
    await _approveFixture(users, alice);
    expect(await AuthService.unlock(alice.id, '0000'), isNull);
    await Hive.box<String>('auth_attempts_v1').close();
    final platform = _SecureStoreProbe((_) async => throw StateError('The PIN must not be evaluated.'));
    FlutterSecureStoragePlatform.instance = platform;
    await expectLater(AuthService.unlock(alice.id, '0123'), throwsA(isA<AccountException>()));
    expect(platform.reads, 0);
    expect(AuthService.unlockedStorage, isNull);
  });

  for (final fixture in <(String, String?, CredentialProblem)>[
    ('missing', null, CredentialProblem.missing),
    ('malformed', 'invalid!', CredentialProblem.corrupted),
    ('short', base64UrlEncode([1, 2, 3]), CredentialProblem.invalidKeyMaterial),
    ('changed', base64UrlEncode(List.filled(32, 1)), CredentialProblem.corrupted),
  ]) {
    test('PIN unlock reports a ${fixture.$1} key separately from a wrong PIN', () async {
      final alice = await _register('alice@example.org');
      await _approveFixture(users, alice);
      expect(await AuthService.unlock(alice.id, '1234'), isNull);
      final keyName = _v2KeyName(users.get(alice.id)!);
      FlutterSecureStorage.setMockInitialValues({if (fixture.$2 != null) keyName: fixture.$2!});
      await expectLater(AuthService.unlock(alice.id, '0123'), throwsA(_credential(fixture.$3)));
      expect(AuthService.unlockedStorage, isNull);
      expect(users.get(alice.id)?.pinHash, startsWith('hmac-v2:'));
    });
  }

  test('Secure storage unavailability is reported and account creation aborts before Hive writes', () async {
    final alice = await _register('alice@example.org');
    await _approveFixture(users, alice);
    final verifier = users.get(alice.id)!.pinHash;
    FlutterSecureStoragePlatform.instance = MethodChannelFlutterSecureStorage();
    await expectLater(AuthService.unlock(alice.id, '0123'), throwsA(_credential(CredentialProblem.unavailable)));
    await expectLater(_register('new@example.org'), throwsA(_credential(CredentialProblem.unavailable)));
    expect(users.length, 1);
    expect(users.get(alice.id)!.pinHash, verifier);
  });

  test('A pending PIN verification cannot publish a session after backgrounding and resuming', () async {
    final alice = await _register('alice@example.org');
    await _approveFixture(users, alice);
    final keys = await const FlutterSecureStorage().readAll();
    final readStarted = Completer<void>();
    final completeRead = Completer<void>();
    FlutterSecureStoragePlatform.instance = _SecureStoreProbe((name) async {
      readStarted.complete();
      await completeRead.future;
      return keys[name];
    });
    final attempted = expectLater(AuthService.unlock(alice.id, '0123'), throwsA(isA<AccountException>()));
    await readStarted.future;
    final queuedAdmin = _configuredVerifier == _fixtureVerifier
        ? expectLater(AuthService.authenticateAdmin(_fixtureAdminPassphrase), throwsA(isA<AccountException>()))
        : Future<void>.value();
    AuthService.lockForBackground();
    AuthService.resumeFromBackground();
    completeRead.complete();
    await attempted;
    await queuedAdmin;
    expect(AuthService.hasAdminAccess, isFalse);
    expect(AuthService.unlockedStorage, isNull);
    FlutterSecureStorage.setMockInitialValues(keys);
    expect(await AuthService.unlock(alice.id, '0123'), isNotNull);
  });

  test('Explicit recovery preserves shared-key accounts, and interrupted recovery leaves the old verifier', () async {
    final alice = await _register('alice@example.org');
    final bob = await _register('bob@example.org');
    final sharedKey = List<int>.generate(32, (index) => index);
    final aliceV1 = _v1Verifier(alice.id, sharedKey);
    final bobV1 = _v1Verifier(bob.id, sharedKey);
    for (final (account, verifier) in [(alice, aliceV1), (bob, bobV1)]) {
      await users.put(account.id, users.get(account.id)!.copyWith(pinHash: verifier, isApproved: true));
    }
    final originalKey = base64UrlEncode(sharedKey);
    FlutterSecureStorage.setMockInitialValues({_v1KeyName: originalKey});
    await AuthService.selectAccount(alice.email);
    final storage = (await AuthService.unlock(alice.id, '0123'))!;
    await storage.bonds.add(_bond());
    await storage.history.add(_record());
    await NotificationService().showWinNotification(storage, bondNumber: '001234', denomination: 'Rs. 1500', city: 'Lahore');
    await AuthService.logout();
    await AuthService.selectAccount(alice.email);
    final admin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;

    FlutterSecureStoragePlatform.instance = MethodChannelFlutterSecureStorage();
    await expectLater(admin.resetPin(alice.id, '8765', recover: true), throwsA(_credential(CredentialProblem.unavailable)));
    expect(users.get(alice.id)!.pinHash, aliceV1);

    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(admin.resetPin(alice.id, '8765'), throwsA(_credential(CredentialProblem.missing)));
    expect(await const FlutterSecureStorage().readAll(), isEmpty);

    final writeStarted = Completer<void>();
    final resumeWrite = Completer<void>();
    final staged = <String, String>{_v1KeyName: 'invalid!'};
    FlutterSecureStoragePlatform.instance = _SecureStoreProbe(
      (name) async => staged[name],
      onWrite: (name, value) async {
        writeStarted.complete();
        await resumeWrite.future;
        staged[name] = value;
      },
    );
    final pending = expectLater(admin.resetPin(alice.id, '8765', recover: true), throwsA(isA<AccountException>()));
    await writeStarted.future;
    AuthService.lockForBackground();
    AuthService.resumeFromBackground();
    resumeWrite.complete();
    await pending;
    expect(admin.isOpen, isFalse);
    expect(admin.accounts, isEmpty);
    expect(users.get(alice.id)!.pinHash, aliceV1);
    expect(users.get(bob.id)!.pinHash, bobV1);

    FlutterSecureStorage.setMockInitialValues(staged);
    final reauthenticated = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;
    await reauthenticated.resetPin(alice.id, '8765', recover: true);
    expect(users.get(alice.id)!.pinHash, startsWith('hmac-v2:'));
    expect(users.get(bob.id)!.pinHash, bobV1);
    final recovered = (await AuthService.unlock(alice.id, '8765'))!;
    expect(recovered.bonds.values.single.number, '001234');
    expect(recovered.history.values.single.bondNumber, '001234');
    expect(recovered.notifications.values.single.isRead, isFalse);
    expect((await const FlutterSecureStorage().readAll())[_v1KeyName], 'invalid!');

    await const FlutterSecureStorage().write(key: _v1KeyName, value: originalKey);
    await AuthService.selectAccount(bob.email);
    expect(await AuthService.unlock(bob.id, '0123'), isNotNull);
  }, skip: _skipAdmin);

  test('A missing account key can be recovered without changing a healthy account’s key', () async {
    final alice = await _register('alice@example.org');
    final bob = await _register('bob@example.org');
    await _approveFixture(users, alice);
    await _approveFixture(users, bob);
    final before = await const FlutterSecureStorage().readAll();
    final aliceKey = _v2KeyName(users.get(alice.id)!);
    final bobKey = _v2KeyName(users.get(bob.id)!);
    FlutterSecureStorage.setMockInitialValues({bobKey: before[bobKey]!});

    final admin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;
    final original = users.get(alice.id)!.pinHash;
    FlutterSecureStoragePlatform.instance = _SecureStoreProbe(
      (name) async => name == bobKey ? before[name] : null,
      onWrite: (_, _) async => throw PlatformException(code: 'storage-write-failed'),
    );
    await expectLater(admin.resetPin(alice.id, '8765', recover: true), throwsA(_credential(CredentialProblem.unavailable)));
    expect(users.get(alice.id)!.pinHash, original);

    FlutterSecureStorage.setMockInitialValues({bobKey: before[bobKey]!});
    await admin.resetPin(alice.id, '8765', recover: true);
    final after = await const FlutterSecureStorage().readAll();
    expect(after[bobKey], before[bobKey]);
    expect(after.containsKey(aliceKey), isFalse);
    expect(after, hasLength(2));

    await AuthService.selectAccount(alice.email);
    expect(await AuthService.unlock(alice.id, '8765'), isNotNull);
    await AuthService.selectAccount(bob.email);
    expect(await AuthService.unlock(bob.id, '0123'), isNotNull);
  }, skip: _skipAdmin);

  _AndroidKeyStoreProbe useAndroidKeyStore() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final probe = _AndroidKeyStoreProbe();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_androidKeys, probe.handle);
    addTearDown(() => messenger.setMockMethodCallHandler(_androidKeys, null));
    return probe;
  }

  test('Android registration waits for a durable key and a failed key write leaves no account', () async {
    final keys = useAndroidKeyStore();
    keys.failCreate = true;
    await expectLater(_register('android@example.org'), throwsA(_credential(CredentialProblem.unavailable)));
    expect(users.isEmpty, isTrue);
    expect(AuthService.selectedAccount, isNull);

    keys.failCreate = false;
    final persisted = Completer<void>();
    final acknowledge = Completer<void>();
    keys.beforeAcknowledgment = () async {
      persisted.complete();
      await acknowledge.future;
    };
    final registration = _register('android@example.org');
    await persisted.future;
    expect(users.isEmpty, isTrue);
    acknowledge.complete();
    final user = await registration;
    expect(users.get(user.id)!.pinHash, startsWith('hmac-android-v3:'));
    await _approveFixture(users, user);
    expect(await AuthService.unlock(user.id, '0000'), isNull);
    expect(await AuthService.unlock(user.id, '0123'), isNotNull);
  });

  test('Android legacy PIN migration leaves the old verifier on key persistence failure', () async {
    final user = await _register('legacy-android@example.org');
    final old = sha256.convert(utf8.encode('0123')).toString();
    await users.put(user.id, users.get(user.id)!.copyWith(pinHash: old, isApproved: true));
    final keys = useAndroidKeyStore();
    keys.failCreate = true;
    await expectLater(AuthService.unlock(user.id, '0123'), throwsA(_credential(CredentialProblem.unavailable)));
    expect(users.get(user.id)!.pinHash, old);
    expect(AuthService.unlockedStorage, isNull);

    keys.failCreate = false;
    expect(await AuthService.unlock(user.id, '0123'), isNotNull);
    expect(users.get(user.id)!.pinHash, startsWith('hmac-android-v3:'));
  });

  test('Android reset preserves the prior PIN after failure and after backgrounding with a staged key', () async {
    final user = await _register('android-reset@example.org');
    await _approveFixture(users, user);
    final previous = users.get(user.id)!.pinHash;
    final keys = useAndroidKeyStore();
    final storage = (await AuthService.unlock(user.id, '0123'))!;
    await storage.bonds.add(_bond());
    final admin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;

    keys.failCreate = true;
    await expectLater(admin.resetPin(user.id, '8765'), throwsA(_credential(CredentialProblem.unavailable)));
    expect(users.get(user.id)!.pinHash, previous);
    expect(keys.persisted, isEmpty);

    keys.failCreate = false;
    final persisted = Completer<void>();
    final acknowledge = Completer<void>();
    keys.beforeAcknowledgment = () async {
      persisted.complete();
      await acknowledge.future;
    };
    final pending = expectLater(admin.resetPin(user.id, '8765'), throwsA(isA<AccountException>()));
    await persisted.future;
    expect(keys.persisted, hasLength(1));
    expect(users.get(user.id)!.pinHash, previous);
    AuthService.lockForBackground();
    AuthService.resumeFromBackground();
    acknowledge.complete();
    await pending;

    await users.close();
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    expect(users.get(user.id)!.pinHash, previous);
    expect(admin.isOpen, isFalse);
    final restored = (await AuthService.unlock(user.id, '0123'))!;
    expect(restored.bonds.values.single.number, '001234');

    keys.beforeAcknowledgment = null;
    final nextAdmin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;
    await nextAdmin.resetPin(user.id, '8765');
    expect(users.get(user.id)!.pinHash, startsWith('hmac-android-v3:'));
    expect(await AuthService.unlock(user.id, '0123'), isNull);
    final updated = (await AuthService.unlock(user.id, '8765'))!;
    expect(updated.bonds.values.single.number, '001234');

    final current = users.get(user.id)!.pinHash;
    keys.failCreate = true;
    await expectLater(nextAdmin.resetPin(user.id, '9876'), throwsA(_credential(CredentialProblem.unavailable)));
    expect(users.get(user.id)!.pinHash, current);
    expect(await AuthService.unlock(user.id, '8765'), isNotNull);
  }, skip: _skipAdmin);

  test('Android key loss requires explicit recovery and leaves a second key usable', () async {
    final keys = useAndroidKeyStore();
    final lost = await _register('lost-android@example.org');
    final healthy = await _register('healthy-android@example.org');
    await _approveFixture(users, lost);
    await _approveFixture(users, healthy);
    final oldLost = users.get(lost.id)!.pinHash;
    final oldHealthy = users.get(healthy.id)!.pinHash;
    keys.persisted.remove((lost.id, oldLost.split(':')[1]));
    final admin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;
    await expectLater(admin.resetPin(lost.id, '8765'), throwsA(_credential(CredentialProblem.missing)));
    expect(keys.persisted, hasLength(1));
    await admin.resetPin(lost.id, '8765', recover: true);
    expect(keys.persisted, hasLength(2));
    expect(users.get(healthy.id)!.pinHash, oldHealthy);
    await AuthService.selectAccount(lost.email);
    expect(await AuthService.unlock(lost.id, '8765'), isNotNull);
    await AuthService.selectAccount(healthy.email);
    expect(await AuthService.unlock(healthy.id, '0123'), isNotNull);
  }, skip: _skipAdmin);

  test('Hive credential write failure preserves the saved PIN after reopening', () async {
    final keys = useAndroidKeyStore();
    final user = await _register('commit-failure@example.org');
    await _approveFixture(users, user);
    final oldVerifier = users.get(user.id)!.pinHash;
    final admin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;

    Hive.registerAdapter(_FailingProfileWriteAdapter(), override: true);
    try {
      await expectLater(admin.resetPin(user.id, '8765'), throwsA(isA<FileSystemException>()));
      expect(keys.persisted, hasLength(2));
      expect(users.get(user.id)!.pinHash, oldVerifier);
    } finally {
      Hive.registerAdapter(UserProfileAdapter(), override: true);
    }

    await users.close();
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    expect(users.get(user.id)!.pinHash, oldVerifier);
    expect(await AuthService.unlock(user.id, '8765'), isNull);
    expect(await AuthService.unlock(user.id, '0123'), isNotNull);
  }, skip: _skipAdmin);

  test('Compaction failure after a successful reset preserves the new PIN after reopening', () async {
    final keys = useAndroidKeyStore();
    final user = await _register('compaction-failure@example.org');
    await _approveFixture(users, user);
    final oldVerifier = users.get(user.id)!.pinHash;
    // At this threshold Hive's usual strategy would compact on the next replacement.
    for (var i = 0; i < 59; i++) {
      await users.put(user.id, users.get(user.id)!.copyWith(mobile: 'fixture-$i'));
    }

    final blockedCompaction = await Directory('${temp.path}/users.hivec').create();
    final admin = (await AuthService.authenticateAdmin(_fixtureAdminPassphrase))!;
    await admin.resetPin(user.id, '8765');
    final newVerifier = users.get(user.id)!.pinHash;
    expect(newVerifier, isNot(oldVerifier));
    expect(keys.persisted, hasLength(2));

    // Keep the maintenance error visible to its caller, separately from the committed reset.
    await expectLater(users.compact(), throwsA(isA<FileSystemException>()));
    await blockedCompaction.delete();
    await users.close();
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');

    expect(users.get(user.id)!.pinHash, newVerifier);
    expect(await AuthService.unlock(user.id, '0123'), isNull);
    expect(await AuthService.unlock(user.id, '8765'), isNotNull);
  }, skip: _skipAdmin);

  test('Hive credential write failure leaves registration retryable', () async {
    useAndroidKeyStore();
    Hive.registerAdapter(_FailingProfileWriteAdapter(), override: true);
    try {
      await expectLater(_register('commit-registration@example.org'), throwsA(isA<FileSystemException>()));
      expect(users.isEmpty, isTrue);
      expect(AuthService.selectedAccount, isNull);
    } finally {
      Hive.registerAdapter(UserProfileAdapter(), override: true);
    }
    await users.close();
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    expect(users.isEmpty, isTrue);
    final user = await _register('commit-registration@example.org');
    expect(users.get(user.id), isNotNull);
  });

  test('Hive credential write failure preserves a legacy PIN for the next migration', () async {
    final user = await _register('commit-legacy@example.org');
    final oldVerifier = sha256.convert(utf8.encode('0123')).toString();
    await users.put(user.id, users.get(user.id)!.copyWith(pinHash: oldVerifier, isApproved: true));
    useAndroidKeyStore();

    Hive.registerAdapter(_FailingProfileWriteAdapter(), override: true);
    try {
      await expectLater(AuthService.unlock(user.id, '0123'), throwsA(isA<FileSystemException>()));
      expect(users.get(user.id)!.pinHash, oldVerifier);
      expect(AuthService.unlockedStorage, isNull);
    } finally {
      Hive.registerAdapter(UserProfileAdapter(), override: true);
    }
    await users.close();
    await AuthService.openAccounts();
    users = Hive.box<UserProfile>('users');
    expect(users.get(user.id)!.pinHash, oldVerifier);
    expect(await AuthService.unlock(user.id, '0123'), isNotNull);
    expect(users.get(user.id)!.pinHash, startsWith('hmac-android-v3:'));
  });

  test('Admin lockout is durable and separate from account PIN throttling', () async {
    final alice = await _register('alice@example.org');
    await _approveFixture(users, alice);
    for (var index = 0; index < 4; index++) {
      expect(await AuthService.authenticateAdmin('wrong'), isNull);
    }
    await expectLater(AuthService.authenticateAdmin('wrong'), throwsA(isA<AccountException>()));
    await AuthService.restoreSelection();
    await expectLater(AuthService.authenticateAdmin(_fixtureAdminPassphrase), throwsA(isA<AccountException>()));
    expect(await AuthService.unlock(alice.id, '0123'), isNotNull);
  }, skip: _skipAdmin);

  test(
    'A build without administrator provisioning fails closed',
    () async {
      await expectLater(AuthService.authenticateAdmin('any passphrase'), throwsA(isA<AccountException>()));
    },
    skip: _configuredVerifier.isNotEmpty ? 'This run uses an explicit administrator verifier.' : false,
  );
}

Future<AccountSummary> _register(String email, {String pin = '0123'}) async => (await _registerResult(email, pin: pin)).account;

Future<RegistrationResult> _registerResult(String email, {required String pin}) => AuthService.registerUser(
  firstName: 'Local',
  lastName: 'Member',
  mobile: '123',
  email: email,
  pin: pin,
  address: 'Original address',
  city: 'Lahore',
);

Future<void> _approveFixture(Box<UserProfile> users, AccountSummary user) =>
    users.put(user.id, users.get(user.id)!.copyWith(isApproved: true));

Bond _bond() => Bond()
  ..id = 'sample-bond'
  ..number = '001234'
  ..denomination = 'Rs. 1500'
  ..status = 'Active'
  ..addedDate = DateTime(2025);

CheckRecord _record() => CheckRecord()
  ..bondNumber = '001234'
  ..denomination = 'Rs. 1500'
  ..checkedAt = DateTime(2025)
  ..resultStatus = 'Won'
  ..drawNumber = '1'
  ..drawDate = 'January 1, 2025';

class _LegacyBondAdapter extends BondAdapter {
  @override
  void write(BinaryWriter writer, Bond bond) {
    final fields = [bond.id, bond.number, bond.denomination, bond.status, bond.addedDate, bond.lastChecked, bond.lastResult];
    writer.writeByte(fields.length);
    for (var index = 0; index < fields.length; index++) {
      writer.writeByte(index);
      writer.write(fields[index]);
    }
  }
}

class _LegacyUserProfileAdapter extends UserProfileAdapter {
  @override
  void write(BinaryWriter writer, UserProfile user) {
    final fields = [
      user.id,
      user.firstName,
      user.lastName,
      user.mobile,
      user.email,
      user.pinHash,
      user.address,
      user.city,
      user.role,
      user.isApproved,
      user.registeredAt,
    ];
    writer.writeByte(fields.length);
    for (var index = 0; index < fields.length; index++) {
      writer.writeByte(index);
      writer.write(fields[index]);
    }
  }
}

Object get _skipAdmin =>
    _configuredVerifier != _fixtureVerifier ? 'Run with the documented fixture verifier to exercise admin access.' : false;

Matcher _credential(CredentialProblem problem) => isA<CredentialException>().having((error) => error.problem, 'problem', problem);

String _v2KeyName(UserProfile account) => 'prize_bond_pin_verifier_key_v2_${account.id}_${account.pinHash.split(':')[1]}';

String _v1Verifier(String id, List<int> key) {
  final salt = const Uuid().v4();
  final digest = Hmac(sha256, key).convert(utf8.encode('$id:$salt:0123'));
  return 'hmac-v1:$salt:$digest';
}

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences(super.data) : super.withData();

  bool failWrites = true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failWrites) return false;
    return super.setValue(valueType, key, value);
  }
}

class _FailingAttemptsBox implements Box<String> {
  bool allowPut = false;
  String? record;

  @override
  bool containsKey(dynamic key) => record != null;

  @override
  String? get(dynamic key, {String? defaultValue}) => record ?? defaultValue;

  @override
  Future<void> put(dynamic key, String value) async {
    if (!allowPut) throw const FileSystemException('Test disk write failed');
    record = value;
  }

  @override
  Future<void> flush() async => throw const FileSystemException('Test disk flush failed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SecureStoreProbe extends MethodChannelFlutterSecureStorage {
  _SecureStoreProbe(this.onRead, {this.onWrite});

  final Future<String?> Function(String name) onRead;
  final Future<void> Function(String name, String value)? onWrite;
  int reads = 0;

  @override
  Future<String?> read({required String key, required Map<String, String> options}) {
    reads++;
    return onRead(key);
  }

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {
    await onWrite?.call(key, value);
  }
}

class _AndroidKeyStoreProbe {
  final persisted = <(String, String), List<int>>{};
  bool failCreate = false;
  Future<void> Function()? beforeAcknowledgment;

  Future<Map<String, String>?> handle(MethodCall call) async {
    final arguments = call.arguments as Map;
    final id = arguments['accountId'] as String;
    final generation = arguments['generation'] as String;
    final pin = arguments['pin'] as String?;
    final alias = (id, generation);
    if (call.method == 'create') {
      if (failCreate) throw PlatformException(code: 'pin-keystore-unavailable');
      if (persisted.containsKey(alias)) throw StateError('An existing test key would be overwritten.');
      persisted[alias] = Hive.generateSecureKey();
      await beforeAcknowledgment?.call();
    }
    final key = persisted[alias];
    if (key == null) return null;
    String mac(String value) => Hmac(sha256, key).convert(utf8.encode(value)).toString();
    return {'check': mac('fyp-pin-key:$id:$generation'), if (pin != null) 'pinDigest': mac('$id:$generation:$pin')};
  }
}

class _FailingProfileWriteAdapter extends UserProfileAdapter {
  @override
  void write(BinaryWriter writer, UserProfile obj) {
    throw const FileSystemException('Injected error while writing a Hive profile frame');
  }
}
