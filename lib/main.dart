import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'models/draw_result_model.dart';
import 'models/bond_model.dart';
import 'models/check_record_model.dart';
import 'models/notification_model.dart';
import 'models/listing_model.dart';
import 'services/draw_service.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/pin_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(DrawResultAdapter());
  Hive.registerAdapter(BondAdapter());
  Hive.registerAdapter(CheckRecordAdapter());
  Hive.registerAdapter(NotificationModelAdapter());
  Hive.registerAdapter(ListingAdapter());

  await Hive.openBox<DrawResult>('draws');
  await Hive.openBox<Bond>('bonds');
  await Hive.openBox<CheckRecord>('check_history');
  await Hive.openBox<NotificationModel>('notifications');
  await Hive.openBox<Listing>('listings');

  await DrawService().seedIfEmpty();

  await NotificationService().init();

  runApp(const PrizeBondApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await DrawService().autoCheckAllBonds();
  });
}

class PrizeBondApp extends StatelessWidget {
  const PrizeBondApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prize Bond Checking App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5BFF), brightness: Brightness.light),
        fontFamily: 'Inter',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFBFC),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      ),
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final loggedIn = await AuthService.isLoggedIn();
    final approved = await AuthService.isApproved();

    if (!mounted) return;

    Widget destination;

    if (!loggedIn) {
      destination = const LandingScreen();
    } else if (!approved) {
      final profile = await AuthService.getUserProfile();
      if (!mounted) return;
      destination = PendingApprovalScreen(email: profile['email'] ?? '');
    } else {
      destination = const PinScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAFBFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF2D5BFF)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF2D5BFF)),
          ],
        ),
      ),
    );
  }
}
