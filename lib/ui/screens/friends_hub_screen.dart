import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/user_service.dart';
import '../../core/friend_service.dart';
import '../../core/cofocus_service.dart';
import '../../core/accountability_service.dart';
import '../../core/ping_service.dart';
import '../../core/models/pact.dart';
import 'add_friend_screen.dart';

class FriendsHubScreen extends StatelessWidget {
  const FriendsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('CIRCLE', style: GoogleFonts.inter(letterSpacing: 2, fontSize: 14)),
        actions: [
          _buildInviteBadge(context),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddFriendScreen()));
            },
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildIntentionHeader(context)),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text("ACTIVE LINKUPS", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
            )
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildActiveSessionsStrip(context)),
          
          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text("THE CIRCLE", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
            )
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          _buildFriendList(context),
        ],
      ),
    );
  }

  Widget _buildInviteBadge(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: context.watch<FriendService>().getIncomingInvitesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        return Center(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${snapshot.data!.length} Pending",
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntentionHeader(BuildContext context) {
    final user = context.watch<UserService>().currentProfile;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2A2A35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Color(0xFF06B6D4), size: 20),
                const SizedBox(width: 8),
                Text("TODAY's INTENTION", style: GoogleFonts.inter(color: const Color(0xFF06B6D4), fontSize: 12, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              user.currentIntention?.isNotEmpty == true ? user.currentIntention! : "Set an intention for the circle...",
              style: GoogleFonts.spectral(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showIntentionDialog(context),
                icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
                label: const Text("Refine", style: TextStyle(color: Colors.white54)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showIntentionDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text("Set Intention", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "I am focusing on...",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                context.read<UserService>().setIntention(ctrl.text);
              }
              Navigator.pop(context);
            },
            child: const Text("BROADCAST", style: TextStyle(color: Color(0xFF06B6D4))),
          ),
        ],
      )
    );
  }

  Widget _buildActiveSessionsStrip(BuildContext context) {
    return StreamBuilder<List<Pact>>(
      stream: context.watch<CoFocusService>().streamActivePacts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                Container(
                  width: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Waiting for signals...", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      SizedBox(height: 8),
                      Text("No active pacts right now.", style: TextStyle(color: Colors.white38, fontSize: 14)),
                    ],
                  ),
                )
              ],
            ),
          );
        }

        final pacts = snapshot.data!;
        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: pacts.length,
            itemBuilder: (context, index) {
              final pact = pacts[index];
              return Container(
                width: 250,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(pact.status == PactStatus.pending ? "WAITING FOR ACCEPT" : "ACTIVE PACT", style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(pact.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Target: ${pact.targetMinutes}m", style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendList(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: context.watch<FriendService>().getAcceptedFriendUidsStream(),
      builder: (context, uidsSnap) {
        if (!uidsSnap.hasData || uidsSnap.data!.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text("Your circle is quiet. Invite an agent.", style: TextStyle(color: Colors.white38))),
            ),
          );
        }

        return StreamBuilder(
          stream: context.read<FriendService>().streamProfiles(uidsSnap.data!),
          builder: (context, profileSnap) {
            if (!profileSnap.hasData) return const SliverToBoxAdapter(child: SizedBox());
            final profiles = profileSnap.data ?? [];
            
            return FutureBuilder(
              future: context.read<AccountabilityService>().getWeeklyActivitiesForUsers(uidsSnap.data!),
              builder: (context, accSnap) {
                final activities = accSnap.data ?? [];
                
                // Tally points
                final pointsMap = <String, int>{};
                for (final act in activities) {
                  pointsMap[act.userId] = (pointsMap[act.userId] ?? 0) + act.points;
                }

                // Sort profiles by point descending
                final sortedProfiles = List.of(profiles)..sort((a, b) {
                  final pA = pointsMap[a.uid] ?? 0;
                  final pB = pointsMap[b.uid] ?? 0;
                  return pB.compareTo(pA);
                });

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final profile = sortedProfiles[index];
                      final points = pointsMap[profile.uid] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A24),
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFF4F46E5),
                                      child: Text(profile.displayName[0].toUpperCase()),
                                    ),
                                    if (profile.lastSeenAt != null && 
                                        DateTime.now().difference(profile.lastSeenAt!).inMinutes < 3)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF1A1A24), width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(profile.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          _buildPresenceLabel(profile.lastSeenAt),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(profile.currentIntention ?? "Building in silence.", 
                                        style: GoogleFonts.spectral(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("$points", style: GoogleFonts.robotoMono(color: const Color(0xFF06B6D4), fontSize: 16, fontWeight: FontWeight.bold)),
                                    Text("pts/wk", style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                                  ],
                                )
                              ],
                            ),
                            if (profile.activeTasks.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("ACTIVE MISSIONS", style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, letterSpacing: 1.2)),
                                    const SizedBox(height: 8),
                                    ...profile.activeTasks.map((taskTitle) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 12),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(taskTitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                          ),
                                          GestureDetector(
                                            onTap: () async {
                                              try {
                                                await context.read<PingService>().sendPing(toUid: profile.uid, taskTitle: taskTitle);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pinged ${profile.displayName} to focus.')));
                                                }
                                              } catch(e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transmission failed')));
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.5)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.notifications_active, color: Color(0xFF818CF8), size: 10),
                                                  SizedBox(width: 4),
                                                  Text("NUDGE", style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      );
                    },
                    childCount: sortedProfiles.length,
                  ),
                );
              }
            );
          },
        );
      },
    );
  }

  Widget _buildPresenceLabel(DateTime? lastSeen) {
    if (lastSeen == null) return const SizedBox();
    final diff = DateTime.now().difference(lastSeen);
    
    if (diff.inMinutes < 3) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text("ONLINE NOW", style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.bold)),
      );
    }
    
    String label;
    if (diff.inMinutes < 60) {
      label = "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      label = "${diff.inHours}h ago";
    } else {
      label = "${diff.inDays}d ago";
    }

    return Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10));
  }
}
