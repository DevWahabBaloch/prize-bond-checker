import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../config/app_config.dart';
import '../models/bond_check_result.dart';
import '../models/draw_result_model.dart';
import '../widgets/bond_number_extractor.dart';
import 'draw_catalog.dart';

enum DrawStatus { completed, today, upcoming }

class DrawImportReport {
  const DrawImportReport({required this.version, required this.count, required this.inserted, required this.repaired});

  final int version;
  final int count;
  final int inserted;
  final int repaired;
}

class DrawImportFailure implements Exception {
  const DrawImportFailure(this.message);

  final String message;

  @override
  String toString() => 'Draw import failed. $message';
}

class DrawService {
  DrawService({DrawCatalog? catalog, DateTime Function()? clock}) : _catalogOverride = catalog, _clock = clock ?? DateTime.now;

  static const _boxName = 'draws';
  static const _metadataBox = 'draw_import';
  static const _seedKey = 'bundled_seed';
  static DrawCatalog? _bundledCatalog;
  static Future<void> _imports = Future.value();

  final DrawCatalog? _catalogOverride;
  final DateTime Function() _clock;

  DrawCatalog? get _catalog => _catalogOverride ?? _bundledCatalog;
  Box<DrawResult> get _box => Hive.box<DrawResult>(_boxName);

  Future<DrawImportReport> importBundledSeed() async {
    final DrawCatalog catalog;
    try {
      catalog = DrawCatalog.parse(
        await rootBundle.loadString(DrawCatalog.asset),
        version: DrawCatalog.bundledVersion,
        expectedCount: DrawCatalog.bundledCount,
        expectedDigest: DrawCatalog.bundledDigest,
      );
    } on FormatException catch (error) {
      throw DrawImportFailure(error.message);
    } catch (_) {
      throw const DrawImportFailure('Could not read the bundled simulated draw asset.');
    }
    return importCatalog(catalog);
  }

