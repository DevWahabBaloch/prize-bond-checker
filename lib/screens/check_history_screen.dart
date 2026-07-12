import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';

class CheckHistoryScreen extends StatefulWidget {
  const CheckHistoryScreen({super.key});

  @override
  State<CheckHistoryScreen> createState() => _CheckHistoryScreenState();
}

class _CheckHistoryScreenState extends State<CheckHistoryScreen> {
  String _selectedDenomination = 'All';
  String _selectedResult = 'All';

  final List<String> denominations = [
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
  final List<String> results = ['All', 'Won', 'No Win'];

  List<CheckRecord> _filtered(List<CheckRecord> all) {
    return all.where((r) {
      final matchDenom = _selectedDenomination == 'All' || r.denomination == _selectedDenomination;
      final matchResult = _selectedResult == 'All' || r.resultStatus == _selectedResult;
      return matchDenom && matchResult;
    }).toList()..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    // Responsive helpers: adapt to screen width and respect the device's
    // safe-area insets (notches / status bar) instead of hardcoded values.
    final screenWidth = MediaQuery.of(context).size.width;
    final topInset = MediaQuery.of(context).padding.top;
    final isWide = screenWidth >= 600; // tablets / foldables / desktop web
    final maxContentWidth = isWide ? 720.0 : double.infinity;
    final horizontalPagePadding = isWide ? 24.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            children: [
              _buildHeader(topInset, isWide),
              _buildFilters(isWide),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: Hive.box<CheckRecord>('check_history').listenable(),
                  builder: (context, Box<CheckRecord> box, _) {
                    final records = _filtered(box.values.toList());
                    if (records.isEmpty) return _buildEmptyState();
                    return ListView.builder(
                      padding: EdgeInsets.all(horizontalPagePadding),
                      itemCount: records.length,
                      itemBuilder: (context, i) => _buildCard(records[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double topInset, bool isWide) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      // Top padding now respects the safe area (status bar / notch) instead
      // of a fixed 50px, so it looks correct across different devices.
      padding: EdgeInsets.fromLTRB(8, topInset + 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Check History',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWide ? 24 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              ValueListenableBuilder(
                valueListenable: Hive.box<CheckRecord>('check_history').listenable(),
                builder: (context, Box<CheckRecord> box, _) {
                  if (box.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                    tooltip: 'Clear all history',
                    onPressed: () => _confirmClearAll(box),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('All previous bond checks', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isWide) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 14, isWide ? 24 : 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Denomination',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: denominations.length,
              itemBuilder: (context, i) {
                final d = denominations[i];
                final sel = _selectedDenomination == d;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(d, style: const TextStyle(fontSize: 12)),
                    selected: sel,
                    onSelected: (_) => setState(() => _selectedDenomination = d),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFEFF6FF),
                    labelStyle: TextStyle(
                      color: sel ? const Color(0xFF2D5BFF) : const Color(0xFF6B7280),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(color: sel ? const Color(0xFF2D5BFF) : const Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Wrapped in a horizontal scroll view so this row can never
          // overflow on narrow screens or with larger accessibility
          // text-scaling settings (it used to be a plain, non-scrollable Row).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: results.map((r) {
                final sel = _selectedResult == r;
                Color color;
                if (r == 'Won')
                  color = const Color(0xFF059669);
                else if (r == 'No Win')
                  color = const Color(0xFFF59E0B);
                else
                  color = const Color(0xFF2D5BFF);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    selected: sel,
                    onSelected: (_) => setState(() => _selectedResult = r),
                    backgroundColor: Colors.white,
                    selectedColor: color.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: sel ? color : const Color(0xFF6B7280),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(color: sel ? color : const Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(CheckRecord record) {
    final isWin = record.resultStatus == 'Won';
    final statusColor = isWin ? const Color(0xFF059669) : const Color(0xFFF59E0B);
    final statusBg = isWin ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flexible so a long bond number / denomination label can
                // never push the status badge off-screen on narrow devices.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.bondNumber,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          record.denomination,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isWin ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        record.resultStatus,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              // Flexible chips + a Spacer instead of a rigid Row: on wide
              // screens it lays out exactly as before (draw # and date on
              // the left, time on the right); on narrow screens the chips
              // shrink with an ellipsis instead of overflowing.
              child: Row(
                children: [
                  Flexible(child: _infoChip(Icons.numbers_outlined, 'Draw #${record.drawNumber}')),
                  const SizedBox(width: 12),
                  Flexible(child: _infoChip(Icons.calendar_today_outlined, record.drawDate)),
                  const Spacer(),
                  Flexible(child: _infoChip(Icons.access_time_outlined, _formatDateTime(record.checkedAt))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.history_toggle_off_rounded, size: 64, color: Color(0xFF2D5BFF)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No checks yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          const Text('Your bond check history will appear here', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  void _confirmClearAll(Box<CheckRecord> box) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to delete all check history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              box.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Check history cleared'),
                  backgroundColor: Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}