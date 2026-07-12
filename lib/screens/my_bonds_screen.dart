import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:prize_bond_checking_app/services/notification_service.dart';

class MyBondsScreen extends StatefulWidget {
  const MyBondsScreen({super.key});

  @override
  State<MyBondsScreen> createState() => _MyBondsScreenState();
}

class _MyBondsScreenState extends State<MyBondsScreen> {
  Box<Bond> get _box => Hive.box<Bond>('bonds');
  final DrawService _drawService = DrawService();

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
              valueListenable: _box.listenable(),
              builder: (context, Box<Bond> box, _) {
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

  void _showAddBondDialog({String? prefillNumber}) {
    final bondNumberController = TextEditingController(text: prefillNumber ?? '');
    String selectedDenomination = AppConfig.defaultDenomination;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Bond'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: bondNumberController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Bond Number',
                    hintText: 'Enter 6-digit number',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDenomination,
                  decoration: InputDecoration(
                    labelText: 'Denomination',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: AppConfig.denominations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) => setDialogState(() => selectedDenomination = val!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final scannedNumber = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ScannerScreen(initialDenomination: selectedDenomination)),
                      );
                      if (scannedNumber != null) {
                        _showAddBondDialog(prefillNumber: scannedNumber);
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Scan Instead'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2D5BFF),
                      side: const BorderSide(color: Color(0xFF2D5BFF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (bondNumberController.text.length == 6) {
                  final bond = Bond()
                    ..id = DateTime.now().millisecondsSinceEpoch.toString()
                    ..number = bondNumberController.text
                    ..denomination = selectedDenomination
                    ..status = 'Active'
                    ..addedDate = DateTime.now();
                  _box.add(bond);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bond added successfully!')));
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Please enter a valid 6-digit number')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5BFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add Bond', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _checkSingleBond(Bond bond) {
    final result = _drawService.checkBond(bond.number, bond.denomination);

    bond.lastChecked = DateTime.now();
    bond.status = result != null ? 'Won' : 'No Win';
    bond.lastResult = result?.drawNumber;
    bond.save();

    if (result != null) {
      NotificationService().showWinNotification(bondNumber: bond.number, denomination: bond.denomination, city: result.city);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              result != null ? Icons.emoji_events : Icons.info_outline,
              color: result != null ? const Color(0xFF059669) : const Color(0xFF2D5BFF),
            ),
            const SizedBox(width: 12),
            Text(result != null ? 'Winner!' : 'Check Result'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bond Number: ${bond.number}'),
            const SizedBox(height: 8),
            Text('Denomination: ${bond.denomination}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: result != null ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    result != null ? Icons.emoji_events : Icons.sentiment_neutral,
                    color: result != null ? const Color(0xFF059669) : const Color(0xFF92400E),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result != null
                          ? '🎉 Won in Draw #${result.drawNumber} (${result.drawDate})\n${_drawService.getPrizePosition(result, bond.number)} — ${_drawService.getPrizeAmount(result, bond.number)}'
                          : 'No win found in completed draws',
                      style: TextStyle(
                        color: result != null ? const Color(0xFF059669) : const Color(0xFF92400E),
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

  void _checkAllBonds() {
    if (_box.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No bonds to check. Add bonds first.')));
      return;
    }

    int wins = 0;
    for (final bond in _box.values) {
      final result = _drawService.checkBond(bond.number, bond.denomination);
      bond.lastChecked = DateTime.now();
      bond.status = result != null ? 'Won' : 'No Win';
      bond.lastResult = result?.drawNumber;
      bond.save();
      if (result != null) wins++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wins > 0 ? '🎉 $wins winning bond${wins > 1 ? 's' : ''} found!' : 'Checked ${_box.length} bonds — no wins found',
        ),
        backgroundColor: wins > 0 ? const Color(0xFF059669) : const Color(0xFF2D5BFF),
      ),
    );
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
            onPressed: () {
              bond.delete();
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
