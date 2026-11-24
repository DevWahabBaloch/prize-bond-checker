import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prize_bond_checking_app/models/bond_model.dart';
import 'package:prize_bond_checking_app/models/check_record_model.dart';
import 'package:prize_bond_checking_app/screens/check_history_screen.dart';
import 'package:prize_bond_checking_app/screens/my_bonds_screen.dart';
import 'package:prize_bond_checking_app/screens/history_screen.dart';
import 'package:prize_bond_checking_app/screens/auth/landing_screen.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/draw_reminder_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _storage = AuthService.requireStorage();

  bool notificationsEnabled = true;
  bool winAlertsEnabled = true;
  bool drawRemindersEnabled = true;
  bool marketplaceAlertsEnabled = false;
  bool _savingNotificationPreference = false;
  bool _notificationPreferencesLoaded = false;

  String _userName = 'User';
  String _email = '';
  String _phone = '';
  String _city = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    _loadUserProfile();
    await _loadNotifPrefs();
  }

  void _loadUserProfile() {
    final profile = AuthService.profile(_storage);
    if (mounted) {
      setState(() {
        _userName = profile.fullName;
        _email = profile.email;
        _phone = profile.mobile;
        _city = profile.city;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotifPrefs() async {
    final Map<String, bool> prefs;
    try {
      prefs = await AuthService.getAllNotifPrefs(_storage);
    } on AccountException {
      return;
    }
    if (mounted && AuthService.canUseStorage(_storage)) {
      setState(() {
        notificationsEnabled = prefs['all'] ?? true;
        winAlertsEnabled = prefs['win'] ?? true;
        drawRemindersEnabled = prefs['draw'] ?? true;
        marketplaceAlertsEnabled = prefs['marketplace'] ?? false;
        _notificationPreferencesLoaded = true;
      });
    }
  }

  Future<void> _saveNotifPref(String key, bool value) async {
    if (!_notificationPreferencesLoaded || _savingNotificationPreference || !AuthService.canUseStorage(_storage)) return;
    setState(() => _savingNotificationPreference = true);
    try {
      await AuthService.setNotifPref(_storage, key, value);
      await _loadNotifPrefs();
      if ((key == 'all' || key == 'draw') && AuthService.canUseStorage(_storage)) {
        final reconciled = await DrawReminderService().reconcile(_storage);
        if (!reconciled && mounted && AuthService.canUseStorage(_storage)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preference saved. Could not confirm pending reminders. Check the draw reminder to retry.'),
            ),
          );
        }
      }
    } on AccountException catch (error) {
      if (mounted && AuthService.canUseStorage(_storage)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _savingNotificationPreference = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D5BFF)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildProfileCard(),
                  const SizedBox(height: 20),
                  _buildStatsSection(),
                  const SizedBox(height: 20),
                  _buildMenuSection(),
                  const SizedBox(height: 20),
                  _buildNotificationSettings(),
                  const SizedBox(height: 20),
                  _buildLogoutButton(),
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
      ),
      padding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Row(
          children: [
            const Icon(Icons.person_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            const Text(
              'My Profile',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: _showEditProfileDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final initials = _userName.isNotEmpty ? _userName.substring(0, 1).toUpperCase() : 'U';

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
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF2D5BFF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _userName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 4),
            Text(_email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 16, color: Color(0xFF2D5BFF)),
                  SizedBox(width: 4),
                  Text(
                    'Verified Account',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2D5BFF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(icon: Icons.phone, label: 'Phone', value: _phone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoTile(icon: Icons.location_on, label: 'City', value: _city),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2D5BFF)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return ValueListenableBuilder(
      valueListenable: _storage.bonds,
      builder: (context, PrivateRecords<Bond> bondsBox, _) {
        return ValueListenableBuilder(
          valueListenable: _storage.history,
          builder: (context, PrivateRecords<CheckRecord> checksBox, _) {
            final savedBonds = bondsBox.length;
            final checks = checksBox.length;
            final wins = bondsBox.values.where((b) => b.status == 'Won').length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFFAF5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Statistics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('$savedBonds', 'Saved Bonds', Icons.bookmark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('$checks', 'Checks', Icons.search)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('$wins', 'Wins', Icons.emoji_events)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String count, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF2D5BFF)),
          const SizedBox(height: 8),
          Text(
            count,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            _buildMenuItem(
              icon: Icons.bookmark_rounded,
              title: 'My Saved Bonds',
              subtitle: 'View and manage your bonds',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBondsScreen())),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.history_rounded,
              title: 'Draw History',
              subtitle: 'Browse past and upcoming draws',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.manage_search_rounded,
              title: 'Check History',
              subtitle: 'View all your past bond checks',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckHistoryScreen())),
            ),
            _buildDivider(),
            _buildMenuItem(
              icon: Icons.download_done_rounded,
              title: 'Downloaded Results',
              subtitle: 'Offline draw lists saved on device',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadedResultsScreen())),
            ),
            _buildDivider(),

            _buildMenuItem(
              icon: Icons.info_outline_rounded,
              title: 'About This App',
              subtitle: 'Data disclaimer & version info',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Prize Bond Checker'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DATA NOTICE: Draw data is simulated for demonstration '
                            'purposes as approved by the project supervisor '
                            '(Saeed Nasir). No official National Savings API is used.',
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Supervisor: Saeed Nasir\n'
                            'Institution: Virtual University of Pakistan',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notifications_rounded, color: Color(0xFF2D5BFF), size: 24),
                SizedBox(width: 12),
                Text(
                  'Device Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSwitchTile(
              title: 'All Device Alerts',
              subtitle: 'In-app inbox notices are still recorded when alerts are off.',
              value: notificationsEnabled,
              onChanged: (value) => _saveNotifPref('all', value),
              enabled: _notificationPreferencesLoaded && !_savingNotificationPreference,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Win Alerts',
              subtitle: 'Device alerts for matching bonds',
              value: winAlertsEnabled,
              onChanged: (value) => _saveNotifPref('win', value),
              enabled: _notificationPreferencesLoaded && notificationsEnabled && !_savingNotificationPreference,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Draw Alerts and Reminders',
              subtitle: 'Device alerts for sample draws, results, and scheduled reminders',
              value: drawRemindersEnabled,
              onChanged: (value) => _saveNotifPref('draw', value),
              enabled: _notificationPreferencesLoaded && notificationsEnabled && !_savingNotificationPreference,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Marketplace Alerts',
              subtitle: 'Unavailable in the offline demo',
              value: marketplaceAlertsEnabled,
              onChanged: null,
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: enabled ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null, activeColor: const Color(0xFF2D5BFF)),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _showLogoutDialog,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Color(0xFFE5E7EB)),
    );
  }

  Future<void> _showEditProfileDialog() async {
    var name = _userName;
    var email = _email;
    var phone = _phone;
    var city = _city;
    String? error;
    var saving = false;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _profileField('Full Name', Icons.person, name, (value) => name = value),
                const SizedBox(height: 16),
                _profileField('Email', Icons.email, email, (value) => email = value),
                const SizedBox(height: 16),
                _profileField('Phone', Icons.phone, phone, (value) => phone = value),
                const SizedBox(height: 16),
                _profileField('City', Icons.location_on, city, (value) => city = value),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      try {
                        await AuthService.saveUserProfile(storage: _storage, email: email, name: name, city: city, phone: phone);
                        if (context.mounted && AuthService.canUseStorage(_storage)) Navigator.pop(context, true);
                      } on AccountException catch (failure) {
                        if (context.mounted) update(() => error = failure.message);
                      } catch (_) {
                        if (context.mounted) update(() => error = 'Could not save these changes.');
                      } finally {
                        if (context.mounted) update(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D5BFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (updated == true && mounted && AuthService.canUseStorage(_storage)) {
      _loadUserProfile();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
    }
  }

  Widget _profileField(String label, IconData icon, String value, ValueChanged<String> onChanged) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await AuthService.logout();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Signed out. The account may still be selected after restarting the app.')),
                  );
                }
              }
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  this.context,
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class DownloadedResultsScreen extends StatefulWidget {
  const DownloadedResultsScreen({super.key});

  @override
  State<DownloadedResultsScreen> createState() => _DownloadedResultsScreenState();
}

class _DownloadedResultsScreenState extends State<DownloadedResultsScreen> {
  List<File> _pdfFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final all = dir.listSync();
    final pdfs = all.whereType<File>().where((f) => f.path.endsWith('.pdf')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (mounted) {
      setState(() {
        _pdfFiles = pdfs;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFile(File file) async {
    await file.delete();
    await _loadFiles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted'), backgroundColor: Color(0xFFEF4444), behavior: SnackBarBehavior.floating),
      );
    }
  }

  String _friendlyName(File file) {
    final name = file.uri.pathSegments.last.replaceAll('.pdf', '');
    return name.replaceAll('Draw_', 'Draw #').replaceAll('__', ' ').replaceAll('_', ' • ').replaceAll('Rs  ', 'Rs. ');
  }

  String _fileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _savedOn(File file) {
    final dt = file.lastModifiedSync();
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D5BFF)))
                : _pdfFiles.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadFiles,
                    color: const Color(0xFF2D5BFF),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _pdfFiles.length,
                      itemBuilder: (context, index) => _buildFileCard(_pdfFiles[index]),
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
      padding: const EdgeInsets.fromLTRB(8, 50, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Downloaded Results',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.offline_pin, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${_pdfFiles.length} file${_pdfFiles.length != 1 ? 's' : ''} available offline',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(File file) {
    return Dismissible(
      key: Key(file.path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete File'),
            content: const Text('Remove this PDF from your device?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteFile(file),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => OpenFile.open(file.path),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'PDF',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _friendlyName(file),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Text(_savedOn(file), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            const SizedBox(width: 12),
                            const Icon(Icons.storage, size: 12, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Text(_fileSize(file), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                          child: const Text(
                            '✓ Available Offline',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 18, color: Color(0xFF2D5BFF)),
                ],
              ),
            ),
          ),
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
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)]),
              borderRadius: BorderRadius.circular(45),
            ),
            child: const Icon(Icons.download_outlined, size: 44, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No downloads yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Download draw result PDFs from Draw History for offline checking.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Go to Draw History'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
