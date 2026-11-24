import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prize_bond_checking_app/config/app_config.dart';
import 'package:prize_bond_checking_app/services/auth_service.dart';
import 'package:prize_bond_checking_app/services/marketplace_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late final _marketplace = MarketplaceService();
  late final _account = AuthService.requireStorage();
  final _removing = <String>{};

  bool get _active => mounted && AuthService.canUseStorage(_account);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Marketplace', style: TextStyle(color: Color(0xFF1F2937))),
      ),
      body: ListenableBuilder(
        listenable: _marketplace.changes,
        builder: (context, _) {
          final listings = _marketplace.listings(_account);
          return listings.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: listings.length,
                  itemBuilder: (context, index) => _buildListingCard(listings[index]),
                );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPostListingDialog,
        backgroundColor: const Color(0xFF2D5BFF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post Listing', style: TextStyle(color: Colors.white)),
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
            child: const Icon(Icons.storefront_outlined, size: 64, color: Color(0xFF2D5BFF)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No listings yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to post a prize bond for sale',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(MarketplaceListing listing) {
    final initials = listing.sellerName.isNotEmpty ? listing.sellerName[0].toUpperCase() : '?';
    final postedAgo = _timeAgo(listing.postedDate);

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
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF2D5BFF), Color(0xFF8B5CF6)]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.sellerName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              listing.location,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(postedAgo, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                        ],
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
                gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFFAF5FF)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Denomination', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            const SizedBox(height: 4),
                            Text(
                              listing.denomination,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Quantity', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            const SizedBox(height: 4),
                            Text(
                              '${listing.quantity} bonds',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('Asking Price', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      ),
                      Flexible(
                        child: Text(
                          'Rs. ${listing.price.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showContactDialog(listing),
                    icon: const Icon(Icons.contact_page_outlined, size: 18),
                    label: const Text('Contact Seller'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (listing.canRemove) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Remove listing',
                    onPressed: _removing.contains(listing.id) ? null : () => _removeListing(listing),
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContactDialog(MarketplaceListing listing) async {
    if (!_active) return;
    final number = listing.sellerPhone;
    final target = await showDialog<Uri>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contact Seller'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(listing.sellerName),
            const SizedBox(height: 12),
            if (number.isEmpty)
              const Text('The seller did not include a phone number.')
            else ...[
              Text('+92 $number'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, Uri(scheme: 'tel', path: '+92$number')),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call Seller'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, Uri.https('wa.me', '/92$number')),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
    if (target == null || !_active) return;
    var launched = false;
    try {
      launched = await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (_) {
      // The device can decline the request or have no matching app.
    }
    if (!launched) _showMessage('Could not open the contact app on this device.');
  }

  Future<void> _removeListing(MarketplaceListing listing) async {
    if (!_active || _removing.contains(listing.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Listing'),
        content: const Text('Remove this listing from the marketplace?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !_active || _removing.contains(listing.id)) return;
    setState(() => _removing.add(listing.id));
    try {
      await _marketplace.remove(_account, listing.id);
      _showMessage('Listing removed.');
    } on MarketplaceException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not remove the listing. Please try again.');
    } finally {
      if (mounted) setState(() => _removing.remove(listing.id));
    }
  }

  Future<void> _showPostListingDialog() async {
    if (!_active) return;
    final posted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PostListingDialog(marketplace: _marketplace, account: _account),
    );
    if (posted == true) _showMessage('Listing posted successfully.');
  }

  void _showMessage(String message) {
    if (_active) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

class _PostListingDialog extends StatefulWidget {
  const _PostListingDialog({required this.marketplace, required this.account});

  final MarketplaceService marketplace;
  final AccountStorage account;

  @override
  State<_PostListingDialog> createState() => _PostListingDialogState();
}

class _PostListingDialogState extends State<_PostListingDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  String _denomination = AppConfig.defaultDenomination;
  bool _posting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_posting || !AuthService.canUseStorage(widget.account)) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await widget.marketplace.post(
        widget.account,
        name: _name.text,
        phone: _phone.text,
        location: _location.text,
        denomination: _denomination,
        quantity: _quantity.text,
        price: _price.text,
      );
      if (mounted && AuthService.canUseStorage(widget.account)) Navigator.pop(context, true);
    } on MarketplaceException catch (error) {
      _postFailed(error.message);
    } catch (_) {
      _postFailed('Could not post the listing. Your draft is still here. Please try again.');
    }
  }

  void _postFailed(String message) {
    if (!mounted || !AuthService.canUseStorage(widget.account)) return;
    setState(() {
      _posting = false;
      _error = message;
    });
  }

  InputDecoration _field(String label, [IconData? icon]) => InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_posting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Post New Listing'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Signed-in accounts on this device can see this listing and any contact details you add.'),
            const SizedBox(height: 12),
            TextField(controller: _name, enabled: !_posting, decoration: _field('Your Name', Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              enabled: !_posting,
              keyboardType: TextInputType.phone,
              decoration: _field('Phone Number (optional)', Icons.phone_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              enabled: !_posting,
              decoration: _field('City / Location', Icons.location_on_outlined),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _denomination,
              isExpanded: true,
              decoration: _field('Denomination'),
              items: AppConfig.denominations
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: _posting ? null : (value) => _denomination = value ?? _denomination,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantity,
              enabled: !_posting,
              keyboardType: TextInputType.number,
              decoration: _field('Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              enabled: !_posting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _field('Asking Price per bond (Rs.)'),
            ),
          ],
        ),
        actions: [
          if (_error case final error?)
            Semantics(
              liveRegion: true,
              child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextButton(onPressed: _posting ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _posting ? null : _post,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D5BFF)),
            child: Text(_posting ? 'Posting…' : 'Post Listing', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
