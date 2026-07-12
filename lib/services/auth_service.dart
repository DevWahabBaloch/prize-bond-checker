import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile_model.dart';

class AuthService {
  static const String _keyLoggedIn = 'is_logged_in';
  static const String _keyCurrentUserEmail = 'current_user_email';

  static const String _legacyKeyApproved = 'is_approved';
  static const String _legacyKeyUserPin = 'user_pin';
  static const String _legacyKeyUserEmail = 'user_email';
  static const String _legacyKeyUserName = 'user_name';
  static const String _legacyKeyUserCity = 'user_city';
  static const String _legacyKeyUserPhone = 'user_phone';
  static const String _legacyKeyUserAddr = 'user_address';
  static const String _legacyKeyUserRole = 'user_role';

  static Box<UserProfile>? get _usersBox => Hive.isBoxOpen('users') ? Hive.box<UserProfile>('users') : null;

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  static List<String> _splitName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return ['User', ''];
    return [parts.first, parts.skip(1).join(' ')];
  }

  static Map<String, String> _profileToMap(UserProfile user) {
    return {
      'email': user.email,
      'name': user.fullName,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'city': user.city,
      'phone': user.mobile,
      'address': user.address,
      'role': user.role,
    };
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, value);
    if (!value) {
      await prefs.remove(_keyCurrentUserEmail);
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    if (!loggedIn) return false;

    final currentEmail = prefs.getString(_keyCurrentUserEmail);
    final box = _usersBox;
    if (box == null) return currentEmail != null || (prefs.getString(_legacyKeyUserEmail) ?? '').isNotEmpty;
    return currentEmail != null && box.containsKey(currentEmail);
  }

  static Future<void> setCurrentUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUserEmail, _normalizeEmail(email));
  }

  static Future<String?> currentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentUserEmail);
  }

  static Future<UserProfile?> currentUser() async {
    final email = await currentUserEmail();
    if (email == null || email.isEmpty) return null;
    return getUserByEmail(email);
  }

  static UserProfile? getUserByEmail(String email) {
    final box = _usersBox;
    if (box == null) return null;
    final normalized = _normalizeEmail(email);
    return box.get(normalized) ??
        box.values.cast<UserProfile?>().firstWhere(
          (user) => user?.email.toLowerCase() == normalized || user?.id.toLowerCase() == normalized,
          orElse: () => null,
        );
  }

  static Future<UserProfile> registerUser({
    required String firstName,
    required String lastName,
    required String mobile,
    required String email,
    required String pin,
    required String address,
    required String city,
    required String role,
  }) async {
    final box = _usersBox;
    if (box == null) {
      throw StateError('Users box must be opened before registration.');
    }

    final normalizedEmail = _normalizeEmail(email);
    final existing = box.get(normalizedEmail);
    final user = existing ?? UserProfile();
    user
      ..id = normalizedEmail
      ..firstName = firstName.trim()
      ..lastName = lastName.trim()
      ..mobile = mobile.trim()
      ..email = email.trim()
      ..pinHash = hashPin(pin.trim())
      ..address = address.trim()
      ..city = city.trim()
      ..role = role
      ..isApproved = false
      ..registeredAt = existing?.registeredAt ?? DateTime.now();

    await box.put(normalizedEmail, user);
    await setCurrentUserEmail(normalizedEmail);
    await setLoggedIn(true);
    return user;
  }

  static Future<void> setApproved(bool value) async {
    final user = await currentUser();
    if (user != null) {
      user.isApproved = value;
      await user.save();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_legacyKeyApproved, value);
  }

  static Future<bool> isApproved() async {
    final user = await currentUser();
    if (user != null) return user.isApproved;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_legacyKeyApproved) ?? false;
  }

  static Future<void> savePin(String pin) async {
    final user = await currentUser();
    if (user != null) {
      user.pinHash = hashPin(pin.trim());
      await user.save();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyKeyUserPin, hashPin(pin.trim()));
  }

  static Future<bool> verifyPin(String pin) async {
    final user = await currentUser();
    if (user != null) {
      return user.pinHash == hashPin(pin.trim());
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_legacyKeyUserPin);
    if (stored == null) return false;
    return stored == hashPin(pin.trim());
  }

  @Deprecated('PIN hashes are stored per UserProfile. Use verifyPin() instead.')
  static Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_legacyKeyUserPin);
  }

  static Future<void> saveUserProfile({
    required String email,
    required String name,
    required String city,
    required String phone,
    required String address,
    required String role,
  }) async {
    final names = _splitName(name);
    final box = _usersBox;
    final current = await currentUser();

    if (box != null && current != null) {
      final normalizedEmail = _normalizeEmail(email);
      final previousKey = current.key;
      final updated = UserProfile()
        ..id = normalizedEmail
        ..firstName = names[0]
        ..lastName = names[1]
        ..mobile = phone.trim()
        ..email = email.trim()
        ..pinHash = current.pinHash
        ..address = address.trim()
        ..city = city.trim()
        ..role = role
        ..isApproved = current.isApproved
        ..registeredAt = current.registeredAt;

      if (previousKey != null && previousKey != normalizedEmail) {
        await box.delete(previousKey);
      }
      await box.put(normalizedEmail, updated);
      await setCurrentUserEmail(normalizedEmail);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyKeyUserEmail, email.trim());
    await prefs.setString(_legacyKeyUserName, name.trim());
    await prefs.setString(_legacyKeyUserCity, city.trim());
    await prefs.setString(_legacyKeyUserPhone, phone.trim());
    await prefs.setString(_legacyKeyUserAddr, address.trim());
    await prefs.setString(_legacyKeyUserRole, role);
  }

  static Future<Map<String, String>> getUserProfile() async {
    final user = await currentUser();
    if (user != null) return _profileToMap(user);

    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_legacyKeyUserEmail) ?? '',
      'name': prefs.getString(_legacyKeyUserName) ?? 'User',
      'firstName': (prefs.getString(_legacyKeyUserName) ?? 'User').split(' ').first,
      'lastName': '',
      'city': prefs.getString(_legacyKeyUserCity) ?? '',
      'phone': prefs.getString(_legacyKeyUserPhone) ?? '',
      'address': prefs.getString(_legacyKeyUserAddr) ?? '',
      'role': prefs.getString(_legacyKeyUserRole) ?? 'Normal User',
    };
  }

  static Future<void> setNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_$key', value);
  }

  static Future<bool> getNotifPref(String key, {bool defaultVal = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_$key') ?? defaultVal;
  }

  static Future<Map<String, bool>> getAllNotifPrefs() async {
    return {
      'all': await getNotifPref('all', defaultVal: true),
      'win': await getNotifPref('win', defaultVal: true),
      'draw': await getNotifPref('draw', defaultVal: true),
      'marketplace': await getNotifPref('marketplace', defaultVal: false),
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, false);
    await prefs.remove(_keyCurrentUserEmail);
  }
}
