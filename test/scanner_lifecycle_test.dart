import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' show CameraController, CameraImage;
// Exercise the camera plugin boundary without native camera hardware.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/notification_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/widgets/input_image_converter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ocr = MethodChannel('google_mlkit_text_recognizer');
final _ios = TargetPlatformVariant({TargetPlatform.iOS});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('scanner-lifecycle-');
    Hive.init(temp.path);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BondAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CheckRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationModelAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
    await AuthService.openAccounts();
    AuthService.resumeFromBackground();
    await AuthService.restoreSelection();
  });

  tearDown(() async {
    await AuthService.logout();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('Android uses packed NV21 and iOS uses BGRA with valid plane sizes', () async {
    const camera = CameraDescription(name: 'demo', lensDirection: CameraLensDirection.back, sensorOrientation: 90);
    final controller = CameraController(camera, ResolutionPreset.medium);
    addTearDown(controller.dispose);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    bool supported(CameraImageData data) =>
        InputImageConverter.fromCameraImage(
          image: CameraImage.fromPlatformInterface(data),
          controller: controller,
          cameraDescription: camera,
        ) !=
        null;

    CameraImageData nv21(int bytes) => CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.nv21, raw: 17),
      planes: [CameraImagePlane(bytes: Uint8List(bytes), bytesPerRow: 2)],
      width: 2,
      height: 2,
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(supported(nv21(6)), isTrue);
    expect(supported(nv21(5)), isFalse);
    expect(supported(_image()), isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(supported(_image()), isTrue);
    expect(supported(nv21(6)), isFalse);
    expect(supported(_image(supported: false)), isFalse);
  });

  testWidgets('Camera permission denial and stream errors leave a working retry action', (tester) async {
    final camera = _ScannerCamera()..denyPermission = true;
    _install(tester, camera, () async => _recognized);
    await tester.runAsync(() async {
      await _openScanner(tester, captureOnly: true);
      await tester.tap(find.text('Scan Now'));
      await _waitFor(tester, () => find.textContaining('Camera permission was denied').evaluate().isNotEmpty);
      expect(find.text('Starting camera...'), findsNothing);

      camera.denyPermission = false;
      camera.failStreamStart = true;
      await tester.tap(find.text('Scan Now'));
      await _waitFor(tester, () => find.textContaining('Could not start the camera stream').evaluate().isNotEmpty);
      expect(find.text('Starting camera...'), findsNothing);

      camera.failStreamStart = false;
      await _startStream(tester);
      camera.frames.addError(PlatformException(code: 'cameraLost'));
      await _waitFor(tester, () => find.textContaining('The camera stream stopped').evaluate().isNotEmpty);
      await _startStream(tester);
      camera.frames.add(_image());
      await _waitFor(tester, () => find.text('Use scanned number').evaluate().isNotEmpty);
      expect(find.text('001234'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  testWidgets('Leaving during camera initialization releases the abandoned controller', (tester) async {
    final camera = _ScannerCamera()..initialization = Completer<void>();
    _install(tester, camera, () async => _recognized);
    await tester.runAsync(() async {
      final account = await _openScanner(tester);
      await tester.tap(find.text('Scan Now'));
      await _waitFor(tester, () => camera.initializations == 1);
      await _unmount(tester);
      camera.initialization!.complete();
      await _waitFor(tester, () => camera.disposals == 1);
      expect(camera.streamStarts, 0);
      expect(account.history.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  testWidgets('An inactive permission prompt defers streaming until resume', (tester) async {
    final camera = _ScannerCamera()..initialization = Completer<void>();
    _install(tester, camera, () async => _recognized);
    await tester.runAsync(() async {
      await _openScanner(tester, captureOnly: true);
      await tester.tap(find.text('Scan Now'));
      await _waitFor(tester, () => camera.initializations == 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      camera.initialization!.complete();
      await tester.pump();
      expect(camera.streamStarts, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _waitFor(tester, () => find.text('Scanning...').evaluate().isNotEmpty);
      expect(camera.streamStarts, 1);
      camera.frames.add(_image());
      await _waitFor(tester, () => find.text('Number captured').evaluate().isNotEmpty);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  testWidgets('Unsupported frames and OCR errors are retryable', (tester) async {
    final camera = _ScannerCamera();
    var scans = 0;
    _install(tester, camera, () async {
      if (++scans == 1) throw PlatformException(code: 'recognitionFailed');
      return _recognized;
    });
    await tester.runAsync(() async {
      await _openScanner(tester, captureOnly: true);
      await _startStream(tester);
      camera.frames.add(_image(supported: false));
      await _waitFor(tester, () => find.textContaining('unsupported image').evaluate().isNotEmpty);
      expect(scans, 0);

      await _startStream(tester);
      camera.frames.add(_image());
      await _waitFor(tester, () => find.textContaining('Could not read the bond number').evaluate().isNotEmpty);

      await _startStream(tester);
      camera.frames.add(_image());
      await _waitFor(tester, () => find.text('Number captured').evaluate().isNotEmpty);
      expect(scans, 2);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });
  }, variant: _ios);

  for (final lockAccount in [false, true]) {
    testWidgets('Pending OCR cannot check after ${lockAccount ? 'account lock' : 'scan cancellation'}', (tester) async {
      final camera = _ScannerCamera();
      final pending = Completer<Object?>();
      var scans = 0;
      _install(tester, camera, () {
        scans++;
        return pending.future;
      });
      await tester.runAsync(() async {
        final account = await _openScanner(tester);
        await _startStream(tester);
        camera.frames.add(_image());
        camera.frames.add(_image());
        await _waitFor(tester, () => scans == 1);

        if (lockAccount) {
          AuthService.lockForBackground();
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        } else {
          await tester.tap(find.text('Cancel Scan'));
        }
        await _waitFor(tester, () => camera.disposals == 1);
        pending.complete(_recognized);
        await tester.pumpAndSettle();
        if (lockAccount) {
          AuthService.resumeFromBackground();
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();
        }
        expect(scans, 1);
        expect(find.text('Scan Now'), findsOneWidget);
        expect(find.text('Results Unavailable'), findsNothing);
        expect(Hive.box<CheckRecord>('check_history_${account.accountId}').isEmpty, isTrue);
        expect(Hive.box<NotificationModel>('notifications_${account.accountId}').isEmpty, isTrue);
        await _unmount(tester);
        expect(tester.takeException(), isNull);
      });
    }, variant: _ios);
  }
}

const _recognized = {'text': 'Prize bond 001234', 'blocks': <Object>[]};

void _install(WidgetTester tester, _ScannerCamera camera, Future<Object?> Function() recognize) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final original = CameraPlatform.instance;
  CameraPlatform.instance = camera;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_ocr, (call) => call.method == 'vision#startTextRecognizer' ? recognize() : Future.value());
  addTearDown(() async {
    messenger.setMockMethodCallHandler(_ocr, null);
    CameraPlatform.instance = original;
    await camera.frames.close();
  });
}

Future<AccountStorage> _openScanner(WidgetTester tester, {bool captureOnly = false}) async {
  final member = (await AuthService.registerUser(
    firstName: 'Scanner',
    lastName: 'Fixture',
    mobile: '123',
    email: 'scanner@example.org',
    pin: '0123',
    address: 'Local address',
    city: 'Lahore',
  )).account;
  final users = Hive.box<UserProfile>('users');
  await users.put(member.id, users.get(member.id)!.copyWith(isApproved: true));
  await AuthService.selectAccount(member.email);
  final account = (await AuthService.unlock(member.id, '0123'))!;
  await tester.pumpWidget(MaterialApp(home: ScannerScreen(captureOnly: captureOnly)));
  return account;
}

Future<void> _startStream(WidgetTester tester) async {
  await tester.tap(find.text('Scan Now'));
  await _waitFor(tester, () => find.text('Scanning...').evaluate().isNotEmpty);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 120; frame++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Scanner did not reach the expected state.');
}

CameraImageData _image({bool supported = true}) => CameraImageData(
  format: supported
      ? const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 1111970369)
      : const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
  planes: [CameraImagePlane(bytes: Uint8List(16), bytesPerRow: 8)],
  height: 2,
  width: 2,
);

class _ScannerCamera extends CameraPlatform {
  final frames = StreamController<CameraImageData>.broadcast();
  final _errors = StreamController<CameraErrorEvent>.broadcast();
  Completer<void>? initialization;
  bool denyPermission = false;
  bool failStreamStart = false;
  int initializations = 0;
  int streamStarts = 0;
  int disposals = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => [
    const CameraDescription(name: 'demo', lensDirection: CameraLensDirection.back, sensorOrientation: 0),
  ];

  @override
  Future<int> createCameraWithSettings(CameraDescription cameraDescription, MediaSettings? mediaSettings) async {
    if (denyPermission) throw PlatformException(code: 'CameraAccessDenied');
    return 1;
  }

  @override
  Future<void> initializeCamera(int cameraId, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {
    initializations++;
    await initialization?.future;
  }

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
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId, {CameraImageStreamOptions? options}) {
    if (failStreamStart) throw PlatformException(code: 'streamFailed');
    streamStarts++;
    return frames.stream;
  }

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox();

  @override
  Future<void> dispose(int cameraId) async {
    if (cameraId == 1) disposals++;
  }
}
