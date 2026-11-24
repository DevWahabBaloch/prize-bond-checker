import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/models/notification_model.dart';
import 'package:prize_bond_checking_app/models/prize_entry_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/screens/bulk_check_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _picker = MethodChannel('miguelruivo.flutter.plugins.filepicker');
const _androidPicker = MethodChannel('prize_bond/android_bulk_import');
const _denomination = 'Rs. 1500';
final _ios = TargetPlatformVariant({TargetPlatform.iOS});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bulk-check-');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    Hive.init(temp.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(DrawResultAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BondAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CheckRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationModelAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(PrizeEntryAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
    await Hive.openBox<DrawResult>('draws');
    await DrawService().importBundledSeed();
    await AuthService.openAccounts();
    AuthService.resumeFromBackground();
    await AuthService.restoreSelection();
  });

  tearDown(() async {
    await AuthService.logout();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets('CSV and paste preserve leading zeros, deduplicate, and skip malformed entries', (tester) async {
    List<Map<String, Object>>? selection;
    _mockPicker(tester, () => selection);
    await tester.runAsync(() async {
      final file = File('${temp.path}/bonds.csv');
      await file.writeAsString('\uFEFF"001234"\r\n498382\n12AB56\r"bogus,000002,cell"');
      selection = [_picked(file, await file.length())];
      final account = await _openBulk(tester);
      await tester.tap(find.text('Pick TXT or CSV File'));
      await _waitForText(tester, 'bonds.csv');

      selection = null;
      await tester.tap(find.text('bonds.csv'));
      await tester.pumpAndSettle();
      expect(find.text('bonds.csv'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '001234, 001235');
      await _check(tester);
      await _waitForText(tester, '1 wins • 2 no win • 0 unavailable • 2 skipped', containing: true);
      expect(account.history.values.map((record) => record.bondNumber), unorderedEquals(['001234', '498382', '001235']));
      expect(account.notifications.length, 1);
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  testWidgets('Unreadable and oversized selections leave the previous TXT selection usable', (tester) async {
    List<Map<String, Object>>? selection;
    _mockPicker(tester, () => selection);
    await tester.runAsync(() async {
      final account = await _openBulk(tester);
      final good = await File('${temp.path}/usable.txt').writeAsString('001234\r\n001235\n');
      selection = [_picked(good, await good.length())];
      await tester.tap(find.text('Pick TXT or CSV File'));
      await _waitForText(tester, 'usable.txt');

      final bad = await File('${temp.path}/bad.csv').writeAsBytes([0xff]);
      selection = [_picked(bad, 1)];
      await tester.tap(find.text('usable.txt'));
      await _waitForText(tester, 'Use a UTF-8 TXT or CSV file.');
      expect(find.text('usable.txt'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(BulkCheckScreen))).removeCurrentSnackBar();

      final missing = File('${temp.path}/missing.txt');
      selection = [_picked(missing, 6)];
      await tester.tap(find.text('usable.txt'));
      await _waitForText(tester, 'Could not read the selected file.', containing: true);
      ScaffoldMessenger.of(tester.element(find.byType(BulkCheckScreen))).removeCurrentSnackBar();

      final overLimit = await File('${temp.path}/large.txt').writeAsBytes(Uint8List(256 * 1024 + 1));
      selection = [_picked(overLimit, 0)]; // The stream must enforce the limit even with an unknown file size.
      await tester.tap(find.text('usable.txt'));
      await _waitForText(tester, 'Use at most 256 KiB', containing: true);
      expect(find.text('usable.txt'), findsOneWidget);
      expect(account.history.isEmpty, isTrue);

      await _check(tester);
      await _waitForText(tester, '2 no win', containing: true);
      expect(account.history.length, 2);
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  testWidgets('The entry limit counts nonempty inputs before deduplication', (tester) async {
    await tester.runAsync(() async {
      final account = await _openBulk(tester);
      await tester.enterText(find.byType(TextField), List.filled(1001, '001234').join('\n'));
      await _check(tester);
      await _waitForText(tester, 'Use at most 1,000 entries per batch.');
      expect(account.history.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  testWidgets('Retry resumes after the last completed entry and keeps history and notices unique', (tester) async {
    await tester.runAsync(() async {
      final account = await _openBulk(tester);
      await account.bonds.add(
        Bond()
          ..id = 'bulk-fixture'
          ..number = '498382'
          ..denomination = _denomination
          ..status = 'Active'
          ..addedDate = DateTime(2025),
      );
      var failWrite = true;
      Hive.registerAdapter(_FailingRecordAdapter(() => failWrite), override: true);
      try {
        await tester.enterText(find.byType(TextField), '498382,001234\n001235');
        await _check(tester);
        await _waitForText(tester, 'Batch stopped after 1 of 3 entries.', containing: true);
        expect(find.text('498382'), findsOneWidget);
        expect(account.history.values.single.bondNumber, '498382');
        expect(account.notifications.length, 1);
        final firstChecked = account.bonds.values.single.lastChecked;

        failWrite = false;
        await _check(tester);
        await _waitForText(tester, '1 wins • 2 no win', containing: true);
        expect(account.history.values.map((record) => record.bondNumber), unorderedEquals(['498382', '001234', '001235']));
        expect(account.notifications.length, 1);
        expect(account.bonds.values.single.lastChecked, firstChecked);
        expect(tester.takeException(), isNull);
      } finally {
        Hive.registerAdapter(CheckRecordAdapter(), override: true);
      }
    });
  }, variant: _ios);

  testWidgets(
    'Android interruption, cancellation, and failures preserve the previous bulk draft',
    (tester) async {
      var receipt = <String, Object?>{
        'request': 1,
        'status': 'picking',
        'fileName': 'previous.csv',
        'fileContent': '001234',
        'paste': '001235',
      };
      var outcome = 'cancelled';
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_androidPicker, (call) async {
        expect(call.arguments['owner'], AuthService.requireStorage().accountId);
        if (call.method == 'load') return receipt;
        if (call.method == 'open') {
          final draft = Map<String, Object?>.from(call.arguments['draft'] as Map);
          final next = (receipt['request'] as int) + 1;
          receipt = {...draft, 'request': next, 'status': outcome};
          if (outcome == 'selected') {
            receipt['selectedName'] = 'invalid.csv';
            receipt['selectedBytes'] = Uint8List.fromList([0xff]);
          }
          return next;
        }
        throw MissingPluginException(call.method);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_androidPicker, null));

      await tester.runAsync(() async {
        final account = await _openBulk(tester, restoreImport: true);
        await _waitForText(tester, 'File selection was interrupted.', containing: true);
        expect(find.text('previous.csv'), findsOneWidget);
        expect(find.text('001235'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(BulkCheckScreen))).removeCurrentSnackBar();

        await tester.tap(find.text('previous.csv'));
        await tester.pumpAndSettle();
        expect(receipt['status'], 'cancelled');
        expect(find.text('previous.csv'), findsOneWidget);
        expect(find.text('001235'), findsOneWidget);

        outcome = 'failed';
        await tester.tap(find.text('previous.csv'));
        await _waitForText(tester, 'Could not read the selected file.', containing: true);
        expect(find.text('previous.csv'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(BulkCheckScreen))).removeCurrentSnackBar();

        outcome = 'selected';
        await tester.tap(find.text('previous.csv'));
        await _waitForText(tester, 'Use a UTF-8 TXT or CSV file.');
        expect(find.text('previous.csv'), findsOneWidget);
        expect(find.text('invalid.csv'), findsNothing);

        outcome = 'picking';
        await tester.tap(find.text('previous.csv'));
        await tester.pumpAndSettle();
        expect(receipt['status'], 'picking');
        receipt.addAll({
          'status': 'selected',
          'selectedName': 'replacement.csv',
          'selectedBytes': Uint8List.fromList('001236'.codeUnits),
        });
        final request = receipt['request'] as int;
        Future<void> notify(int request) => messenger.handlePlatformMessage(
          'prize_bond/android_bulk_import',
          const StandardMethodCodec().encodeMethodCall(MethodCall('changed', request)),
          null,
        );
        await notify(request - 1);
        await tester.pumpAndSettle();
        expect(find.text('replacement.csv'), findsNothing);
        await notify(request);
        await _waitForText(tester, 'replacement.csv');
        await tester.enterText(find.byType(TextField), '000007');
        await notify(request);
        await tester.pumpAndSettle();
        expect(find.text('000007'), findsOneWidget);
        expect(account.history.isEmpty, isTrue);
        expect(tester.takeException(), isNull);
      });
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}

void _mockPicker(WidgetTester tester, List<Map<String, Object>>? Function() selection) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_picker, (call) async {
    expect(call.method, 'custom');
    expect(call.arguments['withData'], isFalse);
    return selection();
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_picker, null));
}

Map<String, Object> _picked(File file, int size) => {
  'path': file.path,
  'name': file.uri.pathSegments.last,
  'size': size,
};

Future<AccountStorage> _openBulk(WidgetTester tester, {bool restoreImport = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final previous = debugDefaultTargetPlatformOverride;
  late AccountSummary member;
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    member = (await AuthService.registerUser(
      firstName: 'Bulk',
      lastName: 'Fixture',
      mobile: '123',
      email: 'bulk@example.org',
      pin: '0123',
      address: 'Local address',
      city: 'Lahore',
    )).account;
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
  final users = Hive.box<UserProfile>('users');
  await users.put(member.id, users.get(member.id)!.copyWith(isApproved: true));
  await AuthService.selectAccount(member.email);
  final account = (await AuthService.unlock(member.id, '0123'))!;
  await tester.pumpWidget(
    MaterialApp(
      home: BulkCheckScreen(denomination: _denomination, restorePendingImport: restoreImport),
    ),
  );
  return account;
}

Future<void> _check(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Check All'));
  await tester.tap(find.text('Check All'));
}

Future<void> _waitForText(WidgetTester tester, String text, {bool containing = false}) async {
  final target = containing ? find.textContaining(text) : find.text(text);
  for (var frame = 0; frame < 120; frame++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (target.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Did not find "$text".');
}

class _FailingRecordAdapter extends CheckRecordAdapter {
  _FailingRecordAdapter(this.shouldFail);

  final bool Function() shouldFail;

  @override
  void write(BinaryWriter writer, CheckRecord record) {
    if (shouldFail() && record.bondNumber == '001234') throw const FileSystemException('Injected check history write failure');
    super.write(writer, record);
  }
}
