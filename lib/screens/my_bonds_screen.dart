import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/screens/scanner_screen.dart';

class MyBondsScreen extends StatefulWidget {
  const MyBondsScreen({super.key});

  @override
  State<MyBondsScreen> createState() => _MyBondsScreenState();
}

class _MyBondsScreenState extends State<MyBondsScreen> {
  // TODO: Replace with bonds loaded from local storage / backend
  final List<Map<String, dynamic>> savedBonds = [];

  String _selectedFilter = 'All';
  final List<String> filterOptions = [
    'All',
    'Rs. 100',
    'Rs. 200',
    'Rs. 750',
    'Rs. 1500',
    'Rs. 7500',
    'Rs. 15000',
    'Rs. 25000',
    'Rs. 40000',
  ];

  List<Map<String, dynamic>> get filteredBonds {
    if (_selectedFilter == 'All') return savedBonds;
    return savedBonds.where((bond) => bond['denomination'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterSection(),
          Expanded(child: filteredBonds.isEmpty ? _buildEmptyState() : _buildBondsList()),
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

  Widget _buildBondsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredBonds.length,
      itemBuilder: (context, index) => _buildBondCard(filteredBonds[index]),
    );
  }

  Widget _buildBondCard(Map<String, dynamic> bond) {
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
                          bond['denomination'],
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bond['number'],
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
                          Text(bond['addedDate'], style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    bond['status'],
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
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
    String selectedDenomination = 'Rs. 1500';

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
                  items: const [
                    'Rs. 100',
                    'Rs. 200',
                    'Rs. 750',
                    'Rs. 1500',
                    'Rs. 7500',
                    'Rs. 15000',
                    'Rs. 25000',
                    'Rs. 40000',
                  ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
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
                        MaterialPageRoute(builder: (_) => const ScannerScreen()),
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
                  setState(() {
                    savedBonds.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'number': bondNumberController.text,
                      'denomination': selectedDenomination,
                      'status': 'Active',
                      'addedDate': 'Just now',
                    });
                  });
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

  void _checkSingleBond(Map<String, dynamic> bond) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Checking Bond...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2D5BFF)),
            const SizedBox(height: 16),
            Text('Checking ${bond['number']} against latest draws...'),
          ],
        ),
      ),
    );

    // TODO: Replace with real API call to match against official draw results
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF2D5BFF)),
              SizedBox(width: 12),
              Text('Check Result'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bond Number: ${bond['number']}'),
              const SizedBox(height: 8),
              Text('Denomination: ${bond['denomination']}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.sentiment_neutral, color: Color(0xFF92400E)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No win found in recent draws',
                        style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600),
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
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  void _checkAllBonds() {
    if (savedBonds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No bonds to check. Add bonds first.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Checking all ${savedBonds.length} bonds against latest draws...'),
        backgroundColor: const Color(0xFF2D5BFF),
      ),
    );
    // TODO: Trigger real auto-check against official draw results
  }

  void _deleteBond(Map<String, dynamic> bond) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Bond'),
        content: Text('Are you sure you want to delete bond ${bond['number']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                savedBonds.removeWhere((b) => b['id'] == bond['id']);
              });
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
}
