import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:prize_bond_checking_app/models/bond_check_result.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/models/prize_entry_model.dart';
import 'package:prize_bond_checking_app/services/draw_catalog.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';

const _denomination = 'Rs. 200';
const _otherDenomination = 'Rs. 750';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory data;
  late Box<DrawResult> draws;
  late DrawService service;
  late DateTime now;

  setUp(() async {
    data = await Directory.systemTemp.createTemp('draw-engine-');
    Hive.init(data.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(DrawResultAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(PrizeEntryAdapter());
    draws = await Hive.openBox<DrawResult>('draws');
    now = DateTime(2026, 2, 1);
    service = DrawService(clock: () => now, catalog: _catalog([_row('91', 'January 15, 2026')]));
  });

  tearDown(() async {
    await Hive.close();
    await data.delete(recursive: true);
  });

  test('Approved asset imports all 21 draws and repeat concurrent imports are idempotent', () async {
    final bundled = DrawService(clock: () => now);
    final first = await bundled.importBundledSeed();
    expect(first.version, 1);
    expect(first.inserted, 21);
    expect(first.repaired, 0);
    expect(bundled.getAll(), hasLength(21));
    expect(draws.values.every((draw) => draw.prizeWinners.length == 10), isTrue);
    final originalKeys = draws.keys.toList();

    await Hive.close();
    draws = await Hive.openBox<DrawResult>('draws');
    final reports = await Future.wait([bundled.importBundledSeed(), DrawService().importBundledSeed()]);

    expect(reports.map((report) => report.inserted), [0, 0]);
    expect(draws.keys, originalKeys);
    expect(Hive.box<String>('draw_import').get('bundled_seed'), 'complete:1:${DrawCatalog.bundledDigest}');
    final result = bundled.checkBond('770487', _denomination);
    expect(result.outcome, BondCheckOutcome.win);
    expect(result.win?.position, '1st Prize');
    expect(result.win?.amount, 'Rs. 750,000');
    expect(result.isSimulated, isTrue);
  });

  test('An explicit range filters the approved sample across dates before the catalog and after today', () async {
    now = DateTime(2026, 11, 24);
    final bundled = DrawService(clock: () => now);
    await bundled.importBundledSeed();
    final range = DrawPeriod(DateTime(2025, 12, 31), DateTime(2026, 12, 1));
    final result = bundled.checkBond('001234', _denomination, period: range);
    expect(result.outcome, BondCheckOutcome.noWin);
    expect(result.coverage.expectedDrawIds, hasLength(3));
    expect(result.coverage.checkedDrawIds, unorderedEquals(result.coverage.expectedDrawIds));
    expect(result.coverage.summary, contains('eligible FYP sample draws'));

    final missing = draws.values.singleWhere((draw) => draw.denomination == _denomination && draw.drawNumber == '99');
    await draws.delete(missing.key);
    final incomplete = bundled.checkBond('001234', _denomination, period: range);
    expect(incomplete.outcome, BondCheckOutcome.resultsUnavailable);
    expect(incomplete.coverage.expectedDrawIds, result.coverage.expectedDrawIds);
    expect(incomplete.coverage.checkedDrawIds, hasLength(2));

    final matched = bundled.checkBond('770487', _denomination, period: range);
    expect(matched.outcome, BondCheckOutcome.win);
    expect(matched.win?.drawNumber, '91');
    expect(matched.win?.position, '1st Prize');

    final empty = DrawPeriod(DateTime(2027, 1, 1), DateTime(2027, 1, 31));
    final unavailable = bundled.checkBond('001234', _denomination, period: empty);
    expect(unavailable.outcome, BondCheckOutcome.resultsUnavailable);
    expect(unavailable.coverage.expectedDrawIds, isEmpty);
  });

  test('Interrupted import restarts from the stored draws and preserves legacy keys', () async {
    final catalog = _catalog([_row('91', 'January 15, 2026'), _row('92', 'January 18, 2026')]);
    final legacyDate = DateTime(2025, 12, 20);
    await draws.put(12, catalog.draws.first.newRecord(legacyDate));
    await draws.put(13, catalog.draws.first.newRecord(legacyDate)); // Legacy physical duplicate.
    final extra = catalog.draws.first.newRecord(legacyDate)..drawNumber = '12';
    await draws.put(14, extra); // Unlisted legacy draw.
    Hive.registerAdapter(_FailingDrawAdapter(), override: true);
    await expectLater(service.importCatalog(catalog), throwsA(isA<DrawImportFailure>()));
    expect(Hive.box<String>('draw_import').get('bundled_seed'), startsWith('importing:'));
    expect(draws.keys, [12, 13, 14]);

    await Hive.close();
    Hive.registerAdapter(DrawResultAdapter(), override: true);
    draws = await Hive.openBox<DrawResult>('draws');
    final report = await service.importCatalog(catalog);

    expect(report.count, 2);
    expect(report.inserted, 1);
    expect(report.repaired, 0);
    final reloaded = DrawService(catalog: catalog, clock: () => now);
    expect(reloaded.getAll().map((draw) => draw.drawNumber), ['91', '92']);
    expect(draws.get(12)?.seededAt, legacyDate);
    expect(draws.get(13)?.seededAt, legacyDate);
    expect(draws.get(14)?.drawNumber, '12');

    await draws.delete(catalog.draws.last.id); // Completeness stamp survives the missing row.
    expect((await service.importCatalog(catalog)).inserted, 1);
    expect(reloaded.getAll(), hasLength(2));
  });

  test('Repairs incomplete draws in place and preserves conflicting complete records', () async {
    final catalog = _catalog([_row('91', 'January 15, 2026')]);
    final legacyDate = DateTime(2025, 12, 20);
    await draws.put(12, catalog.draws.single.newRecord(legacyDate)..prizeWinners = []);
    final repaired = await service.importCatalog(catalog);
    expect(repaired.repaired, 1);
    expect(draws.keys, [12]);
    expect(draws.get(12)?.seededAt, legacyDate);
    expect(draws.get(12)?.prizeWinners.single.number, '001234');

    await draws.put(12, catalog.draws.single.newRecord(legacyDate)..city = 'Different city');
    await expectLater(service.importCatalog(catalog), throwsA(isA<DrawImportFailure>()));
    expect(draws.get(12)?.city, 'Different city');
    expect(service.checkBond('001234', _denomination).outcome, BondCheckOutcome.resultsUnavailable);
  });

  test('Rejects a different catalog claiming the same seed version', () async {
    final catalog = _catalog([_row('91', 'January 15, 2026')]);
    await service.importCatalog(catalog);
    await expectLater(
      service.importCatalog(_catalog([_row('91', 'January 15, 2026', winner: '001235')])),
      throwsA(isA<DrawImportFailure>()),
    );
    expect(draws.values.single.firstPrize, '001234');
  });

  test('Rejects malformed or incomplete seed data before storage writes', () {
    for (final invalid in [
      _row('91', 'February 30, 2026'),
      _row('91', 'January 15, 2026', denomination: 'Rs. 50'),
      _row('91', 'January 15, 2026', winner: '1234'),
      _row('91', 'January 15, 2026')..remove('city'),
      _row('91', 'January 15, 2026')..['totalPrizes'] = '2',
      _row('91', 'January 15, 2026')
        ..['prizeWinners'] = [
          {'number': 123456, 'position': '1st Prize', 'amount': 'Rs. 100'},
        ],
      _row('91', 'January 15, 2026')..['firstPrizeAmount'] = 'Rs. 1',
    ]) {
      expect(() => _catalog([invalid]), throwsFormatException);
    }
    final row = _row('91', 'January 15, 2026');
    expect(() => _catalog([row, row]), throwsFormatException);
    expect(() => DrawCatalog.parse(jsonEncode([row]), version: 1, expectedCount: 2), throwsFormatException);
    expect(
      () => DrawCatalog.parse(jsonEncode([row]), version: 1, expectedCount: 1, expectedDigest: 'wrong'),
      throwsFormatException,
    );
    expect(draws, isEmpty);
    expect(Hive.isBoxOpen('draw_import'), isFalse);
  });

  test('Duplicate identical prize entries are harmless and conflicting prizes are rejected', () async {
    final row = _row('91', 'January 15, 2026');
    final prizes = row['prizeWinners'] as List<Map<String, String>>;
    prizes.add({...prizes.single});
    final catalog = _catalog([row]);
    await service.importCatalog(catalog);
    expect(draws.values.single.prizeWinners, hasLength(1));
    expect(service.checkBond('001234', _denomination).outcome, BondCheckOutcome.win);
    prizes.add({...prizes.first, 'amount': 'Rs. 5'});
    expect(() => _catalog([row]), throwsFormatException);
  });

  test('Matches six digits literally and only checks the selected denomination', () async {
    final catalog = _catalog([
      _row('91', 'January 15, 2026'),
      _row('92', 'January 17, 2026', denomination: _otherDenomination, winner: '101234'),
    ]);
    final checking = DrawService(catalog: catalog, clock: () => now);
    await checking.importCatalog(catalog);
    final range = DrawPeriod(DateTime(2026, 1, 15), DateTime(2026, 1, 17));

    expect(checking.checkBond('001234', _denomination).outcome, BondCheckOutcome.win);
    expect(checking.checkBond('001234', _denomination, period: range).outcome, BondCheckOutcome.win);
    expect(checking.checkBond('101234', _denomination).outcome, BondCheckOutcome.noWin);
    expect(checking.checkBond('001234', _otherDenomination).outcome, BondCheckOutcome.noWin);
    expect(checking.checkBond('101234', _otherDenomination).outcome, BondCheckOutcome.win);
    expect(checking.checkBond('001234', 'Rs. 100').outcome, BondCheckOutcome.resultsUnavailable);
    expect(() => checking.checkBond('1234', _denomination), throwsArgumentError);
  });

  test('Missing or incomplete rows prevent No Win but do not hide a verified match', () async {
    final catalog = _catalog([_row('91', 'January 15, 2026'), _row('92', 'January 18, 2026', winner: '002345')]);
    final checking = DrawService(catalog: catalog, clock: () => now);
    expect(checking.checkBond('000002', _denomination).outcome, BondCheckOutcome.resultsUnavailable);
    await checking.importCatalog(catalog);
    expect(checking.checkBond('000002', _denomination).outcome, BondCheckOutcome.noWin);

    await draws.put(catalog.draws.last.id, catalog.draws.last.newRecord(now)..prizeWinners = []);
    final unknown = checking.checkBond('002345', _denomination);
    expect(unknown.outcome, BondCheckOutcome.resultsUnavailable);
    expect(unknown.coverage.expectedDrawIds, hasLength(2));
    expect(unknown.coverage.checkedDrawIds, [catalog.draws.first.id]);
    expect(checking.checkBond('001234', _denomination).outcome, BondCheckOutcome.win);

    await draws.delete(catalog.draws.first.id);
    expect(checking.checkBond('001234', _denomination).outcome, BondCheckOutcome.resultsUnavailable);
  });

  test('Draw-day and future results remain ineligible despite stored Completed status', () async {
    final catalog = _catalog([_row('91', 'January 15, 2026'), _row('92', 'January 18, 2026', winner: '002345')]);
    final checking = DrawService(catalog: catalog, clock: () => now);
    await checking.importCatalog(catalog);
    final pending = DrawPeriod(DateTime(2026, 1, 15), DateTime(2026, 1, 18));
    final futureOnly = DrawPeriod(DateTime(2026, 1, 18), DateTime(2026, 1, 31));
    final gap = DrawPeriod(DateTime(2026, 1, 16), DateTime(2026, 1, 17));

    now = DateTime(2026, 1, 15, 23, 59);
    expect(checking.checkBond('001234', _denomination).outcome, BondCheckOutcome.resultsUnavailable);
    expect(checking.getCompleted(), isEmpty);
    expect(checking.getUpcoming(), hasLength(2));

    now = DateTime(2026, 1, 16);
    expect(checking.checkBond('001234', _denomination).outcome, BondCheckOutcome.win);
    expect(checking.checkBond('002345', _denomination).outcome, BondCheckOutcome.noWin);
    expect(checking.checkBond('002345', _denomination, period: pending).outcome, BondCheckOutcome.resultsUnavailable);
    expect(checking.checkBond('000002', _denomination, period: pending).outcome, BondCheckOutcome.resultsUnavailable);
    final onlyPending = checking.checkBond('002345', _denomination, period: futureOnly);
    expect(onlyPending.outcome, BondCheckOutcome.resultsUnavailable);
    expect(onlyPending.coverage.expectedDrawIds, [catalog.draws.last.id]);
    expect(onlyPending.coverage.checkedDrawIds, isEmpty);
    expect(checking.checkBond('000002', _denomination, period: gap).outcome, BondCheckOutcome.resultsUnavailable);

    now = DateTime(2026, 1, 19);
    expect(checking.checkBond('002345', _denomination, period: pending).outcome, BondCheckOutcome.win);
    expect(checking.checkBond('000002', _denomination, period: pending).outcome, BondCheckOutcome.noWin);
    expect(checking.checkBond('000002', _denomination, period: futureOnly).outcome, BondCheckOutcome.noWin);
  });
}

Map<String, Object> _row(String drawNumber, String date, {String denomination = _denomination, String winner = '001234'}) => {
  'drawNumber': drawNumber,
  'denomination': denomination,
  'drawDate': date,
  'city': 'Hyderabad',
  'status': 'completed',
  'daysLeft': 0,
  'firstPrize': winner,
  'firstPrizeAmount': 'Rs. 100',
  'totalPrizes': '1',
  'prizeWinners': [
    {'number': winner, 'position': '1st Prize', 'amount': 'Rs. 100'},
  ],
};

DrawCatalog _catalog(List<Map<String, Object>> rows) =>
    DrawCatalog.parse(jsonEncode(rows), version: 1, expectedCount: rows.length);

class _FailingDrawAdapter extends DrawResultAdapter {
  @override
  void write(BinaryWriter writer, DrawResult obj) => throw const FileSystemException('Injected interrupted draw write');
}
