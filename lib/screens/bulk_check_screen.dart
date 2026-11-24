import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/models/bond_check_result.dart';
import 'package:prize_bond_checking_app/services/android_bulk_import.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/bond_checking_service.dart';
import 'package:prize_bond_checking_app/widgets/bond_number_extractor.dart';

class BulkCheckScreen extends StatefulWidget {
  final String denomination;
  final bool restorePendingImport;

  const BulkCheckScreen({super.key, required this.denomination, this.restorePendingImport = false});

  @override
  State<BulkCheckScreen> createState() => _BulkCheckScreenState();
}

class _BulkCheckScreenState extends State<BulkCheckScreen> {
  late final _storage = AuthService.requireStorage();

  static const _maxInputBytes = 256 * 1024;
  static const _maxEntries = 1000;
  static const _sizeError = 'Use at most 256 KiB of TXT, CSV, or pasted input per batch.';

  final TextEditingController _pasteController = TextEditingController();
  final _checking = BondCheckingService();
  bool _isChecking = false;
  bool _isPicking = false;
  String? _fileName;
  String? _fileContent;
  List<_BulkCheckResult> _results = [];
  List<String>? _interruptedTokens;
  StreamSubscription<int>? _pickerEvents;
  int? _androidRequest;
  (int, String)? _appliedReceipt;
  bool _awaitingPicker = false;
  bool _loadingReceipt = false;
  bool _reloadReceipt = false;

