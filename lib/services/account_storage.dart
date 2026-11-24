part of 'auth_service.dart';

class AccountStorage {
  AccountStorage._(this.accountId, Box<Bond> bondBox, Box<CheckRecord> historyBox, Box<NotificationModel> inbox) {
    bonds = PrivateRecords._(this, bondBox, _copyBond);
    history = PrivateRecords._(this, historyBox, _copyCheck);
    notifications = PrivateRecords._(this, inbox, _copyNotification);
  }

  final String accountId;
  late final PrivateRecords<Bond> bonds;
  late final PrivateRecords<CheckRecord> history;
  late final PrivateRecords<NotificationModel> notifications;

  static Future<AccountStorage> _open(String accountId) async {
    if (!Uuid.isValidUUID(fromString: accountId)) {
      throw const AccountException('The account must have a valid ID.');
    }
    return AccountStorage._(
      accountId,
      await Hive.openBox<Bond>('bonds_$accountId'),
      await Hive.openBox<CheckRecord>('check_history_$accountId'),
      await _openInbox(accountId),
    );
  }

  static Future<Box<NotificationModel>> _openInbox(String id) => Hive.openBox<NotificationModel>('notifications_$id');

  static Bond _copyBond(Bond bond) => Bond()
    ..id = bond.id
    ..number = bond.number
    ..denomination = bond.denomination
    ..status = bond.status
    ..addedDate = bond.addedDate
    ..lastChecked = bond.lastChecked
    ..lastResult = bond.lastResult
    ..issueDate = bond.issueDate
    ..issueCity = bond.issueCity;

  static CheckRecord _copyCheck(CheckRecord record) => CheckRecord()
    ..bondNumber = record.bondNumber
    ..denomination = record.denomination
    ..checkedAt = record.checkedAt
    ..resultStatus = record.resultStatus
    ..drawNumber = record.drawNumber
    ..drawDate = record.drawDate;

  static NotificationModel _copyNotification(NotificationModel notification) => NotificationModel()
    ..id = notification.id
    ..typeIndex = notification.typeIndex
    ..title = notification.title
    ..body = notification.body
    ..timestamp = notification.timestamp
    ..isRead = notification.isRead;
}

/// A scoped view of a Hive box. Stored HiveObjects never leave the service.
class PrivateRecords<T extends HiveObject> implements ValueListenable<PrivateRecords<T>> {
  PrivateRecords._(this._account, this._box, this._copy) : _changes = _box.listenable();

  final AccountStorage _account;
  final Box<T> _box;
  final T Function(T) _copy;
  final Listenable _changes;
  final _keys = Expando<Object>();

  bool get _active => AuthService.canUseStorage(_account);
  int get length => _active ? _box.length : 0;
  bool get isEmpty => length == 0;

  List<T> get values {
    if (!_active) return [];
    return _box.values.map((record) {
      final copy = _copy(record);
      _keys[copy] = record.key as Object;
      return copy;
    }).toList();
  }

  @override
  PrivateRecords<T> get value => this;

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _changes.removeListener(listener);

  // A write submitted while active may finish on this box. Every new write rechecks the session.
  Future<void> add(T record) async {
    AuthService._requireStorage(_account);
    await _box.add(_copy(record));
  }

  // Callers serialize event writes before using a stable key.
  Future<bool> addIfAbsent(String key, T record) async {
    AuthService._requireStorage(_account);
    if (_box.containsKey(key)) return false;
    await _box.put(key, _copy(record));
    return true;
  }

  Future<void> update(T record) async {
    AuthService._requireStorage(_account);
    final key = _keys[record];
    if (key != null && _box.containsKey(key)) await _box.put(key, _copy(record));
  }

  Future<void> delete(T record) async {
    AuthService._requireStorage(_account);
    final key = _keys[record];
    if (key != null) await _box.delete(key);
  }

  Future<void> deleteWhere(bool Function(T) matches) async {
    final records = values.where(matches).toList();
    AuthService._requireStorage(_account);
    await _box.deleteAll(records.map((record) => _keys[record]!));
  }

  Future<void> clear() async {
    AuthService._requireStorage(_account);
    await _box.clear();
  }
}
