import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/draw_result_model.dart';
import '../models/bond_model.dart';
import '../models/prize_entry_model.dart';
import 'notification_service.dart';

class DrawService {
  static const _boxName = 'draws';

  Box<DrawResult> get _box => Hive.box<DrawResult>(_boxName);

  List<PrizeEntry> _parsePrizeWinners(Map<String, dynamic> map) {
    final raw = map['prizeWinners'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (entry) => PrizeEntry()
              ..position = (entry['position'] ?? '').toString()
              ..number = (entry['number'] ?? '').toString()
              ..amount = (entry['amount'] ?? '').toString(),
          )
          .where((entry) => entry.number.isNotEmpty)
          .toList();
    }

    final fallback = <PrizeEntry>[
      PrizeEntry()
        ..position = '1st Prize'
        ..number = (map['firstPrize'] ?? '').toString()
        ..amount = (map['firstPrizeAmount'] ?? '').toString(),
    ];

    final second = map['secondPrize']?.toString();
    if (second != null && second.isNotEmpty) {
      fallback.add(
        PrizeEntry()
          ..position = '2nd Prize'
          ..number = second
          ..amount = (map['secondPrizeAmount'] ?? '').toString(),
      );
    }

    final third = map['thirdPrize']?.toString();
    if (third != null && third.isNotEmpty) {
      fallback.add(
        PrizeEntry()
          ..position = '3rd Prize'
          ..number = third
          ..amount = (map['thirdPrizeAmount'] ?? '').toString(),
      );
    }

