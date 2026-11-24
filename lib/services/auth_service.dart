import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/bond_model.dart';
import '../models/check_record_model.dart';
import '../models/notification_model.dart';
import '../models/user_profile_model.dart';
import 'account_credentials.dart';
import 'auth_attempts.dart';

part 'account_storage.dart';

class AccountException implements Exception {
  const AccountException(this.message);

  final String message;
}

class AccountSummary {
  AccountSummary._(UserProfile user)
    : id = user.id,
      email = user.email,
      isApproved = user.isApproved,
      isRejected = user.isRejected;

  final String id;
  final String email;
  final bool isApproved;
  final bool isRejected;
}

class AccountProfile extends AccountSummary {
  AccountProfile._(super.user)
    : fullName = user.fullName,
      mobile = user.mobile,
      address = user.address,
      city = user.city,
      registeredAt = user.registeredAt,
      super._();

  final String fullName;
  final String mobile;
  final String address;
  final String city;
  final DateTime registeredAt;
}

class RegistrationResult {
  const RegistrationResult._(this.account, {required this.selectionSaved});

  final AccountSummary account;
  final bool selectionSaved;
}

class AdminAccess {
  AdminAccess._();

  bool get isOpen => identical(AuthService._admin, this) && AuthService._foreground;

  void close() {
    if (isOpen) AuthService._admin = null;
  }

  void _requireOpen() {
    if (!isOpen) throw const AccountException('Open Admin Access again to continue.');
  }

  List<AccountProfile> get accounts => isOpen ? AuthService._users.values.map(AccountProfile._).toList() : [];

  Future<void> approve(String id) => AuthService._setApproval(this, id, approved: true);

  Future<void> reject(String id) => AuthService._setApproval(this, id, approved: false);

  Future<void> resetPin(String id, String newPin, {bool recover = false}) =>
      AuthService._resetPin(this, id, newPin, recover: recover);
}

class AuthService {
  static const _selectedKey = 'selected_account_id_v2';
  static const _adminVerifier = String.fromEnvironment('FYP_ADMIN_VERIFIER');
  static const _uuid = Uuid();
  static const _notificationPrefs = ['all', 'win', 'draw', 'marketplace'];

  static Future<void> _operations = Future.value();
  static String? _selectedId;
  static AccountStorage? _unlocked;
  static AdminAccess? _admin;
  static AuthAttempts? _attempts;
  static bool _foreground = true;
  static int _epoch = 0;

  static Box<UserProfile> get _users => Hive.box<UserProfile>('users');

  static bool _writingCredential = false;
  static final _storageRevocations = StreamController<AccountStorage>.broadcast(sync: true);

  static Stream<AccountStorage> get storageRevocations => _storageRevocations.stream;

  static Future<void> openAccounts() async {
    await Hive.openBox<UserProfile>(
      'users',
      // Keep Hive 2.2's ordinary compaction thresholds for non-credential writes.
      compactionStrategy: (entries, deleted) => !_writingCredential && deleted > 60 && deleted / entries > 0.15,
    );
  }

  // Credential callers run inside _change, so no other account write can use this strategy concurrently.
  static Future<void> _commitCredential(Object key, UserProfile record) async {
    _writingCredential = true;
    try {
      await _users.put(key, record);
    } finally {
      _writingCredential = false;
    }
  }

  static AccountSummary? get selectedAccount {
    final account = _findById(_selectedId);
    return account == null ? null : AccountSummary._(account);
  }

  static AccountStorage? get unlockedStorage => _unlocked;

  static bool get hasAdminAccess => _admin != null;

  static AccountStorage requireStorage() => _unlocked ?? (throw const AccountException('Unlock your account first.'));

  static bool canUseStorage(AccountStorage storage) => identical(_unlocked, storage);

  static void _requireStorage(AccountStorage storage) {
    if (!canUseStorage(storage)) throw const AccountException('Unlock your account again to continue.');
  }

  static void lockForBackground() {
    _foreground = false;
    _revokeSessions();
  }

  static void resumeFromBackground() => _foreground = true;

  static void _revokeSessions() {
    _epoch++;
    _admin = null;
    _revokeStorage();
  }

  static void _revokeStorage() {
    final previous = _unlocked;
    _unlocked = null;
    if (previous != null) _storageRevocations.add(previous);
  }

  static void _requireForeground(int epoch) {
    if (!_foreground || epoch != _epoch) {
      throw const AccountException('The app was locked. Authenticate again to continue.');
    }
  }

  // Serialize account changes and authentication attempts.
  static Future<T> _change<T>(Future<T> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return next;
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isValidEmail(String email) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());

  static UserProfile? _findByEmail(String email) {
    final normalized = _normalizeEmail(email);
    for (final user in _users.values) {
      if (_normalizeEmail(user.email) == normalized) return user;
    }
    return null;
  }

