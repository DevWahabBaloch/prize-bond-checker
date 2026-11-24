import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/draw_result_model.dart';
import '../models/prize_entry_model.dart';
import '../widgets/bond_number_extractor.dart';

/// A complete, validated manifest of the simulated draws supplied by this app version.
class DrawCatalog {
  DrawCatalog._(this.version, this.digest, Iterable<CatalogDraw> draws)
    : draws = List.unmodifiable(draws.toList()..sort((a, b) => a.day.compareTo(b.day)));

  static const asset = 'assets/data/draws_seed.json';
  static const bundledVersion = 1;
  static const bundledCount = 21;
  static const bundledDigest = '864bb5f35b3a3c43b9253092ca93fe9d9dd0668ca13123b59952c75679d47578';

  final int version;
  final String digest;
  final List<CatalogDraw> draws;

  factory DrawCatalog.parse(String json, {required int version, required int expectedCount, String? expectedDigest}) {
    final digest = sha256.convert(utf8.encode(json)).toString();
    if (expectedDigest != null && digest != expectedDigest) {
      throw const FormatException('The simulated draw asset does not match its approved version.');
    }
    final rows = jsonDecode(json);
    if (version < 1 || expectedCount < 1 || rows is! List || rows.length != expectedCount) {
      throw const FormatException('The simulated catalog has an unexpected number of draws.');
    }

    final draws = <String, CatalogDraw>{};
    for (final (index, row) in rows.indexed) {
      try {
        if (row is! Map<String, dynamic>) throw const FormatException('Expected a draw object.');
        final draw = CatalogDraw._parse(row);
        if (draws.containsKey(draw.id)) throw const FormatException('Duplicate draw identity.');
        draws[draw.id] = draw;
      } on FormatException catch (error) {
        throw FormatException('Draw row ${index + 1}: ${error.message}');
      }
    }
    return DrawCatalog._(version, digest, draws.values);
  }
}

DateTime drawCalendarDay(DateTime date) => DateTime.utc(date.year, date.month, date.day);

class CatalogDraw {
  CatalogDraw._(this.id, this.day, this._record, this._prizes);

  static final _dateFormat = DateFormat('MMMM d, yyyy', 'en_US');
  static final _drawNumberPattern = RegExp(r'^\d+$');

  final String id;
  final DateTime day;
  final DrawResult _record;
  final Map<String, PrizeEntry> _prizes;

  String get denomination => _record.denomination;

  static DateTime parseDay(String date) => _dateFormat.parseStrict(date, true);

  static String identity(String denomination, String drawNumber, DateTime day) =>
      'draw|$denomination|$drawNumber|${day.toIso8601String().substring(0, 10)}';

  static String? identityOf(DrawResult draw) {
    try {
      return identity(draw.denomination, draw.drawNumber, parseDay(draw.drawDate));
    } on FormatException {
      return null;
    }
  }

  factory CatalogDraw._parse(Map<String, dynamic> row) {
    String requiredText(String key) {
      final value = row[key];
      if (value is! String || value.trim().isEmpty) throw FormatException('Missing or invalid $key.');
      return value;
    }

    final drawNumber = requiredText('drawNumber');
    if (!_drawNumberPattern.hasMatch(drawNumber) || (int.tryParse(drawNumber) ?? 0) <= 0) {
      throw const FormatException('Invalid draw number.');
    }
    final denomination = requiredText('denomination');
    if (!AppConfig.denominations.contains(denomination)) throw const FormatException('Unsupported denomination.');
    final date = requiredText('drawDate');
    final day = parseDay(date);
    if (_dateFormat.format(day) != date) throw const FormatException('Use the catalog date format.');
    final status = requiredText('status');
    if (!const {'completed', 'today', 'upcoming'}.contains(status) || row['daysLeft'] is! int) {
      throw const FormatException('Invalid draw status or days left.');
    }
    final rawPrizes = row['prizeWinners'];
    if (rawPrizes is! List) throw const FormatException('Missing prize list.');
    final prizes = _validatedPrizes(
      rawPrizes.map((raw) {
        if (raw is! Map<String, dynamic> || raw['number'] is! String || raw['position'] is! String || raw['amount'] is! String) {
          throw const FormatException('Invalid prize entry.');
        }
        return PrizeEntry()
          ..number = raw['number'] as String
          ..position = raw['position'] as String
          ..amount = raw['amount'] as String;
      }),
      requiredText('totalPrizes'),
    );

    final draw = DrawResult()
      ..drawNumber = drawNumber
      ..denomination = denomination
      ..drawDate = date
      ..city = requiredText('city')
      ..status = status
      ..daysLeft = row['daysLeft'] as int
      ..firstPrize = requiredText('firstPrize')
      ..firstPrizeAmount = requiredText('firstPrizeAmount')
      ..secondPrize = _optionalText(row, 'secondPrize')
      ..secondPrizeAmount = _optionalText(row, 'secondPrizeAmount')
      ..thirdPrize = _optionalText(row, 'thirdPrize')
      ..thirdPrizeAmount = _optionalText(row, 'thirdPrizeAmount')
      ..totalPrizes = requiredText('totalPrizes')
      ..prizeWinners = prizes.values.toList();
    _validateTopPrizes(draw, prizes);
    return CatalogDraw._(identity(denomination, drawNumber, day), day, draw, prizes);
  }

