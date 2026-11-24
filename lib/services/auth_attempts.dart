import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttemptLockout implements Exception {
  const AttemptLockout();
}

class AttemptPersistenceFailure implements Exception {
  const AttemptPersistenceFailure();
}

/// AuthService serializes access. Each verification reserves a durable attempt first.
class AuthAttempts {
  AuthAttempts(this._box, {Duration Function()? elapsed, DateTime Function()? now})
    : _elapsed = elapsed ?? _monotonicClock(),
      _now = now ?? DateTime.now;

  static const _limit = 5;
  static const _lockPeriod = Duration(minutes: 1);
  final Box<String> _box;
  final Duration Function() _elapsed;
  final DateTime Function() _now;
  final _deadlines = <String, Duration>{};

  static Duration Function() _monotonicClock() {
    final clock = Stopwatch()..start();
    return () => clock.elapsed;
  }

  Future<void> reserve(String key, SharedPreferences legacy) async {
    var state = _read(key);
    if (!_box.containsKey(key)) {
      state = _legacyState(legacy, key);
      if (state.isLocked) await _persist(key, state);
    }
    if (state.isLocked) {
      final until = _deadlines.putIfAbsent(key, () => _elapsed() + _lockPeriod);
      if (_elapsed() < until) throw const AttemptLockout();
      state = const _AttemptState(0, 0);
    }

    final count = state.count + 1;
    final locked = count == _limit;
    final deadline = locked ? _now().add(_lockPeriod).millisecondsSinceEpoch : 0;
    await _persist(key, _AttemptState(count, deadline));
    if (locked) {
      _deadlines[key] = _elapsed() + _lockPeriod;
    } else {
      _deadlines.remove(key);
    }
  }

  bool isLocked(String key) => _read(key).isLocked;

  Future<void> clear(String key) async {
    // Keep a marker so legacy preferences cannot be imported a second time.
    await _persist(key, const _AttemptState(0, 0));
    _deadlines.remove(key);
  }

  _AttemptState _read(String key) {
    try {
      final encoded = _box.get(key);
      if (encoded == null) return const _AttemptState(0, 0);
      final parts = jsonDecode(encoded);
      if (parts case [
        final int count,
        final int deadline,
      ] when count >= 0 && count <= _limit && (count == _limit ? deadline != 0 : deadline == 0)) {
        return _AttemptState(count, deadline);
      }
    } catch (_) {
      throw const AttemptPersistenceFailure();
    }
    throw const AttemptPersistenceFailure();
  }

  _AttemptState _legacyState(SharedPreferences prefs, String key) {
    try {
      final until = prefs.getInt('${key}_until') ?? 0;
      // Legacy deadlines used wall time only. Honor a recorded lock once on migration.
      if (until != 0) return _AttemptState(_limit, until);
      final count = prefs.getInt(key) ?? 0;
      if (count < 0 || count >= _limit) throw const AttemptPersistenceFailure();
      return _AttemptState(count, 0);
    } catch (_) {
      throw const AttemptPersistenceFailure();
    }
  }

  Future<void> _persist(String key, _AttemptState state) async {
    try {
      await _box.put(key, jsonEncode([state.count, state.wallDeadline]));
      await _box.flush();
    } catch (_) {
      throw const AttemptPersistenceFailure();
    }
  }
}

class _AttemptState {
  const _AttemptState(this.count, this.wallDeadline);

  final int count;
  final int wallDeadline;

  bool get isLocked => wallDeadline != 0;
}
