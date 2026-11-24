import 'dart:async';
import 'dart:io';

// Replace the installed camera platform with a test camera.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/models/bond_check_result.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/models/notification_model.dart';
import 'package:prize_bond_checking_app/models/prize_entry_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/screens/bulk_check_screen.dart';
import 'package:prize_bond_checking_app/screens/check_bond_screen.dart';
import 'package:prize_bond_checking_app/screens/my_bonds_screen.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/bond_checking_service.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ocr = MethodChannel('google_mlkit_text_recognizer');
const _denomination = 'Rs. 1500';
const _number = '001234';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory data;
  late Box<DrawResult> draws;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    data = await Directory.systemTemp.createTemp('draw-workflows-');
    Hive.init(data.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(DrawResultAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BondAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CheckRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationModelAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(PrizeEntryAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
    draws = await Hive.openBox<DrawResult>('draws');
    await DrawService().importBundledSeed();
    await AuthService.openAccounts();
    AuthService.resumeFromBackground();
    await AuthService.restoreSelection();
  });

  tearDown(() async {
    await AuthService.logout();
    await Hive.close();
    await data.delete(recursive: true);
  });

  for (final (number, outcome) in [
    ('498382', BondCheckOutcome.win),
    (_number, BondCheckOutcome.noWin),
    (_number, BondCheckOutcome.resultsUnavailable),
  ]) {
    testWidgets('All five checking workflows agree on ${outcome.label}', (tester) async {
      _setWorkflowViewport(tester);
      final camera = _mockScanner(tester, number);

      await tester.runAsync(() async {
        if (outcome == BondCheckOutcome.resultsUnavailable) {
          await draws.deleteAll(
            draws.toMap().entries.where((entry) => entry.value.denomination == _denomination).map((entry) => entry.key),
          );
        }
        final user = await _approved('widget@example.org');
        final account = await _unlock(user);
        await account.bonds.add(_bond(number, _denomination));
        expect(AppConfig.defaultDenomination, _denomination);
        await BondCheckingService().refreshAccount(account);
        expect(account.bonds.values.single.status, outcome.label);
        expect(account.history.isEmpty, isTrue);

        final scopedNegative = find.textContaining('eligible FYP sample draws');
        await tester.pumpWidget(MaterialApp(home: CheckBondScreen(initialBondNumber: number)));
        await tester.ensureVisible(find.text('Check Bond'));
        await tester.tap(find.text('Check Bond'));
        await _pumpUntil(tester, () => find.text(outcome.label).evaluate().isNotEmpty);
        if (outcome == BondCheckOutcome.noWin) expect(scopedNegative, findsOneWidget);
        expect(find.text(number), findsWidgets);

        await tester.pumpWidget(
          const MaterialApp(
            key: ValueKey('bulk'),
            home: BulkCheckScreen(denomination: _denomination),
          ),
        );
        await tester.enterText(find.byType(TextField), '$number,$number');
        await tester.ensureVisible(find.text('Check All'));
        await tester.tap(find.text('Check All'));
        await _pumpUntil(tester, () => find.textContaining('${outcome.label} •').evaluate().isNotEmpty);
        final expectedCount = switch (outcome) {
          BondCheckOutcome.win => '1 wins',
          BondCheckOutcome.noWin => '1 no win',
          BondCheckOutcome.resultsUnavailable => '1 unavailable',
        };
        expect(find.textContaining(expectedCount), findsOneWidget);
        expect(find.text(number), findsOneWidget);
        if (outcome == BondCheckOutcome.noWin) expect(scopedNegative, findsOneWidget);

        await tester.pumpWidget(const MaterialApp(key: ValueKey('saved'), home: MyBondsScreen()));
        await tester.ensureVisible(find.text('Check Now'));
        await tester.tap(find.text('Check Now'));
        await _pumpUntil(tester, () => find.byType(AlertDialog).evaluate().isNotEmpty);
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(outcome.label)), findsWidgets);
        if (outcome == BondCheckOutcome.noWin) expect(scopedNegative, findsOneWidget);
        expect(account.bonds.values.single.status, outcome.label);

        await tester.pumpWidget(
          const MaterialApp(
            key: ValueKey('scanner'),
            home: ScannerScreen(initialDenomination: _denomination),
          ),
        );
        await tester.tap(find.text('Scan Now'));
        await _pumpUntil(tester, () => find.text('Scanning...').evaluate().isNotEmpty);
        camera.frames.add(_bgraFrame());
        final scanTitle = outcome == BondCheckOutcome.win ? '🎉 This Bond Won!' : outcome.label;
        await _pumpUntil(tester, () => find.text(scanTitle).evaluate().isNotEmpty);
        expect(find.text(number), findsOneWidget);
        if (outcome == BondCheckOutcome.noWin) expect(scopedNegative, findsOneWidget);

        expect(account.history.values.single.bondNumber, number);
        expect(account.history.values.single.resultStatus, outcome.label);
        final winNotices = NotificationService().notifications(account).where((notice) => notice.type == NotificationType.win);
        expect(winNotices, hasLength(outcome == BondCheckOutcome.win ? 1 : 0));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
  }

  testWidgets(
    'A completed scan returns the checked denomination to the manual screen once',
    (tester) async {
      _setWorkflowViewport(tester);
      final camera = _mockScanner(tester, '770487');
      await tester.runAsync(() async {
        final account = await _unlock(await _approved('scan-handoff@example.org'));
        await tester.pumpWidget(const MaterialApp(home: CheckBondScreen()));
        await tester.ensureVisible(find.text('Scan Bond'));
        await tester.tap(find.text('Scan Bond'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rs. 200').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Scan Now'));
        await _pumpUntil(tester, () => find.text('Scanning...').evaluate().isNotEmpty);
        camera.frames.add(_bgraFrame());
        await _pumpUntil(tester, () => find.text('Back').evaluate().isNotEmpty);
        expect(account.history.values.single.denomination, 'Rs. 200');
        await tester.tap(find.text('Back'));
        await _pumpUntil(tester, () => find.byType(AlertDialog).evaluate().isNotEmpty);
        final dialog = find.byType(AlertDialog);
        expect(find.descendant(of: dialog, matching: find.text('Rs. 200')), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text('Won')), findsOneWidget);
        expect(account.history.length, 1);
        expect(account.notifications.length, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('Add Bond preserves its draft across scanning and a failed save', (tester) async {
    _setWorkflowViewport(tester);
    final camera = _mockScanner(tester, _number);

    await tester.runAsync(() async {
      final owner = await _approved('draft@example.org');
      final account = await _unlock(owner);
      await tester.pumpWidget(const MaterialApp(home: MyBondsScreen()));
      await tester.tap(find.text('Add Bond'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '006789');
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();
      final date = DateUtils.dateOnly(DateTime.now());
      final storedDate = DateTime.utc(date.year, date.month, date.day);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final issueDateText = '${date.day}/${date.month}/${date.year}';

      final fields = find.byType(DropdownButtonFormField<String>);
      await tester.tap(fields.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quetta').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('006789'), findsOneWidget);
      expect(find.text(issueDateText), findsOneWidget);
      expect(tester.state<FormFieldState<String>>(fields.at(1)).value, 'Quetta');

      await tester.tap(find.text('Scan Instead'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rs. 200').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan Now'));
      await _pumpUntil(tester, () => find.text('Scanning...').evaluate().isNotEmpty);
      camera.frames.add(_bgraFrame());
      await _pumpUntil(tester, () => find.text('Use scanned number').evaluate().isNotEmpty);
      await tester.tap(find.text('Use scanned number'));
      await tester.pumpAndSettle();
      expect(find.text(_number), findsOneWidget);
      expect(find.text(issueDateText), findsOneWidget);
      expect(tester.state<FormFieldState<String>>(fields.at(0)).value, 'Rs. 200');
      expect(tester.state<FormFieldState<String>>(fields.at(1)).value, 'Quetta');
      expect(account.bonds.isEmpty && account.history.isEmpty && account.notifications.isEmpty, isTrue);

      final save = find.descendant(of: find.byType(AlertDialog), matching: find.text('Add Bond'));
      var failWrite = true;
      Hive.registerAdapter(_FailingBondAdapter(() => failWrite), override: true);
      try {
        await tester.tap(save);
        await _pumpUntil(tester, () => find.text('Could not save the bond. Please try again.').evaluate().isNotEmpty);
        expect(account.bonds.isEmpty, isTrue);
        expect(find.text(_number), findsOneWidget);
        expect(find.text(issueDateText), findsOneWidget);

        failWrite = false;
        await tester.tap(save);
        await tester.tap(save);
        await _pumpUntil(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
      } finally {
        Hive.registerAdapter(BondAdapter(), override: true);
      }

      final saved = account.bonds.values.single;
      expect(saved.number, _number);
      expect(saved.denomination, 'Rs. 200');
      expect(saved.issueDate, storedDate);
      expect(saved.issueCity, 'Quetta');
      expect(account.history.isEmpty && account.notifications.isEmpty, isTrue);

      await BondCheckingService().check(account, _number, 'Rs. 200', recordHistory: false);
      expect(account.bonds.values.single.issueDate, storedDate);
      expect(account.bonds.values.single.issueCity, 'Quetta');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  test(
    'Concurrent and automatic checks deduplicate account history and notifications without assigning legacy records',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final legacyBonds = await Hive.openBox<Bond>('bonds');
      final legacyHistory = await Hive.openBox<CheckRecord>('check_history');
      final legacyInbox = await Hive.openBox<NotificationModel>('notifications');
      await legacyBonds.put(1, _bond('999999', 'Rs. 200'));
      await legacyHistory.put(
        5,
        CheckRecord()
          ..bondNumber = '999999'
          ..denomination = 'Rs. 200'
          ..checkedAt = DateTime(2025)
          ..resultStatus = 'No Win'
          ..drawNumber = 'N/A'
          ..drawDate = 'N/A',
      );
      await legacyInbox.put(
        3,
        NotificationModel()
          ..id = 'legacy'
          ..typeIndex = 0
          ..title = 'Legacy'
          ..body = 'Legacy account-free record'
          ..timestamp = DateTime(2025)
          ..isRead = false,
      );

      final a = await _approved('alice@example.org');
      final b = await _approved('bob@example.org');
      final alice = await _unlock(a);
      final fixedDay = DateTime(2026, 12, 21);
      final service = BondCheckingService(clock: () => fixedDay);
      const winner = '770487';
      const denomination = 'Rs. 200';
      final issueDate = DateTime.utc(2026, 12, 1);
      await alice.bonds.add(
        _bond(winner, denomination)
          ..issueDate = issueDate
          ..issueCity = 'Lahore',
      );

      final results = await Future.wait(List.generate(3, (_) => service.check(alice, winner, denomination)));
      expect(results.every((result) => result.outcome == BondCheckOutcome.win), isTrue);
      final saved = alice.bonds.values.single;
      expect(saved.status, 'Won');
      expect(saved.lastResult, '91');
      expect(saved.lastChecked, fixedDay);
      expect(saved.issueDate, issueDate);
      expect(saved.issueCity, 'Lahore');
      expect(alice.history.length, 1);
      expect(alice.notifications.length, 1);

      await service.refreshAccount(alice);
      final afterFirstRefresh = alice.notifications.length;
      await service.refreshAccount(alice);
      expect(afterFirstRefresh, 22);
      expect(alice.history.length, 1);
      expect(alice.notifications.length, 22);
      await NotificationService().clearAll(alice);
      await service.refreshAccount(alice);
      await service.check(alice, winner, denomination);
      expect(alice.notifications.isEmpty, isTrue);

      final bob = await _unlock(b);
      expect(bob.history.isEmpty, isTrue);
      expect(bob.notifications.isEmpty, isTrue);
      expect(bob.bonds.isEmpty, isTrue);
      await expectLater(service.check(alice, winner, denomination), throwsA(isA<AccountException>()));
      await service.check(bob, winner, denomination);
      expect(bob.history.length, 1);
      expect(bob.notifications.length, 1);

      final restored = await _unlock(a);
      expect(restored.history.length, 1);
      expect(restored.notifications.isEmpty, isTrue);
      expect(legacyBonds.get(1)?.number, '999999');
      expect(legacyHistory.get(5)?.bondNumber, '999999');
      expect(legacyInbox.get(3)?.id, 'legacy');
    },
  );
}

Future<AccountSummary> _approved(String email) async {
  final user = (await AuthService.registerUser(
    firstName: 'Local',
    lastName: 'Member',
    mobile: '123',
    email: email,
    pin: '0123',
    address: 'Demo address',
    city: 'Lahore',
  )).account;
  final box = Hive.box<UserProfile>('users');
  await box.put(user.id, box.get(user.id)!.copyWith(isApproved: true));
  return user;
}

Future<AccountStorage> _unlock(AccountSummary user) async {
  await AuthService.selectAccount(user.email);
  return (await AuthService.unlock(user.id, '0123'))!;
}

Bond _bond(String number, String denomination) => Bond()
  ..id = 'fixture-$number'
  ..number = number
  ..denomination = denomination
  ..status = 'Active'
  ..addedDate = DateTime(2025);

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 120; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (condition()) {
      await tester.pumpAndSettle();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected widget did not render.');
}

void _setWorkflowViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

_FixtureCamera _mockScanner(WidgetTester tester, String number) {
  final original = CameraPlatform.instance;
  final camera = _FixtureCamera();
  CameraPlatform.instance = camera;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_ocr, (call) async {
    if (call.method == 'vision#closeTextRecognizer') return null;
    expect(call.method, 'vision#startTextRecognizer');
    return {'text': 'Prize Bond $number Series', 'blocks': []};
  });
  addTearDown(() async {
    messenger.setMockMethodCallHandler(_ocr, null);
    CameraPlatform.instance = original;
    await camera.frames.close();
  });
  return camera;
}

CameraImageData _bgraFrame() => CameraImageData(
  format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1111970369),
  planes: [CameraImagePlane(bytes: Uint8List(16), bytesPerRow: 8)],
  height: 2,
  width: 2,
);

class _FixtureCamera extends CameraPlatform {
  final frames = StreamController<CameraImageData>.broadcast();
  final _errors = StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => [
    const CameraDescription(name: 'demo', lensDirection: CameraLensDirection.back, sensorOrientation: 0),
  ];

  @override
  Future<int> createCameraWithSettings(CameraDescription cameraDescription, MediaSettings? mediaSettings) async => 1;

  @override
  Future<void> initializeCamera(int cameraId, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(CameraInitializedEvent(cameraId, 200, 200, ExposureMode.auto, false, FocusMode.auto, false));

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => const Stream.empty();

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId, {CameraImageStreamOptions? options}) => frames.stream;

  @override
  Widget buildPreview(int cameraId) => const SizedBox();

  @override
  Future<void> dispose(int cameraId) async {}
}

class _FailingBondAdapter extends BondAdapter {
  _FailingBondAdapter(this.shouldFail);

  final bool Function() shouldFail;

  @override
  void write(BinaryWriter writer, Bond bond) {
    if (shouldFail()) throw const FileSystemException('Injected save failure');
    super.write(writer, bond);
  }
}
