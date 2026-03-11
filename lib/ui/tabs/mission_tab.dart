import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../../core/calendar_service.dart';
import '../../core/memory_service.dart';
import '../../ui/war_room_viewmodel.dart';
import '../../ui/widgets/debrief_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../ui/widgets/glass_card.dart';
import '../../ui/widgets/chat_sheet.dart';
import '../../ui/screens/memory_vault_screen.dart';

class MissionTab extends StatelessWidget {
  const MissionTab({super.key});

  // Premium Color Palette - High Contrast
  static const kBackground = Color(0xFF000000);
  static const kCardBg = Color(0xFF121212);          // Brighter card background
  static const kCardBgHover = Color(0xFF181818);
  static const kBorder = Color(0xFF2A2A2A);          // More visible borders
  static const kBorderLight = Color(0xFF3A3A3A);
  static const kBurgundy = Color(0xFFB91C32);        // Brighter burgundy
  static const kBurgundyLight = Color(0xFFDC2F45);
  static const kEmerald = Color(0xFF10B981);         // Brighter emerald
  static const kEmeraldLight = Color(0xFF34D399);
  static const kGold = Color(0xFFE5C158);
  static const kTextPrimary = Color(0xFFFFFFFF);     // Pure white
  static const kTextSecondary = Color(0xFFA3A3A3);   // Brighter secondary
  static const kTextMuted = Color(0xFF737373);       // Less muted

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    if (hour < 21) return "Good evening";
    return "Good night";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildHeroGreeting(context),
              _buildQuickActions(context),
              _buildTodaysFocus(context),
              _buildMemoryPreview(context),
              _buildDebriefSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Badge
          _buildPremiumBadge("◈  vyoma", kTextMuted),
          // Status
          Consumer<WarRoomViewModel>(
            builder: (_, vm, __) => _buildStatusChip(
              "${(vm.currentMetrics.focusMinutes / 60).toStringAsFixed(1)}h",
              isActive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? kEmerald.withOpacity(0.08) : kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? kEmerald.withOpacity(0.2) : kBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? kEmerald : kTextMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.jetBrainsMono(
              color: isActive ? kEmeraldLight : kTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroGreeting(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting().toUpperCase(),
            style: GoogleFonts.inter(
              color: kTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: GoogleFonts.dmSans(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
                height: 1.15,
                letterSpacing: -0.5,
              ),
              children: const [
                TextSpan(text: "What will you\n"),
                TextSpan(
                  text: "create ",
                  style: TextStyle(fontWeight: FontWeight.w300, color: Color(0xFFD4D4D4)),
                ),
                TextSpan(text: "today?"),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': '◇', 'label': 'Chat', 'action': 'Chat'},
      {'icon': '◈', 'label': 'Memories', 'action': 'Memories'},
      {'icon': '▣', 'label': 'Schedule', 'action': 'Schedule'},
      {'icon': '◎', 'label': 'Intel', 'action': 'Insights'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ACTIONS",
            style: GoogleFonts.inter(
              color: kTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: actions.asMap().entries.map((entry) {
              final i = entry.key;
              final action = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < actions.length - 1 ? 10 : 0),
                  child: _buildActionCard(
                    context,
                    icon: action['icon'] as String,
                    label: action['label'] as String,
                    onTap: () => _handleQuickAction(context, action['action'] as String),
                  ),
                ).animate(delay: (80 * i).ms).fadeIn().slideY(begin: 0.15),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          child: Column(
            children: [
              Text(
                icon,
                style: GoogleFonts.inter(
                  color: kTextSecondary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  color: kTextSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleQuickAction(BuildContext context, String action) {
    switch (action) {
      case 'Chat':
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ChatSheet(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutQuart))
                ),
                child: child,
              );
            },
          ),
        );
        break;
      case 'Memories':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoryVaultScreen()),
        );
        break;
      case 'Schedule':
        break;
      case 'Insights':
        break;
    }
  }

  Widget _buildTodaysFocus(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY",
                style: GoogleFonts.inter(
                  color: kTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase(),
                style: GoogleFonts.inter(
                  color: kTextMuted,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<calendar.Event>>(
            future: Provider.of<CalendarService>(context, listen: false).syncEvents(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyFocusCard();
              }
              return Column(
                children: snapshot.data!.take(3).toList().asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildEventCard(e.value, e.key),
                  ).animate(delay: (100 * e.key).ms).fadeIn().slideX(begin: 0.05);
                }).toList(),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildEmptyFocusCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kEmerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "＋",
                  style: GoogleFonts.inter(
                    color: kEmerald,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No events scheduled",
                    style: GoogleFonts.inter(
                      color: kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Chat with Vyoma to plan your day",
                    style: GoogleFonts.inter(
                      color: kTextMuted,
                      fontSize: 12,
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

  Widget _buildEventCard(calendar.Event event, int index) {
    final now = DateTime.now();
    final startTime = event.start?.dateTime;
    final isActive = startTime != null && 
        startTime.isBefore(now) && 
        (event.end?.dateTime?.isAfter(now) ?? false);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive ? kBurgundy.withOpacity(0.06) : kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? kBurgundy.withOpacity(0.25) : kBorder,
            width: isActive ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Time Column
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTime(event.start?.dateTime),
                    style: GoogleFonts.jetBrainsMono(
                      color: isActive ? kBurgundyLight : kTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: kBurgundy.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "LIVE",
                        style: GoogleFonts.inter(
                          color: kBurgundyLight,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Vertical Line
            Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: isActive ? kBurgundy.withOpacity(0.3) : kBorder,
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.summary ?? "Untitled",
                    style: GoogleFonts.inter(
                      color: kTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_formatTime(event.start?.dateTime)} → ${_formatTime(event.end?.dateTime)}",
                    style: GoogleFonts.inter(
                      color: kTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Text(
              "→",
              style: GoogleFonts.inter(
                color: kTextMuted,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryPreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MEMORY",
                style: GoogleFonts.inter(
                  color: kTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MemoryVaultScreen()),
                  ),
                  child: Text(
                    "VIEW ALL →",
                    style: GoogleFonts.inter(
                      color: kTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<MemoryService>(
            builder: (context, memory, _) {
              final facts = memory.getFacts();
              if (facts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "◇",
                        style: GoogleFonts.inter(color: kTextMuted, fontSize: 16),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Vyoma learns about you as you chat",
                          style: GoogleFonts.inter(color: kTextMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final recentFacts = facts.entries.take(3).toList();
              return Column(
                children: recentFacts.asMap().entries.map((e) {
                  final i = e.key;
                  final fact = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildMemoryItem(fact.key, fact.value.toString()),
                  ).animate(delay: (80 * i).ms).fadeIn().slideX(begin: 0.05);
                }).toList(),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildMemoryItem(String key, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kEmerald.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                "◈",
                style: GoogleFonts.inter(color: kEmeraldLight, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.inter(
                    color: kTextMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: kTextSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebriefSection(BuildContext context) {
    return Consumer<MemoryService>(
      builder: (context, memory, _) {
        final pending = memory.getPendingDebriefs();
        if (pending.isEmpty) return const SizedBox.shrink();

        final debrief = pending.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
          child: DebriefCard(
            title: debrief.title,
            eventId: debrief.eventId,
            onReport: () async {
              await memory.removePendingDebrief(debrief.eventId);
              if (context.mounted) {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const ChatSheet(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: animation.drive(
                          Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                            .chain(CurveTween(curve: Curves.easeOutQuart))
                        ),
                        child: child,
                      );
                    },
                  ),
                );
                Future.delayed(const Duration(milliseconds: 500), () {
                  Provider.of<WarRoomViewModel>(context, listen: false).submitCommand(
                    "I am reporting for debrief on: '${debrief.title}'"
                  );
                });
              }
            },
          ),
        );
      },
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "--:--";
    return DateFormat('HH:mm').format(dt);
  }
}
