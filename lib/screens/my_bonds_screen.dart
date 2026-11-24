import 'package:prize_bond_checking_app/models/bond_check_result.dart';
import 'package:prize_bond_checking_app/services/bond_checking_service.dart';
import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/widgets/bond_number_extractor.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';
import 'package:uuid/uuid.dart';

class MyBondsScreen extends StatefulWidget {
  const MyBondsScreen({super.key});

  @override
  State<MyBondsScreen> createState() => _MyBondsScreenState();
}

class _MyBondsScreenState extends State<MyBondsScreen> {
  late final _storage = AuthService.requireStorage();

  PrivateRecords<Bond> get _box => _storage.bonds;
  final _checking = BondCheckingService();

  String _selectedFilter = 'All';
  final List<String> filterOptions = ['All', ...AppConfig.denominations];

  List<Bond> _filteredBonds(List<Bond> all) {
    if (_selectedFilter == 'All') return all;
    return all.where((b) => b.denomination == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterSection(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _box,
              builder: (context, PrivateRecords<Bond> box, _) {
                final bonds = _filteredBonds(box.values.toList());
                return bonds.isEmpty ? _buildEmptyState() : _buildBondsList(bonds);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBondDialog,
        backgroundColor: const Color(0xFF2D5BFF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Bond', style: TextStyle(color: Colors.white)),
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
                if (Navigator.canPop(context))
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                const Icon(Icons.bookmark_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'My Bonds',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _checkAllBonds,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Manage and auto-check your saved bonds', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Filter by Denomination',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filterOptions.length,
              itemBuilder: (context, index) {
                final option = filterOptions[index];
                final isSelected = _selectedFilter == option;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = option),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFEFF6FF),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF2D5BFF) : const Color(0xFF6B7280),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    side: BorderSide(color: isSelected ? const Color(0xFF2D5BFF) : const Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBondsList(List<Bond> bonds) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: bonds.length,
      itemBuilder: (context, index) => _buildBondCard(bonds[index]),
    );
  }

  Widget _buildBondCard(Bond bond) {
    Color statusColor;
    Color statusBg;

    if (bond.status == 'Won') {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFD1FAE5);
    } else if (bond.status == 'No Win') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFEF3C7);
    } else {
      statusColor = const Color(0xFF2D5BFF);
      statusBg = const Color(0xFFEFF6FF);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bond.denomination,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bond.number,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(_formatDate(bond.addedDate), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                      if (bond.issueDate != null)
                        Text(
                          'Issued ${_formatDate(bond.issueDate!)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      if (bond.issueCity != null)
                        Text(bond.issueCity!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      if (bond.lastChecked != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.update, size: 14, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(
                              'Last checked: ${_formatDate(bond.lastChecked!)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    bond.status == 'Active' ? 'Active' : bond.status,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _checkSingleBond(bond),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Check Now'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D5BFF),
                      side: const BorderSide(color: Color(0xFF2D5BFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteBond(bond),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
              child: const Icon(Icons.bookmark_border_rounded, size: 64, color: Color(0xFF2D5BFF)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Saved Bonds',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your prize bonds to auto-check them\nwhenever new draws are announced',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddBondDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Bond'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBondDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AddBondDialog(storage: _storage),
    );
    if (saved == true && mounted && AuthService.canUseStorage(_storage)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bond added successfully!')));
    }
  }

  Future<bool> _commit(Future<void> write) async {
    try {
      await write;
      return mounted && AuthService.canUseStorage(_storage);
    } catch (_) {
      if (mounted && AuthService.canUseStorage(_storage)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the bond change.')));
      }
      return false;
    }
  }

  Future<void> _checkSingleBond(Bond bond) async {
    final result = await _checkSavedBond(bond);
    if (result == null || !mounted || !AuthService.canUseStorage(_storage)) return;
    final win = result.win;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              win != null ? Icons.emoji_events : Icons.info_outline,
              color: win != null ? const Color(0xFF059669) : const Color(0xFF2D5BFF),
            ),
            const SizedBox(width: 12),
            Text(win != null ? 'Winner!' : 'Check Result'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bond Number: ${bond.number}'),
            const SizedBox(height: 8),
            Text('Denomination: ${bond.denomination}'),
            const Text(AppConfig.simulatedResultsLabel),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: win != null ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    win != null ? Icons.emoji_events : Icons.sentiment_neutral,
                    color: win != null ? const Color(0xFF059669) : const Color(0xFF92400E),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      win != null
                          ? 'Won in Draw #${win.drawNumber} (${win.drawDate})\n${win.position} • ${win.amount}'
                          : '${result.outcome.label}\n${result.coverage.summary}',
                      style: TextStyle(
                        color: win != null ? const Color(0xFF059669) : const Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5BFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAllBonds() async {
    if (_box.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No bonds to check. Add bonds first.')));
      return;
    }

    var wins = 0;
    var noWins = 0;
    var unavailable = 0;
    var failed = 0;
    for (final bond in _box.values) {
      if (!mounted || !AuthService.canUseStorage(_storage)) return;
      switch ((await _checkSavedBond(bond, showError: false))?.outcome) {
        case BondCheckOutcome.win:
          wins++;
        case BondCheckOutcome.noWin:
          noWins++;
        case BondCheckOutcome.resultsUnavailable:
          unavailable++;
        case null:
          failed++;
      }
    }

    if (!mounted || !AuthService.canUseStorage(_storage)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppConfig.simulatedResultsLabel}: $wins won, $noWins no win, $unavailable results unavailable'
          '${failed > 0 ? ', $failed could not be checked' : ''}',
        ),
        backgroundColor: wins > 0 ? const Color(0xFF059669) : const Color(0xFF2D5BFF),
      ),
    );
  }

  Future<BondCheckResult?> _checkSavedBond(Bond bond, {bool showError = true}) async {
    try {
      return await _checking.check(_storage, bond.number, bond.denomination, recordHistory: false);
    } catch (_) {
      if (showError && mounted && AuthService.canUseStorage(_storage)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check this saved bond.')));
      }
      return null;
    }
  }

  void _deleteBond(Bond bond) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Bond'),
        content: Text('Are you sure you want to delete bond ${bond.number}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!await _commit(_box.delete(bond)) || !context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bond deleted successfully')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _AddBondDialog extends StatefulWidget {
  const _AddBondDialog({required this.storage});

  final AccountStorage storage;

  @override
  State<_AddBondDialog> createState() => _AddBondDialogState();
}

class _AddBondDialogState extends State<_AddBondDialog> {
  static const _cities = ['Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Peshawar', 'Quetta', 'Muzaffarabad', 'Faisalabad'];
  final _numberController = TextEditingController();
  final _bondId = const Uuid().v4();
  var _denomination = AppConfig.defaultDenomination;
  DateTime? _issueDate;
  String? _issueCity;
  String? _numberError;
  String? _saveError;
  bool _saving = false;

  bool get _isActive => mounted && AuthService.canUseStorage(widget.storage);

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _pickIssueDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate ?? today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (_isActive && picked != null) {
      // Keep the picked calendar date independent of later device time-zone changes.
      setState(() => _issueDate = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _scan() async {
    final scan = await Navigator.of(context).push<BondScanResult>(
      MaterialPageRoute(builder: (_) => ScannerScreen(initialDenomination: _denomination, captureOnly: true)),
    );
    if (!_isActive || scan == null) return;
    _numberController.text = scan.number;
    setState(() {
      _denomination = scan.denomination;
      _numberError = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_isActive) return;
    final number = _numberController.text.trim();
    if (!BondNumberExtractor.isValidBondNumber(number)) {
      setState(() => _numberError = 'Please enter a valid 6-digit number');
      return;
    }

    setState(() {
      _saving = true;
      _numberError = null;
      _saveError = null;
    });
    final now = DateTime.now();
    final bond = Bond()
      ..id = _bondId
      ..number = number
      ..denomination = _denomination
      ..status = 'Active'
      ..addedDate = now
      ..issueDate = _issueDate
      ..issueCity = _issueCity;

    try {
      await widget.storage.bonds.addIfAbsent(_bondId, bond);
      if (_isActive) Navigator.of(context).pop(true);
    } catch (_) {
      if (_isActive) setState(() => _saveError = 'Could not save the bond. Please try again.');
    } finally {
      if (_isActive) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueDate = _issueDate;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Bond'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _numberController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (_) {
                  if (_numberError != null) setState(() => _numberError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Bond Number',
                  hintText: 'Enter 6-digit number',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                  errorText: _numberError,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _denomination,
                decoration: InputDecoration(
                  labelText: 'Denomination',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: AppConfig.denominations.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: _saving ? null : (value) => setState(() => _denomination = value!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _saving ? null : _pickIssueDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Issue',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(issueDate == null ? 'Select Date' : '${issueDate.day}/${issueDate.month}/${issueDate.year}'),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _issueCity,
                decoration: InputDecoration(
                  labelText: 'City',
                  prefixIcon: const Icon(Icons.location_city),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _cities.map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
                onChanged: _saving ? null : (value) => setState(() => _issueCity = value),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Scan Instead'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D5BFF),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_saveError case final error?) Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5BFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_saving ? 'Saving…' : 'Add Bond', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
