import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_file/open_file.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/models/prize_entry_model.dart';
import 'package:prize_bond_checking_app/services/draw_catalog.dart';
import 'package:prize_bond_checking_app/services/draw_report_service.dart';

void main() {
  final service = DrawReportService();
  final catalog = DrawCatalog.parse(
    File('assets/data/draws_seed.json').readAsStringSync(),
    version: DrawCatalog.bundledVersion,
    expectedCount: DrawCatalog.bundledCount,
    expectedDigest: DrawCatalog.bundledDigest,
  );

  test('Each approved draw PDF includes every sample winner, prize tier, and prize amount', () async {
    for (final row in catalog.draws) {
      final draw = row.newRecord(DateTime.utc(2026));
      final pages = _pageContent(await service.buildPdf(draw));
      expect(pages, hasLength(1));
      final page = pages.single;
      _expectSimulationLabel(page);
      expect(draw.prizeWinners, hasLength(10));
      final text = _pdfText(page);
      for (final entry in draw.prizeWinners) {
        expect(text, contains('${entry.position} ${entry.number} ${entry.amount}'), reason: row.id);
      }
    }
  });

  test('A long report paginates, repeats its label, and preserves leading zeroes', () async {
    final draw = _fixture(100);
    final pages = _pageContent(await service.buildPdf(draw));
    expect(pages.length, greaterThan(1));
    for (final page in pages) {
      _expectSimulationLabel(page);
      expect(page, contains('Bond'));
      expect(page, contains('amount'));
    }
    final content = pages.join();
    for (final entry in draw.prizeWinners) {
      expect(RegExp(entry.number).allMatches(content), hasLength(1));
    }
    expect(content, contains('000000'));
    expect(content, contains('000099'));
  });

  test('Save creates a complete file without opening it and opening can fail independently', () async {
    final directory = await Directory.systemTemp.createTemp('draw-pdf-');
    addTearDown(() => directory.delete(recursive: true));
    final attempts = <String>[];
    final reports = DrawReportService(
      documentsDirectory: () async => directory,
      openFile: (path) async {
        attempts.add(path);
        return OpenResult(type: attempts.length == 1 ? ResultType.noAppToOpen : ResultType.done);
      },
    );
    final draw = _fixture(10);
    final file = await reports.save(draw);
    expect(file.path, endsWith('Draw_101_100_2026-11-23.pdf'));
    final saved = await file.readAsBytes();
    expect(_pageContent(saved), hasLength(1));
    expect(attempts, isEmpty);
    expect(await reports.open(file), isFalse);
    expect(await file.readAsBytes(), saved);
    expect(await reports.open(file), isTrue);
    expect(attempts, [file.path, file.path]);
    expect(await directory.list().map((entry) => entry.path).toList(), [file.path]);
  });

  test('A write failure creates no completed file and never calls the opener', () async {
    final directory = await Directory.systemTemp.createTemp('draw-pdf-failure-');
    addTearDown(() => directory.delete(recursive: true));
    final invalidDirectory = await File('${directory.path}/file').create();
    final reports = DrawReportService(
      documentsDirectory: () async => Directory(invalidDirectory.path),
      openFile: (_) async => throw StateError('The opener must be invoked separately.'),
    );
    await expectLater(reports.save(_fixture(10)), throwsA(isA<FileSystemException>()));
    expect(await directory.list().map((entry) => entry.path).toList(), [invalidDirectory.path]);
  });
}

DrawResult _fixture(int count) => DrawResult()
  ..drawNumber = '101'
  ..drawDate = 'November 23, 2026'
  ..denomination = 'Rs. 100'
  ..city = 'Lahore'
  ..prizeWinners = List.generate(
    count,
    (i) => PrizeEntry()
      ..position = '2nd Prize'
      ..number = i.toString().padLeft(6, '0')
      ..amount = 'Rs. 2250',
  );

void _expectSimulationLabel(String page) => expect(_pdfText(page), contains('Simulated FYP Results'));

String _pdfText(String page) =>
    RegExp(r'\(([^()]*)\)').allMatches(page).map((match) => match.group(1)!).join(' ').replaceAll(RegExp(r'\s+'), ' ');

// Read page content streams from the PDFs emitted by the project's locked pdf package.
List<String> _pageContent(List<int> pdf) {
  final raw = latin1.decode(pdf);
  final streams = [
    for (final marker in RegExp(r'\bstream\n').allMatches(raw))
      _decodeStream(pdf, marker.end, raw.substring(raw.lastIndexOf(' obj', marker.start), marker.start)),
  ].where((stream) => stream.contains(' Td ')).toList();
  expect(streams, hasLength(RegExp(r'/Type\s*/Page\b').allMatches(raw).length));
  return streams;
}

String _decodeStream(List<int> pdf, int start, String dictionary) {
  final length = int.parse(RegExp(r'/Length\s+(\d+)').firstMatch(dictionary)!.group(1)!);
  final bytes = pdf.sublist(start, start + length);
  return latin1.decode(dictionary.contains('/FlateDecode') ? zlib.decode(bytes) : bytes);
}
