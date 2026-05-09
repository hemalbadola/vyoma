import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/user_service.dart';
import '../../core/friend_service.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchResultUid;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResultUid = null;
      _searchError = null;
    });

    try {
      final friendService = context.read<FriendService>();
      final uid = await friendService.resolveUsernameToUid(query);
      if (uid != null) {
        setState(() => _searchResultUid = uid);
      } else {
        setState(() => _searchError = "No agent found with that designation.");
      }
    } catch (e) {
      setState(() => _searchError = "Error probing network.");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendInvite(String targetUid) async {
    try {
      await context.read<FriendService>().sendInvite(targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transmission sent. Protocol pending.'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to establish link.'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('EXPAND CIRCLE', style: GoogleFonts.inter(letterSpacing: 2, fontSize: 14)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF06B6D4),
          labelColor: const Color(0xFF06B6D4),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "SEARCH"),
            Tab(text: "MY CODE"),
            Tab(text: "SCAN"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildMyCodeTab(),
          _buildScanTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter exact username',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1A1A24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Color(0xFF06B6D4)),
                onPressed: _performSearch,
              ),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 32),
          if (_isSearching)
            const CircularProgressIndicator(color: Color(0xFF06B6D4))
          else if (_searchError != null)
            Text(_searchError!, style: const TextStyle(color: Colors.redAccent))
          else if (_searchResultUid != null)
            _buildUserCard(_searchResultUid!)
        ],
      ),
    );
  }

  Widget _buildUserCard(String uid) {
    // Fetch profile dynamically
    return StreamBuilder(
      stream: context.read<FriendService>().streamProfiles([uid]),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final profile = snapshot.data!.first;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF7C3AED),
                child: Text(profile.displayName[0].toUpperCase()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('@${profile.username}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    if (profile.tagline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(profile.tagline, style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
                    ]
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                onPressed: () => _sendInvite(uid),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyCodeTab() {
    final user = context.watch<UserService>().currentProfile;
    if (user == null) return const Center(child: Text("Initializing...", style: TextStyle(color: Colors.white)));
    
    final link = 'https://vyoma.app/user/${user.username}';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text('@${user.username}', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(user.tagline, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            icon: const Icon(Icons.share),
            label: const Text("Share Link"),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(text: 'Join my accountability circle on Vyoma: $link'),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Text("Scan a Vyoma code to initiate a link.", style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null && barcode.rawValue!.contains('vyoma.app/user/')) {
                      final parts = barcode.rawValue!.split('/user/');
                      if (parts.length > 1) {
                         // Found it. 
                         final username = parts[1];
                         _searchController.text = username;
                         _tabController.animateTo(0);
                         _performSearch();
                         break;
                      }
                    }
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