  static String? _optionalText(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) throw FormatException('Invalid $key.');
    return value;
  }

  static Map<String, PrizeEntry> _validatedPrizes(Iterable<PrizeEntry> list, String total) {
    final prizes = <String, PrizeEntry>{};
    for (final prize in list) {
      if (!BondNumberExtractor.isValidBondNumber(prize.number) || prize.position.trim().isEmpty || prize.amount.trim().isEmpty) {
        throw const FormatException('A prize requires a six-digit number, position, and amount.');
      }
      final duplicate = prizes[prize.number];
      if (duplicate != null && (duplicate.position != prize.position || duplicate.amount != prize.amount)) {
        throw const FormatException('A winning number has conflicting prize entries.');
      }
      prizes[prize.number] = prize;
    }
    if (prizes.isEmpty || int.tryParse(total) != prizes.length) {
      throw const FormatException('The prize list does not contain the declared number of distinct winners.');
    }
    return prizes;
  }

  static void _validateTopPrizes(DrawResult draw, Map<String, PrizeEntry> prizes) {
    for (final (number, amount, position) in [
      (draw.firstPrize, draw.firstPrizeAmount, '1st Prize'),
      (draw.secondPrize, draw.secondPrizeAmount, '2nd Prize'),
      (draw.thirdPrize, draw.thirdPrizeAmount, '3rd Prize'),
    ]) {
      if (number == null && amount == null) continue;
      final prize = prizes[number];
      if (prize == null || prize.position != position || prize.amount != amount) {
        throw FormatException('$position summary does not match the winner list.');
      }
    }
  }

  static bool hasCompleteResults(DrawResult draw) {
    try {
      if (draw.city.trim().isEmpty) return false;
      final prizes = _validatedPrizes(draw.prizeWinners, draw.totalPrizes);
      _validateTopPrizes(draw, prizes);
      return true;
    } on FormatException {
      return false;
    }
  }

  bool matches(DrawResult draw) {
    if (draw.city != _record.city ||
        draw.firstPrize != _record.firstPrize ||
        draw.firstPrizeAmount != _record.firstPrizeAmount ||
        draw.secondPrize != _record.secondPrize ||
        draw.secondPrizeAmount != _record.secondPrizeAmount ||
        draw.thirdPrize != _record.thirdPrize ||
        draw.thirdPrizeAmount != _record.thirdPrizeAmount) {
      return false;
    }
    try {
      final prizes = _validatedPrizes(draw.prizeWinners, draw.totalPrizes);
      return prizes.length == _prizes.length &&
          prizes.values.every((prize) {
            final expected = _prizes[prize.number];
            return expected?.position == prize.position && expected?.amount == prize.amount;
          });
    } on FormatException {
      return false;
    }
  }

  ({String position, String amount})? prizeFor(String number) {
    final prize = _prizes[number];
    return prize == null ? null : (position: prize.position, amount: prize.amount);
  }

  DrawResult newRecord(DateTime seedTime) => DrawResult()
    ..drawNumber = _record.drawNumber
    ..denomination = _record.denomination
    ..drawDate = _record.drawDate
    ..city = _record.city
    ..status = _record.status
    ..daysLeft = _record.daysLeft
    ..firstPrize = _record.firstPrize
    ..firstPrizeAmount = _record.firstPrizeAmount
    ..secondPrize = _record.secondPrize
    ..secondPrizeAmount = _record.secondPrizeAmount
    ..thirdPrize = _record.thirdPrize
    ..thirdPrizeAmount = _record.thirdPrizeAmount
    ..totalPrizes = _record.totalPrizes
    ..seededAt = seedTime
    ..prizeWinners = [
      for (final prize in _prizes.values)
        PrizeEntry()
          ..number = prize.number
          ..position = prize.position
          ..amount = prize.amount,
    ];
}