    return fallback;
  }

  Future<void> seedIfEmpty() async {
    if (_box.isNotEmpty) return;
    final jsonStr = await rootBundle.loadString('assets/data/draws_seed.json');
    final List<dynamic> list = json.decode(jsonStr);
    for (final rawMap in list) {
      final map = Map<String, dynamic>.from(rawMap as Map);
      final prizeWinners = _parsePrizeWinners(map);
      await _box.add(
        DrawResult()
          ..drawNumber = map['drawNumber'] as String
          ..denomination = map['denomination'] as String
          ..drawDate = map['drawDate'] as String
          ..city = map['city'] as String
          ..status = map['status'] as String
          ..daysLeft = map['daysLeft'] as int
          ..firstPrize = map['firstPrize'] as String
          ..firstPrizeAmount = map['firstPrizeAmount'] as String
          ..secondPrize = map['secondPrize'] as String?
          ..secondPrizeAmount = map['secondPrizeAmount'] as String?
          ..thirdPrize = map['thirdPrize'] as String?
          ..thirdPrizeAmount = map['thirdPrizeAmount'] as String?
          ..totalPrizes = prizeWinners.length.toString()
          ..seededAt = DateTime.now()
          ..prizeWinners = prizeWinners,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyNotified = prefs.getBool('draw_notif_seeded') ?? false;
    if (!alreadyNotified) {
      final upcomingDraws = getUpcoming();
      for (final d in upcomingDraws) {
        await NotificationService().showNewDrawNotification(denomination: d.denomination, date: d.drawDate, city: d.city);
      }

      final completedDraws = getCompleted();
      for (final d in completedDraws) {
        await NotificationService().showResultsAvailableNotification(
          denomination: d.denomination,
          date: d.drawDate,
          city: d.city,
        );
      }
      await prefs.setBool('draw_notif_seeded', true);
    }
  }

  Future<void> autoCheckAllBonds() async {
    if (!Hive.isBoxOpen('bonds')) return;
    final bondsBox = Hive.box<Bond>('bonds');
    if (bondsBox.isEmpty) return;
    final notifService = NotificationService();
    for (final bond in bondsBox.values) {
      final result = checkBond(bond.number, bond.denomination);
      final alreadyNotified = result != null && bond.status == 'Won' && bond.lastResult == result.drawNumber;
      bond.lastChecked = DateTime.now();
      bond.status = result != null ? 'Won' : 'No Win';
      bond.lastResult = result?.drawNumber;
      await bond.save();
      if (result != null && !alreadyNotified) {
        await notifService.showWinNotification(bondNumber: bond.number, denomination: bond.denomination, city: result.city);
      }
    }
  }

  Future<void> updateSavedBondAfterCheck({
    required String number,
    required String denomination,
    required DrawResult? result,
  }) async {
    if (!Hive.isBoxOpen('bonds')) return;
    final bondsBox = Hive.box<Bond>('bonds');
    final matches = bondsBox.values.where((bond) => bond.number == number && bond.denomination == denomination);
    for (final bond in matches) {
      bond.lastChecked = DateTime.now();
      bond.status = result != null ? 'Won' : 'No Win';
      bond.lastResult = result?.drawNumber;
      await bond.save();
    }
  }

  int _daysDelta(DrawResult draw) {
    try {
      final parsed = DateFormat('MMMM d, yyyy').parse(draw.drawDate);
      final drawDay = DateTime(parsed.year, parsed.month, parsed.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return drawDay.difference(today).inDays;
    } catch (_) {
      return draw.daysLeft;
    }
  }

  int daysUntil(DrawResult draw) {
    final days = _daysDelta(draw);
    return days < 0 ? 0 : days;
  }

  Future<List<DrawResult>> recalculateDrawStatuses() async {
    final justCompleted = <DrawResult>[];

    for (final draw in _box.values) {
      if (draw.status == 'completed') continue;

      final remainingDays = _daysDelta(draw);
      final nextStatus = remainingDays < 0
          ? 'completed'
          : remainingDays == 0
          ? 'today'
          : 'upcoming';

      if (draw.status == nextStatus) continue;

      draw.status = nextStatus;
      await draw.save();

      if (nextStatus == 'completed') {
        justCompleted.add(draw);
      }
    }

    for (final draw in justCompleted) {
      await NotificationService().showResultsAvailableNotification(
        denomination: draw.denomination,
        date: draw.drawDate,
        city: draw.city,
      );
    }

    if (justCompleted.isNotEmpty) {
      await autoCheckAllBonds();
    }

    return justCompleted;
  }

  Future<void> markDrawCompleted(String drawNumber) async {
    try {
      final draw = _box.values.firstWhere((d) => d.drawNumber == drawNumber);
      if (draw.status == 'completed') return;
      draw.status = 'completed';
      await draw.save();
      await NotificationService().showResultsAvailableNotification(
        denomination: draw.denomination,
        date: draw.drawDate,
        city: draw.city,
      );
      await autoCheckAllBonds();
    } catch (_) {}
  }

  List<DrawResult> getAll() => _box.values.toList();

  List<DrawResult> getCompleted() => _box.values.where((d) => d.status == 'completed').toList();

  List<DrawResult> getUpcoming() => _box.values.where((d) => d.status == 'upcoming' || d.status == 'today').toList();

  DrawResult? checkBond(String number, String denomination) {
    for (final draw in getCompleted()) {
      if (draw.denomination != denomination) continue;
      if (draw.prizeWinners.any((prize) => prize.number == number)) return draw;
      if (draw.firstPrize == number) return draw;
      if (draw.secondPrize == number) return draw;
      if (draw.thirdPrize == number) return draw;
    }
    return null;
  }

  PrizeEntry? _matchingPrize(DrawResult draw, String number) {
    for (final prize in draw.prizeWinners) {
      if (prize.number == number) return prize;
    }
    return null;
  }

  String? getPrizePosition(DrawResult draw, String number) {
    final prize = _matchingPrize(draw, number);
    if (prize != null) return prize.position;
    if (draw.firstPrize == number) return '1st Prize';
    if (draw.secondPrize == number) return '2nd Prize';
    if (draw.thirdPrize == number) return '3rd Prize';
    return null;
  }

  String? getPrizeAmount(DrawResult draw, String number) {
    final prize = _matchingPrize(draw, number);
    if (prize != null) return prize.amount;
    if (draw.firstPrize == number) return draw.firstPrizeAmount;
    if (draw.secondPrize == number) return draw.secondPrizeAmount;
    if (draw.thirdPrize == number) return draw.thirdPrizeAmount;
    return null;
  }
}
