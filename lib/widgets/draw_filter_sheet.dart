import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';

class DrawFilterSheet extends StatefulWidget {
  final String selectedDenomination;
  final String selectedCity;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool showCityFilter;
  final void Function(String denomination, String city, DateTime? fromDate, DateTime? toDate) onApply;

  const DrawFilterSheet({
    super.key,
    required this.selectedDenomination,
    required this.selectedCity,
    required this.fromDate,
    required this.toDate,
    required this.onApply,
    this.showCityFilter = true,
  });

  @override
  State<DrawFilterSheet> createState() => _DrawFilterSheetState();
}

class _DrawFilterSheetState extends State<DrawFilterSheet> {
  late String _denomination;
  late String _city;
  DateTime? _fromDate;
  DateTime? _toDate;

  final List<String> denominations = ['All', ...AppConfig.denominations];
  final List<String> cities = ['All', ...AppConfig.drawCities];

  @override
  void initState() {
    super.initState();
    _denomination = widget.selectedDenomination;
    _city = widget.selectedCity;
    _fromDate = widget.fromDate;
    _toDate = widget.toDate;
  }

  void _applyLive() => widget.onApply(_denomination, _city, _fromDate, _toDate);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Draws',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Denomination',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: denominations.map((d) {
                final sel = _denomination == d;
                return FilterChip(
                  label: Text(d),
                  selected: sel,
                  onSelected: (_) {
                    setState(() => _denomination = d);
                    _applyLive();
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFEFF6FF),
                  labelStyle: TextStyle(
                    color: sel ? const Color(0xFF2D5BFF) : const Color(0xFF6B7280),
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(color: sel ? const Color(0xFF2D5BFF) : const Color(0xFFE5E7EB)),
                );
              }).toList(),
            ),
            if (widget.showCityFilter) ...[
              const SizedBox(height: 24),
              const Text(
                'City',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cities.map((c) {
                  final sel = _city == c;
                  return FilterChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _city = c);
                      _applyLive();
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFEFF6FF),
                    labelStyle: TextStyle(
                      color: sel ? const Color(0xFF2D5BFF) : const Color(0xFF6B7280),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(color: sel ? const Color(0xFF2D5BFF) : const Color(0xFFE5E7EB)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Date Range',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
                if (_fromDate != null || _toDate != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _fromDate = null;
                        _toDate = null;
                      });
                      _applyLive();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear Dates', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dateBox(label: 'From', date: _fromDate, onTap: () => _pickDate(isFrom: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateBox(label: 'To', date: _toDate, onTap: () => _pickDate(isFrom: false)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _denomination = 'All';
                        _city = 'All';
                        _fromDate = null;
                        _toDate = null;
                      });
                      _applyLive();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _dateBox({required String label, required DateTime? date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: date != null ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: date != null ? const Color(0xFF2D5BFF) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: date != null ? const Color(0xFF2D5BFF) : const Color(0xFF9CA3AF)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  Text(
                    date != null ? DateFormat('MMM d, yyyy').format(date) : 'Any',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: date != null ? const Color(0xFF2D5BFF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2D5BFF), onPrimary: Colors.white, surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _applyLive();
    }
  }
}
