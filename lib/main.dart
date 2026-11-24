import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'ios_privacy_cover.dart';
import 'models/draw_result_model.dart';
import 'models/bond_model.dart';
import 'models/check_record_model.dart';
import 'models/notification_model.dart';
import 'models/listing_model.dart';
import 'models/prize_entry_model.dart';
import 'models/user_profile_model.dart';
import 'services/draw_service.dart';
import 'services/draw_reminder_service.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/pin_screen.dart';
import 'services/auth_service.dart';
import 'services/marketplace_service.dart';
import 'services/notification_service.dart';

void main() => runApp(const PrizeBondApp());

Future<void> _initializeHive() => Hive.initFlutter();

void _registerAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) Hive.registerAdapter(adapter);
}

Future<void> _openLocalStorage() async {
  _registerAdapter(PrizeEntryAdapter());
  _registerAdapter(DrawResultAdapter());
  _registerAdapter(BondAdapter());
  _registerAdapter(CheckRecordAdapter());
  _registerAdapter(NotificationModelAdapter());
  _registerAdapter(ListingAdapter());
  _registerAdapter(UserProfileAdapter());
  await Hive.openBox<DrawResult>('draws');
  await MarketplaceService.openStorage();
  await AuthService.openAccounts();
}

class PrizeBondApp extends StatefulWidget {
  const PrizeBondApp({super.key, this.initializeHive = _initializeHive});

  final Future<void> Function() initializeHive;

  @override
  State<PrizeBondApp> createState() => _PrizeBondAppState();
}

class _PrizeBondAppState extends State<PrizeBondApp> with WidgetsBindingObserver {
  static const _privacyChannel = MethodChannel('prize_bond/session_privacy');
  var _navigatorKey = GlobalKey<NavigatorState>();
  var _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _ready = false;
  bool _covered = false;
  bool _backgrounded = false;
  bool _returnToAdminEntry = false;
  IosPrivacyCover? _iosCover;
  bool _lockedSinceNativeRequest = false;
  late final StreamSubscription<AccountStorage> _reminderSuspension;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reminderSuspension = AuthService.storageRevocations.listen((previous) {
      unawaited(DrawReminderService().suspend(previous));
    });
    AuthService.resumeFromBackground();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _iosCover = IosPrivacyCover();
      _privacyChannel.setMethodCallHandler(_handleNativeCover);
    }
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.detached) didChangeAppLifecycleState(state);
  }

  Future<void> _handleNativeCover(MethodCall call) async {
    final cover = _iosCover!;
    if (call.method == 'coverReleased') {
      final generation = call.arguments;
      if (generation is int && cover.presentationConfirmed(generation)) setState(() {});
      return;
    }
    if (call.method != 'awaitSafeFrame') return;
    if (call.arguments case {
      'generation': final int generation,
      'requiresLock': final bool requiresLock,
      'proof': final String proof,
    }) {
      if (!cover.request(generation, proof)) return;
      // The native request and Flutter's lifecycle events use different channels.
      final stillAuthenticated = AuthService.unlockedStorage != null || AuthService.hasAdminAccess;
      if (requiresLock && (!_lockedSinceNativeRequest || stillAuthenticated)) {
        _lockForBackground();
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) _resume();
      }
      _lockedSinceNativeRequest = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_iosCover != null) _privacyChannel.setMethodCallHandler(null);
    AuthService.lockForBackground();
    unawaited(_reminderSuspension.cancel());
    super.dispose();
  }

  void _lockForBackground() {
    if (_backgrounded) return;
    _returnToAdminEntry = AuthService.hasAdminAccess;
    AuthService.lockForBackground();
    _backgrounded = true;
    _lockedSinceNativeRequest = true;
  }

  void _resume() {
    AuthService.resumeFromBackground();
    if (AuthService.unlockedStorage case final account?) {
      unawaited(DrawReminderService().reconcile(account));
    }
    if (_covered || _backgrounded) {
      setState(() {
        if (_backgrounded && _ready) {
          // Discard private pages, dialogs, and queued snackbars in one rebuild.
          _navigatorKey = GlobalKey<NavigatorState>();
          _messengerKey = GlobalKey<ScaffoldMessengerState>();
        }
        _backgrounded = false;
        _covered = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
      return;
    }

    if (state != AppLifecycleState.inactive) _lockForBackground();
    if (!_covered) setState(() => _covered = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) {
        final proof = _covered ? null : _iosCover?.proof;
        final masked = _covered || proof != null;
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: masked,
              child: Offstage(offstage: masked, child: child),
            ),
            if (_covered) const ColoredBox(key: ValueKey('session-privacy-cover'), color: Color(0xFFFAFBFC)),
            if (proof != null) IosPrivacyFrame(proof: proof),
          ],
        );
      },
      title: 'Prize Bond Checking App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5BFF), brightness: Brightness.light),
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFBFC),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      ),
      home: _ready
          ? (_returnToAdminEntry ? const LandingScreen() : _accountEntry())
          : _StartupRouter(initializeHive: widget.initializeHive, onReady: () => _ready = true),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter({required this.initializeHive, required this.onReady});

  final Future<void> Function() initializeHive;
  final VoidCallback onReady;

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  String? _startupError;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final draws = DrawService();
    try {
      await widget.initializeHive();
      await _openLocalStorage();
      await draws.importBundledSeed();
      await AuthService.restoreSelection();
      if (!mounted) return;
      widget.onReady();
      final destination = _accountEntry();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => destination,
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(NotificationService().initializeDeviceNotifications());
        unawaited(DrawReminderService().start());
      });
    } catch (error, stackTrace) {
      debugPrint('App startup failed: $error');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 6);
      if (mounted) {
        setState(() {
          _startupError = error is DrawImportFailure
              ? 'Could not import the simulated draw catalog. Please retry.'
              : 'Could not open the app. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF2D5BFF)),
              const SizedBox(height: 24),
              if (_startupError != null) ...[
                Text(_startupError!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() => _startupError = null);
                    unawaited(_start());
                  },
                  child: const Text('Retry'),
                ),
              ] else
                const CircularProgressIndicator(color: Color(0xFF2D5BFF)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _accountEntry() {
  final account = AuthService.selectedAccount;
  if (account == null) return const LandingScreen();
  if (account.isApproved && !account.isRejected) return PinScreen(accountId: account.id);
  return PendingApprovalScreen(accountId: account.id, email: account.email);
}
