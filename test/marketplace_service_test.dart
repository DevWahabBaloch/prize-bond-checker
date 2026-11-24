import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/listing_model.dart';
import 'package:prize_bond_checking_app/models/notification_model.dart';
import 'package:prize_bond_checking_app/models/user_profile_model.dart';
import 'package:prize_bond_checking_app/screens/marketplace_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/marketplace_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory data;
  late MarketplaceService market;
  late AccountSummary alice;
  late AccountSummary bob;
  late AccountStorage aliceSession;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    data = await Directory.systemTemp.createTemp('marketplace-');
    Hive.init(data.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BondAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CheckRecordAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationModelAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ListingAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(UserProfileAdapter());
    await AuthService.openAccounts();
    AuthService.resumeFromBackground();
    await AuthService.restoreSelection();
    await MarketplaceService.openStorage();
    market = MarketplaceService();
    alice = await _register('alice');
    bob = await _register('bob');
    aliceSession = await _unlock(alice);
  });

  tearDown(() async {
    await AuthService.logout();
    await Hive.close();
    await data.delete(recursive: true);
  });

  test('New listings are shared after reopen and only their active owner can remove them', () async {
    await _post(market, aliceSession);
    final id = market.listings(aliceSession).single.id;
    final persisted = Hive.box<Listing>('listings').get(id)!;
    expect(persisted.ownerAccountId, alice.id);
    expect(persisted.sellerName, 'Seller');
    expect(persisted.sellerPhone, '3001234567');
    expect(persisted.quantity, 2);
    expect(persisted.price, 120.5);
    expect(market.listings(aliceSession).single.canRemove, isTrue);

    await Hive.box<Listing>('listings').close();
    await MarketplaceService.openStorage();
    market = MarketplaceService();
    final bobSession = await _unlock(bob);
    expect(market.listings(bobSession).single.id, id);
    expect(market.listings(bobSession).single.canRemove, isFalse);
    await expectLater(market.remove(bobSession, id), throwsA(isA<MarketplaceException>()));
    expect(market.listings(bobSession).single.id, id);
    expect(market.listings(aliceSession), isEmpty);
    await expectLater(market.remove(aliceSession, id), throwsA(isA<MarketplaceException>()));
    await expectLater(_post(market, aliceSession), throwsA(isA<MarketplaceException>()));

    final owner = await _unlock(alice);
    AuthService.lockForBackground();
    expect(market.listings(owner), isEmpty);
    await expectLater(market.remove(owner, id), throwsA(isA<MarketplaceException>()));
    AuthService.resumeFromBackground();
    final restored = await _unlock(alice);
    await market.remove(restored, id);
    expect(market.listings(restored), isEmpty);
    expect(market.listings(await _unlock(bob)), isEmpty);
  });

  test('Legacy nine-field records remain readable, unassigned, hidden, and untouched', () async {
    await Hive.box<Listing>('listings').close();
    Hive.registerAdapter(_LegacyListingAdapter(), override: true);
    await MarketplaceService.openStorage();
    final legacy = Listing()
      ..id = 'legacy'
      ..sellerName = 'Original seller'
      ..sellerPhone = '3001111111'
      ..denomination = 'Rs. 750'
      ..quantity = 3
      ..price = 755.0
      ..location = 'Karachi'
      ..postedDate = DateTime.utc(2025, 12, 3)
      ..isActive = true;
    final oldBox = Hive.box<Listing>('listings');
    await oldBox.put(7, legacy);
    await oldBox.close();

    Hive.registerAdapter(ListingAdapter(), override: true);
    await MarketplaceService.openStorage();
    market = MarketplaceService();
    expect(market.listings(aliceSession), isEmpty);
    final other = await _unlock(bob);
    expect(market.listings(other), isEmpty);
    await expectLater(market.remove(other, 'legacy'), throwsA(isA<MarketplaceException>()));
    await _post(market, other, phone: '');
    final newListing = market.listings(other).single;
    expect(newListing.sellerPhone, isEmpty);
    await market.remove(other, newListing.id);

    final box = Hive.box<Listing>('listings');
    expect(box.keys, [7]);
    final saved = box.get(7)!;
    expect(saved.ownerAccountId, isNull);
    expect(_legacyFields(saved), _legacyFields(legacy));
  });

  test('Invalid posts cause no write and optional contact fields can be empty', () async {
    for (final request in [
      () => _post(market, aliceSession, name: '   '),
      () => _post(market, aliceSession, denomination: 'Rs. 5'),
      () => _post(market, aliceSession, quantity: '0'),
      () => _post(market, aliceSession, quantity: '-1'),
      () => _post(market, aliceSession, quantity: '1.5'),
      () => _post(market, aliceSession, price: 'NaN'),
      () => _post(market, aliceSession, price: 'Infinity'),
      () => _post(market, aliceSession, price: '0'),
      () => _post(market, aliceSession, price: '-10'),
      () => _post(market, aliceSession, price: '0.001'),
      () => _post(market, aliceSession, phone: '300123'),
    ]) {
      await expectLater(request(), throwsA(isA<MarketplaceException>()));
    }
    expect(Hive.box<Listing>('listings').isEmpty, isTrue);
    await _post(market, aliceSession, phone: '', location: '');
    expect(market.listings(aliceSession).single.sellerPhone, isEmpty);
    expect(market.listings(aliceSession).single.location, 'Pakistan');
  });

  test('Failed Hive writes are propagated and reopening retains the existing listing', () async {
    await _post(market, aliceSession);
    final id = market.listings(aliceSession).single.id;
    final box = Hive.box<Listing>('listings');
    final failingMarket = MarketplaceService(box: _FailingWrites(box));
    await expectLater(_post(failingMarket, aliceSession), throwsA(isA<FileSystemException>()));
    await expectLater(failingMarket.remove(aliceSession, id), throwsA(isA<FileSystemException>()));
    await box.close();
    await MarketplaceService.openStorage();
    expect(MarketplaceService().listings(aliceSession).single.id, id);
  });

  testWidgets('The Market form displays a validation error and can submit on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(340, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const MarketplaceScreen(),
    );
    await tester.pumpWidget(app);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Post Listing'));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(ElevatedButton, 'Post Listing');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter a seller name of up to 80 characters.'), findsOneWidget);
    expect(market.listings(aliceSession), isEmpty);

    for (final (label, input) in [
      ('Your Name', 'Demo seller'),
      ('Quantity', '2'),
      ('Asking Price per bond (Rs.)', '125.50'),
    ]) {
      final field = find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == label);
      await tester.ensureVisible(field);
      await tester.enterText(field, input);
    }
    await tester.runAsync(() async {
      await tester.tap(submit);
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (find.text('Listing posted successfully.').evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Listing posted successfully.'), findsOneWidget);
    expect(find.text('Demo seller'), findsOneWidget);
    expect(find.byTooltip('Remove listing'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => _unlock(bob));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Demo seller'), findsOneWidget);
    expect(find.byTooltip('Remove listing'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _post(
  MarketplaceService market,
  AccountStorage account, {
  String name = ' Seller ',
  String phone = '+92 (300) 1234567',
  String location = ' Lahore ',
  String denomination = 'Rs. 100',
  String quantity = '2',
  String price = '120.50',
}) => market.post(
  account,
  name: name,
  phone: phone,
  location: location,
  denomination: denomination,
  quantity: quantity,
  price: price,
);

Future<AccountSummary> _register(String name) => _withIosCredentials(() async {
  final account = (await AuthService.registerUser(
    firstName: name,
    lastName: 'Fixture',
    mobile: '123',
    email: '$name@example.org',
    pin: '0123',
    address: 'Demo address',
    city: 'Lahore',
  )).account;
  final box = Hive.box<UserProfile>('users');
  await box.put(account.id, box.get(account.id)!.copyWith(isApproved: true));
  return account;
});

Future<AccountStorage> _unlock(AccountSummary account) => _withIosCredentials(() async {
  await AuthService.selectAccount(account.email);
  return (await AuthService.unlock(account.id, '0123'))!;
});

Future<T> _withIosCredentials<T>(Future<T> Function() action) async {
  final previous = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    return await action();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

List<Object> _legacyFields(Listing listing) => [
  listing.id,
  listing.sellerName,
  listing.sellerPhone,
  listing.denomination,
  listing.quantity,
  listing.price,
  listing.location,
  listing.postedDate,
  listing.isActive,
];

class _LegacyListingAdapter extends ListingAdapter {
  @override
  void write(BinaryWriter writer, Listing obj) {
    final fields = _legacyFields(obj);
    writer.writeByte(fields.length);
    for (final (index, value) in fields.indexed) {
      writer
        ..writeByte(index)
        ..write(value);
    }
  }
}

class _FailingWrites implements Box<Listing> {
  _FailingWrites(this.box);

  final Box<Listing> box;

  @override
  Listing? get(dynamic key, {Listing? defaultValue}) => box.get(key, defaultValue: defaultValue);

  @override
  Future<void> put(dynamic key, Listing value) async =>
      throw const FileSystemException('Injected listing write failure');

  @override
  Future<void> delete(dynamic key) async => throw const FileSystemException('Injected listing deletion failure');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
