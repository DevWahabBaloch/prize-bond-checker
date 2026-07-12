import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/screens/bulk_check_screen.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';
import 'package:prize_bond_checking_app/widgets/bond_number_extractor.dart';

class CheckBondScreen extends StatefulWidget {
  final String? initialBondNumber;

  const CheckBondScreen({super.key, this.initialBondNumber});

  @override
  State<CheckBondScreen> createState() => _CheckBondScreenState();
}

class _CheckBondScreenState extends State<CheckBondScreen> {
  final TextEditingController _bondNumberController = TextEditingController();
  String _selectedDenomination = AppConfig.defaultDenomination;
  bool _isChecking = false;
  Map<String, dynamic>? _checkResult;

  final DrawService _drawService = DrawService();

  @override
  void initState() {
    super.initState();

    if (widget.initialBondNumber != null) {
      _bondNumberController.text = widget.initialBondNumber!;
    }
  }

  @override
  void dispose() {
    _bondNumberController.dispose();
    super.dispose();
  }

  void _checkBond() async {
    final number = _bondNumberController.text.trim();
    if (!BondNumberExtractor.isValidBondNumber(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit bond number'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    setState(() => _isChecking = true);

    final result = _drawService.checkBond(number, _selectedDenomination);
    await _drawService.updateSavedBondAfterCheck(number: number, denomination: _selectedDenomination, result: result);

    if (result != null) {
      await NotificationService().showWinNotification(
        bondNumber: number,
        denomination: _selectedDenomination,
        city: result.city,
      );
    }

    final record = CheckRecord()
      ..bondNumber = number
      ..denomination = _selectedDenomination
      ..checkedAt = DateTime.now()
      ..resultStatus = result != null ? 'Won' : 'No Win'
      ..drawNumber = result?.drawNumber ?? 'N/A'
      ..drawDate = result?.drawDate ?? 'N/A';
    await Hive.box<CheckRecord>('check_history').add(record);

    final checkedDraws = _drawService.getCompleted().where((d) => d.denomination == _selectedDenomination).length;

    setState(() {
      _isChecking = false;
      _checkResult = {
        'number': number,
        'denomination': _selectedDenomination,
        'status': result != null ? 'Winner!' : 'No Win',
        'drawDate': result?.drawDate ?? 'N/A',
        'drawNumber': result?.drawNumber ?? 'N/A',
        'checkedDraws': checkedDraws,
        'prizePosition': result != null ? _drawService.getPrizePosition(result, number) : null,
        'prizeAmount': result != null ? _drawService.getPrizeAmount(result, number) : null,
      };
    });

    _showResultDialog();
  }

  void _showResultDialog() {
    final bool isWin = _checkResult!['status'] == 'Winner!';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isWin ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isWin ? Icons.emoji_events : Icons.info_outline,
                color: isWin ? const Color(0xFF059669) : const Color(0xFF92400E),
              ),
            ),
            const SizedBox(width: 12),
            Text(isWin ? 'Congratulations!' : 'Check Result'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('Bond Number', _checkResult!['number']),
              _buildResultRow('Denomination', _checkResult!['denomination']),
              _buildResultRow('Status', _checkResult!['status']),
              if (isWin) ...[
                _buildResultRow('Prize', _checkResult!['prizePosition'] ?? ''),
                _buildResultRow('Amount', _checkResult!['prizeAmount'] ?? ''),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.emoji_events, color: Color(0xFF059669), size: 40),
                      SizedBox(height: 8),
                      Text(
                        'You Won a Prize!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sentiment_neutral, color: Color(0xFF92400E), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'No Prize Won',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Checked against ${_checkResult!['checkedDraws']} completed draws',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                      ),
                    ],
                  ),
                ),
              ],
              if (_checkResult!['drawDate'] != 'N/A') ...[
                const SizedBox(height: 16),
                Text(
                  'Last draw: ${_checkResult!['drawDate']} (Draw #${_checkResult!['drawNumber']})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _bondNumberController.clear();
              setState(() => _checkResult = null);
            },
            icon: const Icon(Icons.search),
            label: const Text('Check Another'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildCheckForm(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 100),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Check Prize Bond',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Enter your bond details to check results', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCheckForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note, color: Color(0xFF2D5BFF), size: 24),
                SizedBox(width: 12),
                Text(
                  'Enter Bond Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Denomination',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDenomination,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.monetization_on, color: Color(0xFF2D5BFF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              items: AppConfig.denominations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => _selectedDenomination = val!),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bond Number',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bondNumberController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Enter 6-digit number',
                prefixIcon: const Icon(Icons.numbers, color: Color(0xFF2D5BFF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkBond,
                icon: _isChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
                label: Text(_isChecking ? 'Checking...' : 'Check Bond'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.qr_code_scanner,
                  title: 'Scan Bond',
                  subtitle: 'Use camera',
                  gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                  onTap: () async {
                    final scannedNumber = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ScannerScreen(initialDenomination: _selectedDenomination)),
                    );
                    if (scannedNumber != null) {
                      _bondNumberController.text = scannedNumber;
                      if (BondNumberExtractor.isValidBondNumber(scannedNumber)) {
                        _checkBond();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.upload_file,
                  title: 'Upload List',
                  subtitle: 'Check txt/csv',
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BulkCheckScreen(denomination: _selectedDenomination)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
