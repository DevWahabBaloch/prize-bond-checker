import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDenomination = 'All';
  String _selectedCity = 'All';
  bool _isDownloading = false;

  final List<String> denominations = ['All', 'Rs. 100', 'Rs. 200', 'Rs. 750', 'Rs. 1500', 'Rs. 7500', 'Rs. 15000'];
  final List<String> cities = ['All', 'Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Multan', 'Faisalabad'];

  final List<Map<String, dynamic>> pastDraws = [
    {
      'denomination': 'Rs. 1500',
      'date': 'January 15, 2026',
      'city': 'Lahore',
      'firstPrize': '654321',
      'firstPrizeAmount': 'Rs. 3,000,000',
      'secondPrize': '321654',
      'secondPrizeAmount': 'Rs. 1,500,000',
      'thirdPrize': '111222',
      'thirdPrizeAmount': 'Rs. 93,000',
      'drawNumber': '98',
      'totalPrizes': '1,696',
    },
    {
      'denomination': 'Rs. 750',
      'date': 'January 10, 2026',
      'city': 'Karachi',
      'firstPrize': '987654',
      'firstPrizeAmount': 'Rs. 1,500,000',
      'secondPrize': '456789',
      'secondPrizeAmount': 'Rs. 500,000',
      'thirdPrize': '789456',
      'thirdPrizeAmount': 'Rs. 9,300',
      'drawNumber': '97',
      'totalPrizes': '1,696',
    },
    {
      'denomination': 'Rs. 200',
      'date': 'January 05, 2026',
      'city': 'Islamabad',
      'firstPrize': '456789',
      'firstPrizeAmount': 'Rs. 750,000',
      'secondPrize': '987123',
      'secondPrizeAmount': 'Rs. 250,000',
      'thirdPrize': '654987',
      'thirdPrizeAmount': 'Rs. 1,250',
      'drawNumber': '96',
      'totalPrizes': '1,130',
    },
    {
      'denomination': 'Rs. 1500',
      'date': 'December 15, 2025',
      'city': 'Rawalpindi',
      'firstPrize': '234567',
      'firstPrizeAmount': 'Rs. 3,000,000',
      'secondPrize': '765432',
      'secondPrizeAmount': 'Rs. 1,500,000',
      'thirdPrize': '112233',
      'thirdPrizeAmount': 'Rs. 93,000',
      'drawNumber': '95',
      'totalPrizes': '1,696',
    },
    {
      'denomination': 'Rs. 7500',
      'date': 'December 10, 2025',
      'city': 'Multan',
      'firstPrize': '890123',
      'firstPrizeAmount': 'Rs. 15,000,000',
      'secondPrize': '321098',
      'secondPrizeAmount': 'Rs. 5,000,000',
      'thirdPrize': '445566',
      'thirdPrizeAmount': 'Rs. 93,000',
      'drawNumber': '94',
      'totalPrizes': '1,696',
    },
    {
      'denomination': 'Rs. 100',
      'date': 'December 01, 2025',
      'city': 'Faisalabad',
      'firstPrize': '567890',
      'firstPrizeAmount': 'Rs. 700,000',
      'secondPrize': '098765',
      'secondPrizeAmount': 'Rs. 200,000',
      'thirdPrize': '334455',
      'thirdPrizeAmount': 'Rs. 1,000',
      'drawNumber': '93',
      'totalPrizes': '1,199',
    },
  ];

  final List<Map<String, dynamic>> upcomingDraws = [
    {'denomination': 'Rs. 200', 'date': 'January 20, 2026', 'city': 'Lahore', 'daysLeft': '3', 'estimatedPrize': 'Rs. 750,000'},
    {
      'denomination': 'Rs. 1500',
      'date': 'February 15, 2026',
      'city': 'Karachi',
      'daysLeft': '29',
      'estimatedPrize': 'Rs. 3,000,000',
    },
    {
      'denomination': 'Rs. 750',
      'date': 'February 20, 2026',
      'city': 'Islamabad',
      'daysLeft': '34',
      'estimatedPrize': 'Rs. 1,500,000',
    },
    {
      'denomination': 'Rs. 15000',
      'date': 'March 01, 2026',
      'city': 'Rawalpindi',
      'daysLeft': '43',
      'estimatedPrize': 'Rs. 30,000,000',
    },
  ];

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

  List<Map<String, dynamic>> get filteredDraws {
    return pastDraws.where((draw) {
      final matchesDenom = _selectedDenomination == 'All' || draw['denomination'] == _selectedDenomination;
      final matchesCity = _selectedCity == 'All' || draw['city'] == _selectedCity;
      return matchesDenom && matchesCity;
    }).toList();
  }

  // ─── PDF Generation ──────────────────────────────────────────────────────────

  Future<void> _downloadPDF(Map<String, dynamic> draw) async {
    setState(() => _isDownloading = true);

    try {
      final pdf = pw.Document();

      // ── Color palette ──
      final headerBlue = PdfColor.fromHex('#2D5BFF');
      final accentPurple = PdfColor.fromHex('#8B5CF6');
      final goldColor = PdfColor.fromHex('#F59E0B');
      final lightBlue = PdfColor.fromHex('#EFF6FF');
      final darkText = PdfColor.fromHex('#1F2937');
      final grayText = PdfColor.fromHex('#6B7280');
      final lightGray = PdfColor.fromHex('#F9FAFB');
      final borderGray = PdfColor.fromHex('#E5E7EB');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Header banner ──
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [headerBlue, accentPurple],
                      begin: pw.Alignment.centerLeft,
                      end: pw.Alignment.centerRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(16),
                  ),
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Prize Bond Draw Results',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Official National Savings Draw List', style: pw.TextStyle(color: PdfColors.white, fontSize: 13)),
                      pw.SizedBox(height: 16),
                      pw.Row(
                        children: [
                          _pdfChip('Draw #${draw['drawNumber']}', PdfColors.white, headerBlue),
                          pw.SizedBox(width: 10),
                          _pdfChip(draw['denomination'], PdfColors.white, accentPurple),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // ── Draw info row ──
                pw.Row(
                  children: [
                    _infoBox('Date', draw['date'], grayText, lightGray, borderGray, darkText),
                    pw.SizedBox(width: 12),
                    _infoBox('City', draw['city'], grayText, lightGray, borderGray, darkText),
                    pw.SizedBox(width: 12),
                    _infoBox('Total Prizes', draw['totalPrizes'], grayText, lightGray, borderGray, darkText),
                  ],
                ),

                pw.SizedBox(height: 20),

                // ── Prize section label ──
                pw.Text(
                  'Prize Winners',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: darkText),
                ),
                pw.SizedBox(height: 12),

                // ── 1st Prize ──
                _prizeCard(
                  rank: '1st Prize',
                  amount: draw['firstPrizeAmount'],
                  number: draw['firstPrize'],
                  bgColor: PdfColor.fromHex('#FEF3C7'),
                  rankColor: goldColor,
                  textColor: PdfColor.fromHex('#78350F'),
                ),

                pw.SizedBox(height: 10),

                // ── 2nd Prize ──
                _prizeCard(
                  rank: '2nd Prize',
                  amount: draw['secondPrizeAmount'] ?? 'N/A',
                  number: draw['secondPrize'] ?? 'N/A',
                  bgColor: PdfColor.fromHex('#F3F4F6'),
                  rankColor: PdfColor.fromHex('#6B7280'),
                  textColor: darkText,
                ),

                pw.SizedBox(height: 10),

                // ── 3rd Prize ──
                _prizeCard(
                  rank: '3rd Prize',
                  amount: draw['thirdPrizeAmount'] ?? 'N/A',
                  number: draw['thirdPrize'] ?? 'N/A',
                  bgColor: PdfColor.fromHex('#FFF7ED'),
                  rankColor: PdfColor.fromHex('#F97316'),
                  textColor: darkText,
                ),

                pw.SizedBox(height: 24),

                // ── Offline notice ──
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: lightBlue,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: headerBlue, width: 0.5),
                  ),
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '📱 Offline Access',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: headerBlue),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'This PDF has been saved to your device for offline checking. '
                        'You can verify your prize bond numbers against this list '
                        'even without an internet connection.',
                        style: pw.TextStyle(fontSize: 11, color: grayText),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // ── Footer ──
                pw.Divider(color: borderGray),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Prize Bond Checker App • National Savings Pakistan',
                      style: pw.TextStyle(fontSize: 10, color: grayText),
                    ),
                    pw.Text(
                      'Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: pw.TextStyle(fontSize: 10, color: grayText),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // ── Save to device ──
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Draw_${draw['drawNumber']}_${draw['denomination'].replaceAll('.', '').replaceAll(' ', '_')}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      setState(() => _isDownloading = false);

      if (mounted) {
        // Open the PDF immediately
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('✅ PDF saved: $fileName', style: const TextStyle(fontSize: 13))),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── PDF widget helpers ────────────────────────────────────────────────────────

  pw.Widget _pdfChip(String text, PdfColor textColor, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(20)),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: textColor, fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _infoBox(String label, String value, PdfColor labelColor, PdfColor bg, PdfColor border, PdfColor valueColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 10, color: labelColor)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: valueColor),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _prizeCard({
    required String rank,
    required String amount,
    required String number,
    required PdfColor bgColor,
    required PdfColor rankColor,
    required PdfColor textColor,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: bgColor, borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                rank,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: rankColor),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                number,
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: textColor),
              ),
            ],
          ),
          pw.Text(
            amount,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  // ─── Reminder ────────────────────────────────────────────────────────────────

  void _setReminder(Map<String, dynamic> draw) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder set for ${draw['denomination']} draw on ${draw['date']}'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

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
          // Loading overlay while PDF generates
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

                const Text(
                  'Draw History',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const Spacer(),

                IconButton(
                  icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
                  onPressed: _showFilterDialog,
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
    return filteredDraws.isEmpty
        ? _buildEmptyState()
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredDraws.length,
            itemBuilder: (context, index) => _buildPastDrawCard(filteredDraws[index]),
          );
  }

  Widget _buildUpcomingDrawsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: upcomingDraws.length,
      itemBuilder: (context, index) => _buildUpcomingDrawCard(upcomingDraws[index]),
    );
  }

  Widget _buildPastDrawCard(Map<String, dynamic> draw) {
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
          onTap: () => _showDrawDetails(draw),
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

  Widget _buildUpcomingDrawCard(Map<String, dynamic> draw) {
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
                        draw['daysLeft'],
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Text('Days Left', style: TextStyle(fontSize: 11, color: Colors.white)),
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
                    draw['estimatedPrize'],
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
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
                  final sel = _selectedDenomination == d;
                  return FilterChip(
                    label: Text(d),
                    selected: sel,
                    onSelected: (_) {
                      setModalState(() => _selectedDenomination = d);
                      setState(() => _selectedDenomination = d);
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
                  final sel = _selectedCity == c;
                  return FilterChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (_) {
                      setModalState(() => _selectedCity = c);
                      setState(() => _selectedCity = c);
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedDenomination = 'All';
                          _selectedCity = 'All';
                        });
                        setState(() {
                          _selectedDenomination = 'All';
                          _selectedCity = 'All';
                        });
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
      ),
    );
  }

  void _showDrawDetails(Map<String, dynamic> draw) {
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
            // Sheet header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draw['denomination'],
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Draw #${draw['drawNumber']} • ${draw['date']}',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Sheet body
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
                    const SizedBox(height: 24),
                    // ── Download PDF button (real) ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadPDF(draw);
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
                    // ── Share button REMOVED (not in requirements) ──────────
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
