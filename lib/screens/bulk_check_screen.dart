import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:prize_bond_checking_app/widgets/bond_number_extractor.dart';

class BulkCheckScreen extends StatefulWidget {
  final String denomination;

  const BulkCheckScreen({super.key, required this.denomination});

  @override
  State<BulkCheckScreen> createState() => _BulkCheckScreenState();
}

class _BulkCheckScreenState extends State<BulkCheckScreen> {
  final TextEditingController _pasteController = TextEditingController();
  final DrawService _drawService = DrawService();
  bool _isChecking = false;
  String? _fileName;
  String? _fileContent;
  List<_BulkCheckResult> _results = [];

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'csv'], withData: true);
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    String content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to read selected file'), backgroundColor: Color(0xFFEF4444)));
      return;
    }

    setState(() {
      _fileName = file.name;
      _fileContent = content;
    });
  }

  List<String> _parseTokens(String content) {
    return content.split(RegExp(r'[\r\n,]+')).map((token) => token.trim()).where((token) => token.isNotEmpty).toList();
  }

  Future<void> _checkAll() async {
    final combined = [_fileContent, _pasteController.text].whereType<String>().where((part) => part.trim().isNotEmpty).join('\n');
    final tokens = _parseTokens(combined);

    if (tokens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a file or paste bond numbers first'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    setState(() {
      _isChecking = true;
      _results = [];
    });

    final nextResults = <_BulkCheckResult>[];
    for (final token in tokens) {
      if (!BondNumberExtractor.isValidBondNumber(token)) {
        nextResults.add(_BulkCheckResult.invalid(token));
        continue;
      }

      final draw = _drawService.checkBond(token, widget.denomination);
      await _drawService.updateSavedBondAfterCheck(number: token, denomination: widget.denomination, result: draw);

      final record = CheckRecord()
        ..bondNumber = token
        ..denomination = widget.denomination
        ..checkedAt = DateTime.now()
        ..resultStatus = draw != null ? 'Won' : 'No Win'
        ..drawNumber = draw?.drawNumber ?? 'N/A'
        ..drawDate = draw?.drawDate ?? 'N/A';
      await Hive.box<CheckRecord>('check_history').add(record);

      if (draw != null) {
        await NotificationService().showWinNotification(bondNumber: token, denomination: widget.denomination, city: draw.city);
      }

      nextResults.add(_BulkCheckResult.checked(token, draw));
    }

    if (!mounted) return;
    setState(() {
      _results = nextResults;
      _isChecking = false;
    });
  }

  int get _validCount => _results.where((result) => !result.skipped).length;
  int get _winCount => _results.where((result) => result.draw != null).length;
  int get _skippedCount => _results.where((result) => result.skipped).length;
  int get _noWinCount => _validCount - _winCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInputCard(),
                const SizedBox(height: 20),
                if (_results.isNotEmpty) _buildResultsSummary(),
                if (_results.isNotEmpty) const SizedBox(height: 12),
                ..._results.map(_buildResultRow),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Bond List',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.denomination, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batch Input',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isChecking ? null : _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_fileName == null ? 'Pick TXT or CSV File' : _fileName!),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D5BFF),
                side: const BorderSide(color: Color(0xFF2D5BFF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pasteController,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: 'Paste numbers separated by new lines or commas',
              prefixIcon: const Icon(Icons.content_paste, color: Color(0xFF2D5BFF)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isChecking ? null : _checkAll,
              icon: _isChecking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.checklist_rtl),
              label: Text(_isChecking ? 'Checking...' : 'Check All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_outlined, color: Color(0xFF2D5BFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_validCount checked - $_winCount wins - $_noWinCount no win - $_skippedCount skipped',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(_BulkCheckResult result) {
    final isWin = result.draw != null;
    final color = result.skipped
        ? const Color(0xFFEF4444)
        : isWin
        ? const Color(0xFF059669)
        : const Color(0xFF6B7280);
    final bg = result.skipped
        ? const Color(0xFFFEF2F2)
        : isWin
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFF3F4F6);

    String subtitle;
    if (result.skipped) {
      subtitle = 'Invalid token skipped';
    } else if (result.draw != null) {
      final position = _drawService.getPrizePosition(result.draw!, result.number) ?? 'Prize';
      final amount = _drawService.getPrizeAmount(result.draw!, result.number) ?? '';
      subtitle = '$position $amount - Draw #${result.draw!.drawNumber}';
    } else {
      subtitle = 'No match in completed draws';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(result.skipped ? Icons.error_outline : (isWin ? Icons.emoji_events : Icons.remove_circle_outline), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.number,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: color),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkCheckResult {
  final String number;
  final DrawResult? draw;
  final bool skipped;

  const _BulkCheckResult._({required this.number, required this.draw, required this.skipped});

  factory _BulkCheckResult.checked(String number, DrawResult? draw) {
    return _BulkCheckResult._(number: number, draw: draw, skipped: false);
  }

  factory _BulkCheckResult.invalid(String token) {
    return _BulkCheckResult._(number: token, draw: null, skipped: true);
  }
}
