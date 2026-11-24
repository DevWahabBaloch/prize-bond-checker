import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/listing_model.dart';
import 'auth_service.dart';

class MarketplaceException implements Exception {
  const MarketplaceException(this.message);

  final String message;
}

class MarketplaceListing {
  MarketplaceListing._(Listing listing, String accountId)
    : id = listing.id,
      sellerName = listing.sellerName,
      sellerPhone = listing.sellerPhone,
      denomination = listing.denomination,
      quantity = listing.quantity,
      price = listing.price,
      location = listing.location,
      postedDate = listing.postedDate,
      canRemove = listing.ownerAccountId == accountId;

  final String id;
  final String sellerName;
  final String sellerPhone;
  final String denomination;
  final int quantity;
  final double price;
  final String location;
  final DateTime postedDate;
  final bool canRemove;
}

class MarketplaceService {
  MarketplaceService({Box<Listing>? box}) : _box = box ?? Hive.box<Listing>(_boxName);

  static const _boxName = 'listings';
  final Box<Listing> _box;

  static Future<void> openStorage() async {
    // Hive runs automatic compaction after committing a write. Keep it out of
    // post/remove so a compaction error cannot misreport a committed change.
    await Hive.openBox<Listing>(_boxName, compactionStrategy: (_, _) => false);
  }

  Listenable get changes => _box.listenable();

  List<MarketplaceListing> listings(AccountStorage account) {
    if (!AuthService.canUseStorage(account)) return [];
    return [
      for (final row in _box.values.toList().reversed)
        if (row.isActive && (row.ownerAccountId?.isNotEmpty ?? false)) MarketplaceListing._(row, account.accountId),
    ];
  }

  Future<void> post(
    AccountStorage account, {
    required String name,
    required String phone,
    required String location,
    required String denomination,
    required String quantity,
    required String price,
  }) async {
    _requireSession(account);
    name = name.trim();
    location = location.trim();
    if (name.isEmpty || name.length > 80) {
      throw const MarketplaceException('Enter a seller name of up to 80 characters.');
    }
    if (location.length > 80) throw const MarketplaceException('Enter a location of up to 80 characters.');
    if (!AppConfig.denominations.contains(denomination)) {
      throw const MarketplaceException('Select a supported denomination.');
    }

    final count = int.tryParse(quantity.trim(), radix: 10);
    if (count == null || count <= 0) throw const MarketplaceException('Enter a positive whole-number quantity.');
    final priceText = price.trim();
    final amount = double.tryParse(priceText);
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(priceText) || amount == null || !amount.isFinite || amount <= 0) {
      throw const MarketplaceException('Enter a price greater than zero with up to two decimal places.');
    }

    final contact = _nationalPhone(phone);
    final id = const Uuid().v4();
    await _box.put(
      id,
      Listing()
        ..id = id
        ..ownerAccountId = account.accountId
        ..sellerName = name
        ..sellerPhone = contact
        ..denomination = denomination
        ..quantity = count
        ..price = amount
        ..location = location.isEmpty ? 'Pakistan' : location
        ..postedDate = DateTime.now()
        ..isActive = true,
    );
  }

  Future<void> remove(AccountStorage account, String id) async {
    _requireSession(account);
    final listing = _box.get(id);
    if (listing == null || listing.ownerAccountId != account.accountId || !listing.isActive) {
      throw const MarketplaceException('Only the owner can remove an active listing.');
    }
    await _box.delete(id);
  }

  void _requireSession(AccountStorage account) {
    if (!AuthService.canUseStorage(account)) {
      throw const MarketplaceException('Unlock your account again to continue.');
    }
  }

  String _nationalPhone(String input) {
    final phone = input.trim().replaceAll(RegExp(r'[ ()-]'), '');
    if (input.trim().isEmpty) return '';
    final match = RegExp(r'^(?:\+92|0)?([0-9]{10})$').firstMatch(phone);
    if (match == null) {
      throw const MarketplaceException('Enter a Pakistani phone number or leave the optional field blank.');
    }
    return match.group(1)!;
  }
}
