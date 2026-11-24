import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../models/draw_result_model.dart';
import 'draw_catalog.dart';

class DrawReportService {
  const DrawReportService({this.documentsDirectory = getApplicationDocumentsDirectory, this.openFile = OpenFile.open});

  final Future<Directory> Function() documentsDirectory;
  final Future<OpenResult> Function(String) openFile;

  Future<File> save(DrawResult draw) async {
    final date = CatalogDraw.parseDay(draw.drawDate).toIso8601String().substring(0, 10);
    final denomination = draw.denomination.replaceAll(RegExp(r'[^0-9]'), '');
    final number = draw.drawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final directory = await documentsDirectory();
    final file = File('${directory.path}/Draw_${number}_${denomination}_$date.pdf');
    final pending = File('${file.path}.${const Uuid().v4()}.part');
    try {
      await pending.writeAsBytes(await buildPdf(draw), flush: true);
      return await pending.rename(file.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  Future<bool> open(File file) async => (await openFile(file.path)).type == ResultType.done;

  Future<Uint8List> buildPdf(DrawResult draw) {
    final pdf = pw.Document(title: 'Simulated FYP Results - Draw ${draw.drawNumber}');
    final blue = PdfColor.fromHex('#2D5BFF');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Simulated FYP Results',
                style: pw.TextStyle(color: blue, fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Draw #${draw.drawNumber}  |  ${draw.denomination}  |  ${draw.drawDate}  |  ${draw.city}'),
              pw.SizedBox(height: 4),
              pw.Text('Professor-approved sample data. For demonstration only.'),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ),
        build: (_) => [
          pw.Text('Sample winner entries: ${draw.prizeWinners.length}'),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            data: [
              ['Prize', 'Bond number', 'Prize amount'],
              for (final winner in draw.prizeWinners) [winner.position, winner.number, winner.amount],
            ],
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
