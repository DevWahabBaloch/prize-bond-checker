import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/bond_check_result.dart';
import '../widgets/bond_number_extractor.dart';
import '../models/check_record_model.dart';
import 'auth_service.dart';
import 'draw_catalog.dart';
import 'draw_service.dart';
import 'notification_service.dart';

/// Checks the sample catalog and applies side effects to the authenticated account.
class BondCheckingService {
  BondCheckingService({DrawService? draws, DateTime Function()? clock})
    : _draws = draws ?? DrawService(clock: clock),
      _clock = clock ?? DateTime.now;

  final DrawService _draws;
  final DateTime Function() _clock;

  // A retry or another screen must wait for an earlier check's inbox and history writes.
  static Future<void> _writes = Future.value();

  static Future<T> _write<T>(Future<T> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static String _eventKey(String type, List<Object?> data) => '$type:${sha256.convert(utf8.encode(jsonEncode(data)))}';

  Future<BondCheckResult> check(
    AccountStorage account,
    String number,
    String denomination, {
    bool recordHistory = true,
    DrawPeriod? period,
  }) => _write(() => _check(account, number, denomination, recordHistory: recordHistory, period: period));

  Future<BondCheckResult> _check(
    AccountStorage account,
    String number,
    String denomination, {
    required bool recordHistory,
    DrawPeriod? period,
  }) async {
    if (!AuthService.canUseStorage(account)) throw const AccountException('Unlock your account again to continue.');
    final result = _draws.checkBond(number, denomination, period: period);
    final now = _clock();
    final win = result.win;
    final label = result.outcome.label;

    // A check for a narrower period is separate from the saved bond's overall status.
    if (period == null) {
      for (final bond in account.bonds.values.where((bond) => bond.number == number && bond.denomination == denomination)) {
        if (!AuthService.canUseStorage(account)) return result;
        bond.lastChecked = now;
        bond.status = label;
        bond.lastResult = win?.drawNumber;
        await account.bonds.update(bond);
      }
    }
    if (!AuthService.canUseStorage(account)) return result;
    if (recordHistory) {
      final day = drawCalendarDay(now).toIso8601String();
      final historyKey = _eventKey('check', [
        day,
        denomination,
        number,
        label,
        win?.drawId,
        result.coverage.catalogVersion,
        result.coverage.expectedDrawIds,
        result.coverage.checkedDrawIds,
        period?.start.toIso8601String(),
        period?.end.toIso8601String(),
      ]);
      await account.history.addIfAbsent(
        historyKey,
        CheckRecord()
          ..bondNumber = number
          ..denomination = denomination
          ..checkedAt = now
          ..resultStatus = label
          ..drawNumber = win?.drawNumber ?? 'N/A'
          ..drawDate = win?.drawDate ?? 'N/A',
      );
    }

    if (win != null && AuthService.canUseStorage(account)) await _notifyWin(account, result, win);
    return result;
  }

  Future<void> _notifyWin(AccountStorage account, BondCheckResult result, BondWin win) async {
    final prefs = await SharedPreferences.getInstance();
    if (!AuthService.canUseStorage(account)) return;
    final key = 'win_notice_events_${account.accountId}';
    final seen = (prefs.getStringList(key) ?? []).toSet();
    final eventId = _eventKey('win', [win.drawId, result.number]);
    if (!seen.add(eventId)) return;
    await NotificationService().showWinNotification(
      account,
      bondNumber: result.number,
      denomination: result.denomination,
      city: win.city,
      drawNumber: win.drawNumber,
      eventId: eventId,
    );
    if (AuthService.canUseStorage(account) && !await prefs.setStringList(key, seen.toList())) {
      debugPrint('Could not save the win notice receipt.');
    }
  }

  Future<void> refreshAccount(AccountStorage account) => _write(() async {
    if (!AuthService.canUseStorage(account)) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'draw_updates_${account.accountId}';
    final seen = (prefs.getStringList(key) ?? []).toSet();
    var changed = false;
    final notifications = NotificationService();
    for (final draw in _draws.getAll()) {
      if (!AuthService.canUseStorage(account)) return;
      final completed = _draws.statusOf(draw) == DrawStatus.completed;
      final event = jsonEncode([draw.denomination, draw.drawNumber, draw.drawDate, completed]);
      if (seen.contains(event)) continue;
      final eventId = _eventKey('draw-update', [event]);
      if (completed) {
        await notifications.showResultsAvailableNotification(
          account,
          denomination: draw.denomination,
          date: draw.drawDate,
          city: draw.city,
          eventId: eventId,
        );
      } else {
        await notifications.showNewDrawNotification(
          account,
          denomination: draw.denomination,
          date: draw.drawDate,
          city: draw.city,
          eventId: eventId,
        );
      }
      seen.add(event);
      changed = true;
    }
    if (!AuthService.canUseStorage(account)) return;
    if (changed && !await prefs.setStringList(key, seen.toList())) {
      debugPrint('Could not save the draw announcement preferences.');
    }
    await _checkSavedBonds(account);
  });

  Future<void> _checkSavedBonds(AccountStorage account) async {
    final seen = <(String, String)>{};
    for (final bond in account.bonds.values) {
      if (!AuthService.canUseStorage(account)) return;
      if (!seen.add((bond.denomination, bond.number))) continue;
      // Older saved records can contain invalid input. Leave those records as stored.
      if (!BondNumberExtractor.isValidBondNumber(bond.number) || !AppConfig.denominations.contains(bond.denomination)) {
        continue;
      }
      await _check(account, bond.number, bond.denomination, recordHistory: false);
    }
  }
}