  static UserProfile? _findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final user in _users.values) {
      if (user.id == id) return user;
    }
    return null;
  }

  static Future<void> restoreSelection() => _change(() async {
    _revokeSessions();
    _selectedId = null;
    _attempts = null;
    // Keep the legacy Hive key so the original account and its profile survive a retry.
    for (final entry in _users.toMap().entries) {
      if (!Uuid.isValidUUID(fromString: entry.value.id)) {
        await _users.put(entry.key, entry.value.copyWith(id: _uuid.v4()));
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final saved = prefs.getString(_selectedKey);
    if (saved != null) {
      _selectedId = _findById(saved)?.id;
      return;
    }

    final legacyEmail = prefs.getString('current_user_email');
    final legacyUser = prefs.getBool('is_logged_in') == true && legacyEmail != null ? _findByEmail(legacyEmail) : null;
    await _saveSelection(legacyUser?.id);
  });

  static Future<void> _saveSelection(String? id, {int? epoch}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != null) _requireForeground(epoch);
      if (!await prefs.setString(_selectedKey, id ?? '')) {
        throw const AccountException('Could not save the account selection.');
      }
    } on AccountException {
      rethrow;
    } catch (_) {
      throw const AccountException('Could not save the account selection.');
    }
    _selectedId = id;
    if (epoch != null) _requireForeground(epoch);
  }

  static Future<AccountSummary?> selectAccount(String email) async {
    _requireForeground(_epoch);
    if (_findByEmail(email) == null) return null;
    _revokeSessions();
    final epoch = _epoch;
    return _change(() async {
      _requireForeground(epoch);
      final account = _findByEmail(email);
      if (account == null) return null;
      await _saveSelection(account.id, epoch: epoch);
      return AccountSummary._(account);
    });
  }

  static Future<RegistrationResult> registerUser({
    required String firstName,
    required String lastName,
    required String mobile,
    required String email,
    required String pin,
    required String address,
    required String city,
  }) {
    final epoch = _epoch;
    return _change(() async {
      _requireForeground(epoch);
      if (!isValidEmail(email)) throw const AccountException('Enter a valid email address.');
      if (_findByEmail(email) != null) {
        throw const AccountException('An account already uses this email. Sign in to continue.');
      }
      _validatePin(pin);
      final id = _uuid.v4();
      final user = UserProfile()
        ..id = id
        ..firstName = firstName.trim()
        ..lastName = lastName.trim()
        ..mobile = mobile.trim()
        ..email = email.trim()
        ..pinHash = await AccountCredentials.create(id, pin)
        ..address = address.trim()
        ..city = city.trim()
        ..role = 'Normal User'
        ..isApproved = false
        ..registeredAt = DateTime.now();
      _requireForeground(epoch);
      await _commitCredential(id, user);
      final account = AccountSummary._(user);
      try {
        _requireForeground(epoch);
        _revokeSessions();
        await _saveSelection(id, epoch: _epoch);
        return RegistrationResult._(account, selectionSaved: true);
      } on AccountException {
        return RegistrationResult._(account, selectionSaved: false);
      }
    });
  }

  static Future<AccountStorage?> unlock(String id, String pin) {
    final epoch = _epoch;
    return _change(() async {
      _requireForeground(epoch);
      final account = _findById(_selectedId);
      if (account == null || account.id != id || !account.isApproved || account.isRejected) {
        throw const AccountException('This account is unavailable. Sign in again or check its approval.');
      }
      final prefs = await SharedPreferences.getInstance();
      return _verify('pin_attempts_$id', epoch, prefs, () async {
        if (!await AccountCredentials.matches(id, account.pinHash, pin)) return null;
        _requireForeground(epoch);
        if (AccountCredentials.isLegacy(account.pinHash)) {
          final updated = account.copyWith(pinHash: await AccountCredentials.create(id, pin));
          _requireForeground(epoch);
          await _commitCredential(account.key as Object, updated);
          final legacyEmail = prefs.getString('user_email');
          if (_foreground &&
              epoch == _epoch &&
              legacyEmail != null &&
              _normalizeEmail(legacyEmail) == _normalizeEmail(account.email) &&
              prefs.getString('user_pin') == account.pinHash) {
            await prefs.remove('user_pin');
          }
        }
        _requireForeground(epoch);
        return AccountStorage._open(id);
      }, (storage) => _unlocked = storage);
    });
  }

  static Future<AdminAccess?> authenticateAdmin(String passphrase) {
    final epoch = _epoch;
    return _change(() async {
      _requireForeground(epoch);
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(_adminVerifier)) {
        throw const AccountException('Admin access needs to be configured for this build.');
      }
      final prefs = await SharedPreferences.getInstance();
      return _verify('local_admin_attempts', epoch, prefs, () async {
        return AccountCredentials.matchesDigest(_adminVerifier, passphrase) ? AdminAccess._() : null;
      }, (access) => _admin = access);
    });
  }

  static Future<AuthAttempts> _getAttempts() async =>
      _attempts ??= AuthAttempts(await Hive.openBox<String>('auth_attempts_v1', crashRecovery: false));

  static Future<T?> _verify<T>(
    String key,
    int epoch,
    SharedPreferences prefs,
    Future<T?> Function() verify,
    void Function(T) publish,
  ) async {
    try {
      final attempts = await _getAttempts();
      _requireForeground(epoch);
      await attempts.reserve(key, prefs);
      _requireForeground(epoch);
      final result = await verify();
      _requireForeground(epoch);
      if (result == null) {
        if (attempts.isLocked(key)) throw const AttemptLockout();
        return null;
      }
      await attempts.clear(key);
      _requireForeground(epoch);
      publish(result);
      return result;
    } on AttemptLockout {
      throw const AccountException('Too many attempts. Wait one minute and try again.');
    } on AttemptPersistenceFailure {
      throw const AccountException('Could not save authentication attempts. Try again when device storage is available.');
    } on HiveError {
      throw const AccountException('Could not access local storage. Try again when device storage is available.');
    }
  }

  static void _validatePin(String pin) {
    if (!AccountCredentials.isPin(pin)) throw const AccountException('Enter exactly four PIN digits.');
  }

  static Future<void> _setApproval(AdminAccess admin, String id, {required bool approved}) => _change(() async {
    admin._requireOpen();
    final account = _findById(id);
    if (account == null || account.isApproved) throw const AccountException('This account is no longer pending review.');
    await _users.put(account.key, account.copyWith(isApproved: approved, isRejected: !approved));
    if (!approved || !admin.isOpen) return;
    try {
      final inbox = await AccountStorage._openInbox(id);
      if (!admin.isOpen) return;
      await inbox.add(
        NotificationModel()
          ..id = _uuid.v4()
          ..typeIndex =
              3 // General notification, using the existing inbox encoding.
          ..title = 'Account Approved'
          ..body = 'Your account has been approved. You can now sign in with your PIN.'
          ..timestamp = DateTime.now()
          ..isRead = false,
      );
    } catch (_) {
      debugPrint('Could not add account approval to the inbox.');
    }
  });

  static Future<void> _resetPin(AdminAccess admin, String id, String newPin, {required bool recover}) => _change(() async {
    admin._requireOpen();
    _validatePin(newPin);
    final account = _findById(id);
    if (account == null || !account.isApproved || account.isRejected) {
      throw const AccountException('Only an approved account can have its PIN reset.');
    }
    try {
      await AccountCredentials.checkCredential(id, account.pinHash);
    } on CredentialException catch (error) {
      if (!recover || !error.canRecover) rethrow;
    }
    admin._requireOpen();
    final updated = account.copyWith(pinHash: await AccountCredentials.create(id, newPin));
    admin._requireOpen();
    if (_unlocked?.accountId == id) _revokeStorage();
    await _commitCredential(account.key as Object, updated);
    if (!admin.isOpen) return;
    try {
      final attempts = await _getAttempts();
      if (admin.isOpen) await attempts.clear('pin_attempts_$id');
    } catch (_) {
      debugPrint('The PIN was reset. Existing retry limits remain in effect.');
    }
  });

  static Future<void> saveUserProfile({
    required AccountStorage storage,
    required String email,
    required String name,
    required String city,
    required String phone,
  }) => _change(() async {
    _requireStorage(storage);
    final account = _findById(storage.accountId);
    if (account == null) throw const AccountException('This account is unavailable.');
    if (!isValidEmail(email)) throw const AccountException('Enter a valid email address.');
    final duplicate = _findByEmail(email);
    if (duplicate != null && duplicate.id != account.id) {
      throw const AccountException('An account already uses this email.');
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.first.isEmpty) throw const AccountException('Enter your name.');
    await _users.put(
      account.key,
      account.copyWith(
        firstName: parts.first,
        lastName: parts.skip(1).join(' '),
        mobile: phone.trim(),
        email: email.trim(),
        city: city.trim(),
      ),
    );
  });

  static AccountProfile profile(AccountStorage storage) {
    _requireStorage(storage);
    final account = _findById(storage.accountId);
    if (account == null) throw const AccountException('This account is unavailable.');
    return AccountProfile._(account);
  }

  static Future<void> setNotifPref(AccountStorage storage, String key, bool value) async {
    _requireStorage(storage);
    final prefs = await SharedPreferences.getInstance();
    _requireStorage(storage);
    if (!_notificationPrefs.contains(key)) throw const AccountException('Unknown notification preference.');
    try {
      if (await prefs.setBool('notif_${storage.accountId}_$key', value)) return;
    } catch (_) {
      // SharedPreferences updates its cache before the write result is known.
    }
    try {
      await prefs.reload();
    } catch (_) {
      throw const AccountException('Could not reload notification preferences after a failed save.');
    }
    throw const AccountException('Could not save the notification preference.');
  }

  static Future<Map<String, bool>> getAllNotifPrefs(AccountStorage storage) async {
    _requireStorage(storage);
    final prefs = await SharedPreferences.getInstance();
    _requireStorage(storage);
    return {for (final key in _notificationPrefs) key: prefs.getBool('notif_${storage.accountId}_$key') ?? key != 'marketplace'};
  }

  static Future<void> logout() {
    _revokeSessions();
    _selectedId = null;
    return _change(() => _saveSelection(null));
  }
}
