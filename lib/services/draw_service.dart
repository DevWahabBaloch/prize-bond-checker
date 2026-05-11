import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/draw_result_model.dart';
import '../models/bond_model.dart';
import 'notification_service.dart';

class DrawService {
  static const _boxName = 'draws';

  Box<DrawResult> get _box => Hive.box<DrawResult>(_boxName);

  Future<void> seedIfEmpty() async {
    if (_box.isNotEmpty) return;
    final jsonStr = await rootBundle.loadString('assets/data/draws_seed.json');
    final List<dynamic> list = json.decode(jsonStr);
    for (final map in list) {
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
          ..totalPrizes = map['totalPrizes'] as String
          ..seededAt = DateTime.now(),
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
      bond.lastChecked = DateTime.now();
      bond.status = result != null ? 'Won' : 'No Win';
      bond.lastResult = result?.drawNumber;
      await bond.save();
      if (result != null) {
        await notifService.showWinNotification(bondNumber: bond.number, denomination: bond.denomination, city: result.city);
      }
    }
  }

  Future<void> markDrawCompleted(String drawNumber) async {
    try {
      final draw = _box.values.firstWhere((d) => d.drawNumber == drawNumber);
      draw.status = 'completed';
      await draw.save();
      await NotificationService().showResultsAvailableNotification(
        denomination: draw.denomination,
        date: draw.drawDate,
        city: draw.city,
      );
    } catch (_) {}
  }

  List<DrawResult> getAll() => _box.values.toList();

  List<DrawResult> getCompleted() => _box.values.where((d) => d.status == 'completed').toList();

  List<DrawResult> getUpcoming() => _box.values.where((d) => d.status == 'upcoming' || d.status == 'today').toList();

  DrawResult? checkBond(String number, String denomination) {
    for (final draw in getCompleted()) {
      if (draw.denomination != denomination) continue;
      if (draw.firstPrize == number) return draw;
      if (draw.secondPrize == number) return draw;
      if (draw.thirdPrize == number) return draw;
    }
    return null;
  }

  String? getPrizePosition(DrawResult draw, String number) {
    if (draw.firstPrize == number) return '1st Prize';
    if (draw.secondPrize == number) return '2nd Prize';
    if (draw.thirdPrize == number) return '3rd Prize';
    return null;
  }

  String? getPrizeAmount(DrawResult draw, String number) {
    if (draw.firstPrize == number) return draw.firstPrizeAmount;
    if (draw.secondPrize == number) return draw.secondPrizeAmount;
    if (draw.thirdPrize == number) return draw.thirdPrizeAmount;
    return null;
  }
}
