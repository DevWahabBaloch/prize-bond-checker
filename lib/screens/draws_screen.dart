import 'package:flutter/material.dart';

class DrawsScreen extends StatefulWidget {
  const DrawsScreen({super.key});

  @override
  State<DrawsScreen> createState() => _DrawsScreenState();
}

class _DrawsScreenState extends State<DrawsScreen> {
  String _selectedDenomination = 'All';

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

  // TODO: Replace with real draw data from National Savings API
  final List<Map<String, dynamic>> allDraws = [
    {
      'denomination': 'Rs. 40000',
      'drawDate': 'January 20, 2026',
      'city': 'Quetta',
      'status': 'upcoming',
      'daysLeft': 3,
      'drawNumber': '102',
    },
    {
      'denomination': 'Rs. 1500',
      'drawDate': 'January 17, 2026',
      'city': 'Lahore',
      'status': 'today',
      'daysLeft': 0,
      'drawNumber': '101',
    },
    {
      'denomination': 'Rs. 200',
      'drawDate': 'January 15, 2026',
      'city': 'Hyderabad',
      'status': 'completed',
      'daysLeft': -2,
      'drawNumber': '100',
    },
    {
      'denomination': 'Rs. 750',
      'drawDate': 'January 10, 2026',
      'city': 'Karachi',
      'status': 'completed',
      'daysLeft': -7,
      'drawNumber': '99',
    },
    {
      'denomination': 'Rs. 25000',
      'drawDate': 'February 01, 2026',
      'city': 'Islamabad',
      'status': 'upcoming',
      'daysLeft': 15,
      'drawNumber': '103',
    },
    {
      'denomination': 'Rs. 7500',
      'drawDate': 'February 15, 2026',
      'city': 'Multan',
      'status': 'upcoming',
      'daysLeft': 29,
      'drawNumber': '104',
    },
    {
      'denomination': 'Rs. 100',
      'drawDate': 'December 28, 2025',
      'city': 'Peshawar',
      'status': 'completed',
      'daysLeft': -20,
      'drawNumber': '98',
    },
  ];

  List<Map<String, dynamic>> get filteredDraws {
    if (_selectedDenomination == 'All') return allDraws;
    return allDraws.where((draw) => draw['denomination'] == _selectedDenomination).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildDenominationFilter(),
          Expanded(child: _buildDrawsList()),
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

                const Icon(Icons.trending_up_rounded, color: Colors.white, size: 28),

                const SizedBox(width: 12),

                const Text(
                  'Prize Bond Draws',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text('View all prize bond draw schedules', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDenominationFilter() {
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
              itemCount: denominations.length,
              itemBuilder: (context, index) {
                final denom = denominations[index];
                final isSelected = _selectedDenomination == denom;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(denom),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedDenomination = denom),
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

  Widget _buildDrawsList() {
    if (filteredDraws.isEmpty) {
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
            const Text('Try selecting a different denomination', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredDraws.length,
      itemBuilder: (context, index) {
        final draw = filteredDraws[index];
        return _buildDrawCard(draw);
      },
    );
  }

  Widget _buildDrawCard(Map<String, dynamic> draw) {
    final status = draw['status'];
    final isUpcoming = status == 'upcoming';
    final isToday = status == 'today';
    final isCompleted = status == 'completed';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isToday) {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'DRAW TODAY';
      statusIcon = Icons.event_available;
    } else if (isUpcoming) {
      statusColor = const Color(0xFF10B981);
      statusText = '${draw['daysLeft']} DAYS LEFT';
      statusIcon = Icons.access_time;
    } else {
      statusColor = const Color(0xFF6B7280);
      statusText = 'COMPLETED';
      statusIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isToday ? Border.all(color: const Color(0xFFF59E0B), width: 2) : null,
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
                            draw['drawDate'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            statusText,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isUpcoming || isToday) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _setReminder(draw),
                          icon: const Icon(Icons.notifications_outlined, size: 16),
                          label: const Text('Set Reminder'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2D5BFF),
                            side: const BorderSide(color: Color(0xFF2D5BFF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showDrawDetails(draw),
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D5BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isCompleted) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _downloadPDF(draw),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download PDF'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF2D5BFF)),
                      ),
                      InkWell(
                        onTap: () => _showDrawDetails(draw),
                        child: const Row(
                          children: [
                            Text(
                              'View Results',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2D5BFF)),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF2D5BFF)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setReminder(Map<String, dynamic> draw) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder set for ${draw['denomination']} draw on ${draw['drawDate']}'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadPDF(Map<String, dynamic> draw) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading PDF: ${draw['denomination']} Draw #${draw['drawNumber']}'),
        backgroundColor: const Color(0xFF2D5BFF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDrawDetails(Map<String, dynamic> draw) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Draw #${draw['drawNumber']} • ${draw['drawDate']}',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow('Draw Date', draw['drawDate'], Icons.calendar_today),
                    _buildDetailRow('Draw Location', draw['city'], Icons.location_on),
                    _buildDetailRow('Draw Number', '#${draw['drawNumber']}', Icons.numbers),
                    const SizedBox(height: 24),
                    if (draw['status'] == 'upcoming' || draw['status'] == 'today') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _setReminder(draw);
                          },
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Enable Draw Reminder'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D5BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (draw['status'] == 'completed') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _downloadPDF(draw);
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download Full Results PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D5BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
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