  @override
  void initState() {
    super.initState();
    if (!AndroidBulkImport.supported) return;
    _pickerEvents = AndroidBulkImport.instance.changes.listen((request) {
      if (_androidRequest != request) return;
      _awaitingPicker = false;
      unawaited(_restoreAndroidImport());
    });
    if (widget.restorePendingImport) {
      _isPicking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_restoreAndroidImport()));
    }
  }

  @override
  void dispose() {
    unawaited(_pickerEvents?.cancel());
    _pasteController.dispose();
    super.dispose();
  }

  bool get _isActive => mounted && AuthService.canUseStorage(_storage) && (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _pickFile() async {
    if (_isPicking || _isChecking || !_isActive) return;
    if (AndroidBulkImport.supported) {
      await _pickAndroidFile();
      return;
    }
    setState(() => _isPicking = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
        withReadStream: true,
      );
      if (!_isActive || picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final content = await _readFile(file);
      if (_isActive && content != null) {
        setState(() {
          _fileName = file.name;
          _fileContent = content;
        });
      }
    } on FormatException catch (error) {
      if (_isActive) _showInputError(error.message);
    } catch (_) {
      if (_isActive) _showInputError('Could not read the selected file. Choose a local TXT or CSV file and try again.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickAndroidFile() async {
    final paste = _pasteController.text;
    if (paste.length > _maxInputBytes || utf8.encode(paste).length > _maxInputBytes) {
      _showInputError(_sizeError);
      return;
    }
    setState(() => _isPicking = true);
    _awaitingPicker = true;
    try {
      final request = await AndroidBulkImport.instance.open(
        _storage,
        denomination: widget.denomination,
        paste: paste,
        fileName: _fileName,
        fileContent: _fileContent,
      );
      if (!_isActive) return;
      if (request == null) throw StateError('No Android picker request');
      _androidRequest = request;
    } catch (_) {
      if (!_isActive) return;
      _awaitingPicker = false;
      setState(() => _isPicking = false);
      _showInputError('Could not open the file picker. Please try again.');
      return;
    }
    await _restoreAndroidImport();
  }

  Future<void> _restoreAndroidImport() async {
    if (!_isActive) return;
    if (_loadingReceipt) {
      _reloadReceipt = true;
      return;
    }
    _loadingReceipt = true;
    try {
      final receipt = await AndroidBulkImport.instance.load(_storage);
      if (!_isActive) return;
      if (receipt == null) {
        _awaitingPicker = false;
        setState(() => _isPicking = false);
        return;
      }
      if (receipt.status == 'picking' && _awaitingPicker) return;
      final version = (receipt.request, receipt.status);
      if (_appliedReceipt == version) return;
      _appliedReceipt = version;
      _androidRequest = receipt.request;
      _awaitingPicker = false;
      final error = _applyAndroidReceipt(receipt);
      if (error != null) _showInputError(error);
    } catch (_) {
      if (_isActive) {
        _awaitingPicker = false;
        setState(() => _isPicking = false);
        _showInputError('Could not restore the file selection. Please choose the file again.');
      }
    } finally {
      _loadingReceipt = false;
      if (_reloadReceipt) {
        _reloadReceipt = false;
        unawaited(_restoreAndroidImport());
      }
    }
  }

  String? _applyAndroidReceipt(AndroidBulkImportReceipt receipt) {
    var name = receipt.fileName;
    var content = receipt.fileContent;
    var error = switch (receipt.status) {
      'picking' => 'File selection was interrupted. Choose the file again.',
      'failed' => 'Could not read the selected file. Choose a local TXT or CSV file and try again.',
      _ => receipt.error,
    };
    if (receipt.selectedName case final selectedName?) {
      try {
        content = utf8.decode(receipt.selectedBytes!);
        name = selectedName;
      } on FormatException {
        error = 'Use a UTF-8 TXT or CSV file.';
      }
    }
    setState(() {
      _pasteController.text = receipt.paste;
      _fileName = name;
      _fileContent = content;
      _isPicking = false;
    });
    return error;
  }

  Future<void> _clearPendingImport() async {
    if (_androidRequest case final request?) {
      await AndroidBulkImport.instance.clear(_storage, request);
      if (_androidRequest == request) _androidRequest = null;
    }
  }

  Future<void> _discardOnBack() async {
    try {
      if (_androidRequest != null) await _clearPendingImport();
    } catch (error) {
      debugPrint('Could not discard the bulk import (${error.runtimeType}).');
    }
  }

  Future<String?> _readFile(PlatformFile file) async {
    if (file.size > _maxInputBytes) throw const FormatException(_sizeError);
    final stream =
        file.readStream ??
        (file.path != null ? File(file.path!).openRead() : null) ??
        (file.bytes != null ? Stream.value(file.bytes!) : null);
    if (stream == null) throw const FormatException('Could not read the selected file.');

    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (!_isActive) return null;
      if (chunk.length > _maxInputBytes - bytes.length) throw const FormatException(_sizeError);
      bytes.add(chunk);
    }
    try {
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const FormatException('Use a UTF-8 TXT or CSV file.');
    }
  }

  void _showInputError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFFEF4444)));
  }

  List<String> _parseTokens(String content) {
    final tokens = <String>{};
    var entries = 0;

    void addField(int start, int end) {
      var token = content.substring(start, end).trim();
      if (token.isEmpty) return;
      if (++entries > _maxEntries) throw const FormatException('Use at most 1,000 entries per batch.');
      if (token.length == 8 && token.startsWith('"') && token.endsWith('"')) {
        final unquoted = token.substring(1, 7);
        if (BondNumberExtractor.isValidBondNumber(unquoted)) token = unquoted;
      }
      tokens.add(token);
    }

    var start = content.startsWith('\uFEFF') ? 1 : 0;
    var quoted = false;
    for (var index = start; index < content.length; index++) {
      switch (content.codeUnitAt(index)) {
        case 34: // Double quote.
          quoted = !quoted;
        case 44 || 13 || 10: // Comma, CR, LF.
          if (!quoted) {
            addField(start, index);
            start = index + 1;
          }
      }
    }
    addField(start, content.length);
    return tokens.toList();
  }

  Future<void> _checkAll() async {
    if (_isPicking || _isChecking || !_isActive) return;
    final parts = [_fileContent, _pasteController.text].whereType<String>().where((part) => part.isNotEmpty);
    final combined = parts.join('\n');
    final List<String> tokens;
    try {
      if (combined.length > _maxInputBytes || utf8.encode(combined).length > _maxInputBytes) {
        throw const FormatException(_sizeError);
      }
      tokens = _parseTokens(combined);
      if (tokens.isEmpty) throw const FormatException('Pick a file or paste bond numbers first.');
    } on FormatException catch (error) {
      _showInputError(error.message);
      return;
    }

    final resuming = listEquals(_interruptedTokens, tokens);
    final nextResults = resuming ? [..._results] : <_BulkCheckResult>[];
    setState(() {
      _isChecking = true;
      if (!resuming) _results = [];
    });

    try {
      // Only an explicit Check All starts processing. Consume the handoff before
      // applying any results so it cannot be offered again after a restart.
      await _clearPendingImport();
      for (final token in tokens.skip(nextResults.length)) {
        if (!_isActive) return;
        if (!BondNumberExtractor.isValidBondNumber(token)) {
          nextResults.add(_BulkCheckResult(token));
          continue;
        }
        final result = await _checking.check(_storage, token, widget.denomination);
        nextResults.add(_BulkCheckResult(token, result));
      }
      _interruptedTokens = null;
    } catch (_) {
      _interruptedTokens = tokens;
      if (_isActive) {
        _showInputError(
          'Batch stopped after ${nextResults.length} of ${tokens.length} entries. Tap Check All to retry.',
        );
      }
    } finally {
      if (_isActive) {
        setState(() {
          _results = nextResults;
          _isChecking = false;
        });
      }
    }
  }

  int _count(BondCheckOutcome outcome) => _results.where((row) => row.check?.outcome == outcome).length;

  @override
  Widget build(BuildContext context) {
    final headerCount = _results.isEmpty ? 1 : 2;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _androidRequest != null) unawaited(_discardOnBack());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
                itemCount: headerCount + _results.length,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildInputCard();
                  if (index < headerCount) {
                    return Padding(padding: const EdgeInsets.only(top: 20, bottom: 12), child: _buildResultsSummary());
                  }
                  return _buildResultRow(_results[index - headerCount]);
                },
              ),
            ),
          ],
        ),
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
              onPressed: _isChecking || _isPicking ? null : _pickFile,
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
            enabled: !_isChecking && !_isPicking,
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
              onPressed: _isChecking || _isPicking ? null : _checkAll,
              icon: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
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
              '${AppConfig.simulatedResultsLabel}\n'
              '${_count(BondCheckOutcome.win)} wins • ${_count(BondCheckOutcome.noWin)} no win • '
              '${_count(BondCheckOutcome.resultsUnavailable)} unavailable • ${_results.where((row) => row.skipped).length} skipped',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(_BulkCheckResult result) {
    final check = result.check;
    final win = check?.win;
    final isWin = win != null;
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

    final subtitle = switch (check?.outcome) {
      BondCheckOutcome.win => 'Won • ${win!.position} ${win.amount} • Draw #${win.drawNumber}',
      BondCheckOutcome.noWin => 'No Win • ${check!.coverage.summary}',
      BondCheckOutcome.resultsUnavailable => 'Results Unavailable • ${check!.coverage.summary}',
      null => 'Invalid token skipped',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(
            result.skipped ? Icons.error_outline : (isWin ? Icons.emoji_events : Icons.remove_circle_outline),
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.number,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
  const _BulkCheckResult(this.number, [this.check]);

  final String number;
  final BondCheckResult? check;

  bool get skipped => check == null;
}
