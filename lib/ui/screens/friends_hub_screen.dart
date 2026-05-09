import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/user_service.dart';
import '../../core/friend_service.dart';
import '../../core/cofocus_service.dart';
import '../../core/accountability_service.dart';
import '../../core/ping_service.dart';
import '../../core/models/pact.dart';
import '../../core/services/focus_ranking_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/vyoma_tokens.dart' show VyType, VyColors;
import '../../core/widgets/vy_empty_state.dart';
import '../../core/widgets/vy_logo.dart';
import '../../core/widgets/vy_section_label.dart';
import '../../features/circle/presentation/widgets/focus_leaderboard.dart';
import '../../features/mirror/presentation/screens/mirror_sessions_screen.dart';
import '../../features/witness/data/witness_models.dart';
import '../../features/witness/domain/witness_service.dart';
import '../../features/witness/presentation/screens/create_vow_screen.dart';
import '../../features/witness/presentation/screens/vow_detail_screen.dart';
import '../../features/witness/presentation/widgets/vow_card.dart';
import 'add_friend_screen.dart';

class FriendsHubScreen extends StatelessWidget {
  const FriendsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header — wordmark-style "circle", lowercase Cormorant. The page is the title.
            // Back button surfaces only when this screen was pushed (e.g. from Today),
            // so opening Circle as a tab doesn't show a redundant back arrow.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 20, 8),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: VyColors.textMuted, size: 18),
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text('circle',
                          style: VyType.title.copyWith(letterSpacing: 0.5)),
                    ),
                    _buildInviteBadge(context),
                    IconButton(
                      icon: const Icon(Icons.compare_arrows_rounded,
                          color: VyColors.textMuted, size: 20),
                      tooltip: 'Mirror Sessions',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MirrorSessionsScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add_outlined,
                          color: VyColors.textMuted, size: 20),
                      tooltip: 'Invite',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // The active vow — at most one in v0. Renders the card if held,
            // an outlined "take a vow" prompt otherwise.
            SliverToBoxAdapter(child: _buildActiveVow(context)),

            // Active pact strip — only renders when something is live. Empty placeholder removed.
            SliverToBoxAdapter(child: _buildActiveSessionsStrip(context)),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: const VySectionLabel('CO-TRAVELERS'),
              ),
            ),

            _buildFriendList(context),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: const VySectionLabel('THIS WEEK'),
              ),
            ),
            SliverToBoxAdapter(child: _buildFocusLeaderboard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Scores reset every Monday.',
                  style: VyType.caption,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusLeaderboard(BuildContext context) {
    final currentUserId =
        context.watch<UserService>().currentProfile?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: StreamBuilder(
        stream: context.read<FocusRankingService>().watchWeeklyRanking(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const [];
          if (entries.length <= 1) {
            return VyEmptyState(
              headline: 'Invite friends to compete',
              body: 'See who protects their focus the best each week.',
              ctaLabel: 'Invite',
              onCta: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                );
              },
            );
          }
          return FocusLeaderboard(
            entries: entries,
            currentUserId: currentUserId,
          );
        },
      ),
    );
  }

  Widget _buildInviteBadge(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: context.watch<FriendService>().getIncomingInvitesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildIntentionHeader(BuildContext context) {
    final user = context.watch<UserService>().currentProfile;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: AppColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "TODAY's INTENTION",
                  style: GoogleFonts.inter(
                    color: AppColors.gold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              user.currentIntention?.isNotEmpty == true
                  ? user.currentIntention!
                  : "Set an intention for the circle...",
              style: const TextStyle(
                fontFamily: 'CormorantGaramond',
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showIntentionDialog(context),
                icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
                label: const Text(
                  "Refine",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showIntentionDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text(
          "Set Intention",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "I am focusing on...",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                context.read<UserService>().setIntention(ctrl.text);
              }
              Navigator.pop(context);
            },
            child: const Text(
              "BROADCAST",
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  // Renders the user's single active vow as a tappable card, or an outlined
  // prompt when none is held. Hidden entirely if the user has no friends yet.
  Widget _buildActiveVow(BuildContext context) {
    final witness = context.read<WitnessService>();
    return StreamBuilder<WitnessVow?>(
      stream: witness.streamActiveVow(),
      builder: (context, snap) {
        final vow = snap.data;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: vow != null
              ? VowCard(
                  vow: vow,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VowDetailScreen(vowId: vow.id),
                      ),
                    );
                  },
                )
              : _VowPrompt(),
        );
      },
    );
  }

  Widget _buildActiveSessionsStrip(BuildContext context) {
    return StreamBuilder<List<Pact>>(
      stream: context.watch<CoFocusService>().streamActivePacts(),
      builder: (context, snapshot) {
        // No empty placeholder — clutter. Hide the strip when nothing is live.
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final pacts = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pacts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final pact = pacts[index];
                final pending = pact.status == PactStatus.pending;
                return Container(
                  width: 240,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: pending ? AppColors.border : AppColors.goldDim,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pending ? 'AWAITING ACCEPT' : 'IN SESSION',
                        style: VyType.sectionLabel.copyWith(
                          color: pending ? AppColors.textMuted : AppColors.gold,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        pact.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VyType.heading.copyWith(fontSize: 16),
                      ),
                      Text(
                        '${pact.targetMinutes}m focus',
                        style: VyType.caption,
                      ),
                    ],
                  ),
                );
              },
            ),
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
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    children: [
                      const VyMark(size: 56),
                      const SizedBox(height: 28),
                      Text(
                        'solitude is also a circle.',
                        textAlign: TextAlign.center,
                        style: VyType.heading.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'invite a co-traveler to walk beside you.',
                        textAlign: TextAlign.center,
                        style: VyType.bodyMuted,
                      ),
                      const SizedBox(height: 28),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddFriendScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.goldDim, width: 1),
                          foregroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'INVITE',
                          style: VyType.accent.copyWith(letterSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return StreamBuilder(
          stream: context.read<FriendService>().streamProfiles(uidsSnap.data!),
          builder: (context, profileSnap) {
            if (!profileSnap.hasData) {
              return const SliverToBoxAdapter(child: SizedBox());
            }
            final profiles = profileSnap.data ?? [];

            return FutureBuilder(
              future: context
                  .read<AccountabilityService>()
                  .getWeeklyActivitiesForUsers(uidsSnap.data!),
              builder: (context, accSnap) {
                final activities = accSnap.data ?? [];

                // Tally points
                final pointsMap = <String, int>{};
                for (final act in activities) {
                  pointsMap[act.userId] =
                      (pointsMap[act.userId] ?? 0) + act.points;
                }

                // Sort profiles by point descending
                final sortedProfiles = List.of(profiles)
                  ..sort((a, b) {
                    final pA = pointsMap[a.uid] ?? 0;
                    final pB = pointsMap[b.uid] ?? 0;
                    return pB.compareTo(pA);
                  });

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final profile = sortedProfiles[index];
                    final points = pointsMap[profile.uid] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(
                        bottom: 12,
                        left: 24,
                        right: 24,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(16),
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
                                    backgroundColor: AppColors.goldDim,
                                    child: Text(
                                      profile.displayName[0].toUpperCase(),
                                    ),
                                  ),
                                  if (profile.lastSeenAt != null &&
                                      DateTime.now()
                                              .difference(profile.lastSeenAt!)
                                              .inMinutes <
                                          3)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: AppColors.gold,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.surface1,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.gold.withValues(alpha: 0.5),
                                              blurRadius: 4,
                                              spreadRadius: 2,
                                            ),
                                          ],
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
                                        Text(
                                          profile.displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildPresenceLabel(profile.lastSeenAt),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      profile.currentIntention ??
                                          "Building in silence.",
                                      style: const TextStyle(
                                        fontFamily: 'CormorantGaramond',
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "$points",
                                    style: GoogleFonts.robotoMono(
                                      color: AppColors.gold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "pts/wk",
                                    style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (profile.activeTasks.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "ACTIVE MISSIONS",
                                    style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...profile.activeTasks.map(
                                    (taskTitle) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.radio_button_unchecked,
                                            color: Colors.white38,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              taskTitle,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () async {
                                              try {
                                                await context
                                                    .read<PingService>()
                                                    .sendPing(
                                                      toUid: profile.uid,
                                                      taskTitle: taskTitle,
                                                    );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Pinged ${profile.displayName} to focus.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Transmission failed',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.goldDim
                                                    .withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppColors.goldDim,
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.notifications_active,
                                                    color: AppColors.gold,
                                                    size: 10,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "NUDGE",
                                                    style: TextStyle(
                                                      color: Color(0xFF818CF8),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
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
                          ],
                        ],
                      ),
                    );
                  }, childCount: sortedProfiles.length),
                );
              },
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
          color: AppColors.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "ONLINE NOW",
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
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

    return Text(
      label,
      style: const TextStyle(color: Colors.white24, fontSize: 10),
    );
  }
}

// Outlined prompt that opens [CreateVowScreen]. Visible only when the user
// has no active vow.
class _VowPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateVowScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.goldDim,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'take a vow',
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'commit to one practice. name a witness.',
                    style: VyType.caption,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.gold,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
