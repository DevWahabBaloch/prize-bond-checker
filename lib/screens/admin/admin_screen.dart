import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prize_bond_checking_app/services/account_credentials.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.access});

  final AdminAccess access;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _busyAccountId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  List<AccountProfile> _pendingUsers(List<AccountProfile> accounts) {
    return accounts.where((user) => !user.isApproved && !user.isRejected).toList()
      ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
  }

  List<AccountProfile> _approvedUsers(List<AccountProfile> accounts) {
    return accounts.where((user) => user.isApproved).toList()..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
  }

  Future<void> _approve(AccountProfile user) async {
    if (_busyAccountId != null) return;
    setState(() => _busyAccountId = user.id);
    try {
      await widget.access.approve(user.id);
      if (!mounted || !widget.access.isOpen) return;
      _message('${user.fullName} approved.');
      _tabController.animateTo(1);
    } on AccountException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Could not approve this account.');
    } finally {
      if (mounted) setState(() => _busyAccountId = null);
    }
  }

  Future<void> _reject(AccountProfile user) async {
    if (_busyAccountId != null) return;
    setState(() => _busyAccountId = user.id);
    try {
      await widget.access.reject(user.id);
      if (mounted) _message('${user.fullName} declined. The account can be reviewed again.');
    } on AccountException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Could not decline this account.');
    } finally {
      if (mounted) setState(() => _busyAccountId = null);
    }
  }

  Future<void> _resetPin(AccountProfile user) async {
    if (_busyAccountId != null) return;
    var pin = '';
    var confirmation = '';
    final digits = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)];
    final newPin = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Reset account PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Have ${user.fullName} enter a new four-digit PIN.'),
              TextField(
                obscureText: true,
                inputFormatters: digits,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New PIN'),
                onChanged: (value) => update(() => pin = value),
              ),
              TextField(
                obscureText: true,
                inputFormatters: digits,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                onChanged: (value) => update(() => confirmation = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: pin.length == 4 && pin == confirmation ? () => Navigator.pop(context, pin) : null,
              child: const Text('Reset PIN'),
            ),
          ],
        ),
      ),
    );
    if (newPin == null || !mounted || _busyAccountId != null) return;
    setState(() => _busyAccountId = user.id);
    try {
      try {
        await widget.access.resetPin(user.id, newPin);
      } on CredentialException catch (error) {
        if (!mounted || !widget.access.isOpen) return;
        if (!error.canRecover) rethrow;
        final recover = await _confirmRecovery(user, error);
        if (!recover || !mounted || !widget.access.isOpen) return;
        await widget.access.resetPin(user.id, newPin, recover: true);
      }
      if (mounted && widget.access.isOpen) _message('PIN updated for ${user.fullName}.');
    } on CredentialException catch (error) {
      if (mounted && widget.access.isOpen) _message(error.message);
    } on AccountException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Could not reset the PIN.');
    } finally {
      if (mounted) setState(() => _busyAccountId = null);
    }
  }

  Future<bool> _confirmRecovery(AccountProfile user, CredentialException error) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Recover account PIN'),
            content: Text(
              '${error.message} Verify the identity of ${user.fullName} (${user.email}) before continuing. '
              'Recovery sets a new PIN for this account and preserves its records. Each other affected account needs its own recovery.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Recover PIN')),
            ],
          ),
        ) ??
        false;
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildApprovedTab(List<AccountProfile> approved) {
    return approved.isEmpty
        ? const _EmptyState(icon: Icons.people_outline, message: 'No approved users yet')
        : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: approved.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ApprovedCard(user: approved[i], onResetPin: () => _resetPin(approved[i])),
          );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.access.accounts;
    final pending = _pendingUsers(accounts);
    final approved = _approvedUsers(accounts);
    final rejected = accounts.where((user) => user.isRejected).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2D5BFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2D5BFF),
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Approved (${approved.length})'),
            Tab(text: 'Declined (${rejected.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          pending.isEmpty
              ? const _EmptyState(icon: Icons.check_circle_outline, message: 'No pending registrations')
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _PendingCard(
                    user: pending[i],
                    isBusy: _busyAccountId == pending[i].id,
                    onApprove: () => _approve(pending[i]),
                    onReject: () => _reject(pending[i]),
                  ),
                ),
          _buildApprovedTab(approved),
          rejected.isEmpty
              ? const _EmptyState(icon: Icons.person_off_outlined, message: 'No declined registrations')
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: rejected.length,
                  itemBuilder: (context, index) {
                    final user = rejected[index];
                    return ListTile(
                      title: Text(user.fullName),
                      subtitle: Text(user.email),
                      trailing: TextButton(
                        onPressed: _busyAccountId == null ? () => _approve(user) : null,
                        child: const Text('Approve'),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final AccountProfile user;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({required this.user, required this.isBusy, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFFBBF24).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
                    ),
                    Text(user.email, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Tag(Icons.location_city_outlined, user.city.isNotEmpty ? user.city : 'N/A'),
              _Tag(Icons.calendar_today_outlined, _formatDate(user.registeredAt)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      side: BorderSide(color: Colors.red[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isBusy ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovedCard extends StatelessWidget {
  final AccountProfile user;

  final VoidCallback onResetPin;

  const _ApprovedCard({required this.user, required this.onResetPin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937)),
                ),
                Text(user.email, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [_Tag(Icons.location_city_outlined, user.city.isNotEmpty ? user.city : 'N/A')],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reset PIN',
            onPressed: onResetPin,
            icon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF2D5BFF)),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
