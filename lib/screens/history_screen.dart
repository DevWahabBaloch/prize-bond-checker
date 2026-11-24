import 'dart:io';

import 'package:flutter/material.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/models/draw_result_model.dart';
import 'package:prize_bond_checking_app/services/draw_report_service.dart';
import 'package:prize_bond_checking_app/services/draw_service.dart';
import 'package:prize_bond_checking_app/widgets/draw_reminder_dialog.dart';
import 'package:prize_bond_checking_app/widgets/draw_filter_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late final _storage = AuthService.requireStorage();

  late TabController _tabController;
  String _selectedDenomination = 'All';
  String _selectedCity = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isDownloading = false;

  final List<String> denominations = ['All', ...AppConfig.denominations];
  final List<String> cities = ['All', ...AppConfig.drawCities];

  final DrawService _drawService = DrawService();
  final _reports = const DrawReportService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DrawResult> _applyFilters(List<DrawResult> all) {
    return all.where((d) {
      final matchesDenom = _selectedDenomination == 'All' || d.denomination == _selectedDenomination;
      final matchesCity = _selectedCity == 'All' || d.city == _selectedCity;
      final matchesDate =
          (_fromDate == null && _toDate == null) ||
          (() {
            try {
              final drawDt = DateFormat('MMMM d, yyyy').parse(d.drawDate);
              final afterFrom = _fromDate == null || !drawDt.isBefore(_fromDate!);
              final beforeTo = _toDate == null || !drawDt.isAfter(_toDate!);
              return afterFrom && beforeTo;
            } catch (_) {
              return true;
            }
          })();
      return matchesDenom && matchesCity && matchesDate;
    }).toList();
  }

  bool get _isDateFilterActive => _fromDate != null || _toDate != null;
  bool get _isAnyFilterActive => _selectedDenomination != 'All' || _selectedCity != 'All' || _isDateFilterActive;

  Map<String, dynamic> _drawToMap(DrawResult d) => {
    'drawNumber': d.drawNumber,
    'denomination': d.denomination,
    'date': d.drawDate,
    'city': d.city,
    'firstPrize': d.firstPrize,
    'firstPrizeAmount': d.firstPrizeAmount,
    'secondPrize': d.secondPrize ?? 'N/A',
    'secondPrizeAmount': d.secondPrizeAmount ?? 'N/A',
    'thirdPrize': d.thirdPrize ?? 'N/A',
    'thirdPrizeAmount': d.thirdPrizeAmount ?? 'N/A',
    'totalPrizes': d.totalPrizes,
    'prizeWinners': d.prizeWinners.map((p) => {'position': p.position, 'number': p.number, 'amount': p.amount}).toList(),
  };

  bool get _canShowReportFeedback => mounted && AuthService.canUseStorage(_storage);

  Future<void> _downloadPDF(DrawResult draw) async {
    if (_isDownloading || !_canShowReportFeedback || _drawService.statusOf(draw) != DrawStatus.completed) return;
    setState(() => _isDownloading = true);
    try {
      final file = await _reports.save(draw);
      if (!mounted || !AuthService.canUseStorage(_storage)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF saved to app storage.'),
          action: SnackBarAction(label: 'Open PDF', onPressed: () => _openReport(file)),
        ),
      );
    } catch (_) {
      if (mounted && AuthService.canUseStorage(_storage)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the PDF. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _openReport(File file) async {
    if (!_canShowReportFeedback) return;
    var opened = false;
    try {
      opened = await _reports.open(file);
    } catch (_) {
      // The saved report is still available if the platform cannot open it.
    }
    if (mounted && AuthService.canUseStorage(_storage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(opened ? 'PDF viewer opened.' : 'PDF saved. The device could not open it.')),
      );
    }
  }

  Future<void> _setReminder(DrawResult draw) => showDrawReminderDialog(context, _storage, draw);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(controller: _tabController, children: [_buildPastDrawsTab(), _buildUpcomingDrawsTab()]),
              ),
            ],
          ),
          if (_isDownloading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2D5BFF)),
                      SizedBox(height: 16),
                      Text('Generating PDF...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Saving for offline use', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
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

                const Icon(Icons.history_rounded, color: Colors.white, size: 28),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Sample Draw History',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),

                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
                      onPressed: _showFilterDialog,
                    ),
                    if (_isAnyFilterActive)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text('Browse all prize bond draw results', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF2D5BFF),
        indicatorWeight: 3,
        labelColor: const Color(0xFF2D5BFF),
        unselectedLabelColor: const Color(0xFF9CA3AF),
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Past Draws'),
          Tab(text: 'Upcoming Draws'),
        ],
      ),
    );
  }

  Widget _buildPastDrawsTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DrawResult>('draws').listenable(),
      builder: (context, Box<DrawResult> box, _) {
        final all = _drawService.getCompleted();
        final filtered = _applyFilters(all);
        return filtered.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _buildPastDrawCard(filtered[index]),
              );
      },
    );
  }

  Widget _buildUpcomingDrawsTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DrawResult>('draws').listenable(),
      builder: (context, Box<DrawResult> box, _) {
        final upcoming = _applyFilters(_drawService.getUpcoming());
        if (upcoming.isEmpty) return _buildEmptyState();
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: upcoming.length,
          itemBuilder: (context, index) => _buildUpcomingDrawCard(upcoming[index]),
        );
      },
    );
  }

  Widget _buildPastDrawCard(DrawResult result) {
    final draw = _drawToMap(result);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDrawDetails(result),
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
                              draw['denomination'],
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            draw['date'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text(draw['city'], style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                              const SizedBox(width: 12),
                              const Icon(Icons.numbers, size: 14, color: Color(0xFF6B7280)),
                              const SizedBox(width: 4),
                              Text('Draw #${draw['drawNumber']}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1st Prize Winner',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            draw['firstPrize'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: Color(0xFF78350F),
                            ),
                          ),
                          Text(
                            draw['firstPrizeAmount'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Prizes: ${draw['totalPrizes']}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const Row(
                      children: [
                        Text(
                          'View Full List',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D5BFF)),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF2D5BFF)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingDrawCard(DrawResult draw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFFAF5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                        decoration: BoxDecoration(color: const Color(0xFF2D5BFF), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          draw.denomination,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        draw.drawDate,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(draw.city, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _drawService.statusOf(draw) == DrawStatus.today ? '0' : '${_drawService.daysUntil(draw)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _drawService.statusOf(draw) == DrawStatus.today ? 'Today!' : 'Days Left',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expected 1st Prize', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Color(0xFF6B7280)),
                          SizedBox(width: 4),
                          Text('Subject to change', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    draw.firstPrizeAmount,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _setReminder(draw),
                icon: const Icon(Icons.notifications_outlined, size: 16),
                label: const Text('Set Reminder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D5BFF),
                  side: const BorderSide(color: Color(0xFF2D5BFF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
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
            child: const Icon(Icons.search_off_rounded, size: 64, color: Color(0xFF2D5BFF)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No draws found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          const Text('Try adjusting your filters', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {
              _selectedDenomination = 'All';
              _selectedCity = 'All';
              _fromDate = null;
              _toDate = null;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DrawFilterSheet(
        selectedDenomination: _selectedDenomination,
        selectedCity: _selectedCity,
        fromDate: _fromDate,
        toDate: _toDate,
        onApply: (denomination, city, fromDate, toDate) {
          setState(() {
            _selectedDenomination = denomination;
            _selectedCity = city;
            _fromDate = fromDate;
            _toDate = toDate;
          });
        },
      ),
    );
  }

  void _showDrawDetails(DrawResult result) {
    final draw = _drawToMap(result);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draw['denomination'],
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Draw #${draw['drawNumber']} • ${draw['date']}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Draw Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Location', draw['city'], Icons.location_on),
                    _buildInfoRow('Total Prizes', draw['totalPrizes'], Icons.emoji_events),
                    _buildInfoRow('1st Prize Amount', draw['firstPrizeAmount'], Icons.monetization_on),
                    _buildInfoRow('2nd Prize Amount', draw['secondPrizeAmount'] ?? 'N/A', Icons.monetization_on),
                    _buildInfoRow('3rd Prize Amount', draw['thirdPrizeAmount'] ?? 'N/A', Icons.monetization_on),
                    if ((draw['prizeWinners'] as List).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'All Prize Winners',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 12),
                      ...(draw['prizeWinners'] as List).map((p) {
                        final entry = p as Map;
                        return _buildInfoRow(
                          entry['position'] as String,
                          '${entry['number']} — ${entry['amount']}',
                          Icons.confirmation_number_outlined,
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadPDF(result);
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download Full List (PDF)'),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: const Color(0xFF2D5BFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