  Future<DrawImportReport> importCatalog(DrawCatalog catalog) {
    final next = _imports.then((_) => _reconcile(catalog));
    _imports = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<DrawImportReport> _reconcile(DrawCatalog catalog) async {
    try {
      final metadata = await Hive.openBox<String>(_metadataBox);
      final previous = metadata.get(_seedKey)?.split(':');
      final previousVersion = previous?.length == 3 ? int.tryParse(previous![1]) : null;
      if (previousVersion != null &&
          (previousVersion > catalog.version || (previousVersion == catalog.version && previous![2] != catalog.digest))) {
        throw const DrawImportFailure('The stored seed version conflicts with the bundled catalog.');
      }

      _bundledCatalog = catalog;
      final byId = _storedById();
      final changes = <Object, DrawResult>{};
      var inserted = 0;
      var repaired = 0;
      for (final expected in catalog.draws) {
        final existing = byId[expected.id] ?? [];
        if (existing.any((entry) => expected.matches(entry.value))) continue;
        if (existing.any((entry) => CatalogDraw.hasCompleteResults(entry.value))) {
          throw DrawImportFailure('An existing complete draw conflicts with the approved catalog (${expected.id}).');
        }
        final key = existing.isEmpty ? expected.id : existing.first.key;
        if (existing.isEmpty && _box.containsKey(key)) {
          throw DrawImportFailure('An unrelated record occupies the catalog key ${expected.id}.');
        }
        changes[key] = expected.newRecord(existing.isEmpty ? _clock() : existing.first.value.seededAt);
        if (existing.isEmpty) {
          inserted++;
        } else {
          repaired++;
        }
      }

      final stamp = '${catalog.version}:${catalog.digest}';
      if (changes.isNotEmpty || metadata.get(_seedKey) != 'complete:$stamp') {
        await metadata.put(_seedKey, 'importing:$stamp');
        await metadata.flush();
        if (changes.isNotEmpty) await _box.putAll(changes);
        await _box.flush();
        if (_availableDraws(catalog).length != catalog.draws.length) {
          throw const DrawImportFailure('The stored catalog is incomplete after import.');
        }
        await metadata.put(_seedKey, 'complete:$stamp');
        await metadata.flush();
      }

      return DrawImportReport(version: catalog.version, count: catalog.draws.length, inserted: inserted, repaired: repaired);
    } on DrawImportFailure {
      rethrow;
    } catch (error) {
      throw DrawImportFailure('Could not save and verify the simulated catalog. $error');
    }
  }

  Map<String, List<MapEntry<Object, DrawResult>>> _storedById() {
    final byId = <String, List<MapEntry<Object, DrawResult>>>{};
    if (!Hive.isBoxOpen(_boxName)) return byId;
    for (final entry in _box.toMap().entries) {
      final id = CatalogDraw.identityOf(entry.value);
      if (id != null) {
        (byId[id] ??= []).add(MapEntry(entry.key as Object, entry.value));
      }
    }
    return byId;
  }

  Map<String, DrawResult> _availableDraws(DrawCatalog catalog) {
    final byId = _storedById();
    return {
      for (final expected in catalog.draws)
        if ((byId[expected.id] ?? []).map((entry) => entry.value).where(expected.matches).firstOrNull case final DrawResult draw)
          expected.id: draw,
    };
  }

  DrawStatus statusOf(DrawResult draw) => _statusOn(CatalogDraw.parseDay(draw.drawDate), drawCalendarDay(_clock()));

  DrawStatus _statusOn(DateTime day, DateTime today) {
    if (day.isBefore(today)) return DrawStatus.completed;
    return day == today ? DrawStatus.today : DrawStatus.upcoming;
  }

  int daysUntil(DrawResult draw) {
    final days = CatalogDraw.parseDay(draw.drawDate).difference(drawCalendarDay(_clock())).inDays;
    return days < 0 ? 0 : days;
  }

  List<DrawResult> getAll() {
    final catalog = _catalog;
    return catalog == null ? [] : _availableDraws(catalog).values.toList();
  }

  List<DrawResult> getCompleted() => getAll().where((draw) => statusOf(draw) == DrawStatus.completed).toList();

  List<DrawResult> getUpcoming() => getAll().where((draw) => statusOf(draw) != DrawStatus.completed).toList();

  BondCheckResult checkBond(String number, String denomination, {DrawPeriod? period}) {
    if (!BondNumberExtractor.isValidBondNumber(number)) throw ArgumentError('A bond number must contain exactly six digits.');
    if (!AppConfig.denominations.contains(denomination)) throw ArgumentError('Unsupported denomination.');

    final catalog = _catalog;
    final today = drawCalendarDay(_clock());
    final expected =
        catalog?.draws.where((draw) {
          if (draw.denomination != denomination) return false;
          // A period filters sample records and includes pending draws among the expected results.
          return period == null ? draw.day.isBefore(today) : period.includes(draw.day);
        }).toList() ??
        [];
    final available = catalog == null ? <String, DrawResult>{} : _availableDraws(catalog);
    final checked = <String>[];
    BondWin? win;
    for (final draw in expected.reversed) {
      final stored = available[draw.id];
      if (stored == null || !draw.day.isBefore(today)) continue;
      checked.add(draw.id);
      final prize = draw.prizeFor(number);
      if (prize != null && win == null) {
        win = BondWin(
          drawId: draw.id,
          drawNumber: stored.drawNumber,
          drawDate: stored.drawDate,
          city: stored.city,
          position: prize.position,
          amount: prize.amount,
        );
      }
    }

    return BondCheckResult(
      number: number,
      denomination: denomination,
      win: win,
      coverage: DrawCoverage(
        catalogVersion: catalog?.version,
        period: period,
        expectedDrawIds: expected.map((draw) => draw.id),
        checkedDrawIds: checked,
      ),
    );
  }
}
