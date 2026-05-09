import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/notification_service.dart';
import '../theme/vyoma_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<List<NotificationRecord>> _loadHistory() {
    return context.read<NotificationService>().getHistory(limit: 150);
  }

  Future<void> _reload() async {
    setState(() {});
  }

  String _format(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '${t.day}/${t.month}/${t.year} $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VyomaColors.bgBase,
      appBar: AppBar(
        title: Text(
          'Notification Inbox',
          style: GoogleFonts.inter(color: VyomaColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<NotificationService>().markAllRead();
              if (!mounted) return;
              await _reload();
            },
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                color: VyomaColors.accentBright,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationRecord>>(
        future: _loadHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _NotificationSkeletonList();
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const _NotificationEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = items[index];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: VyomaColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.archive_outlined, color: VyomaColors.error),
                ),
                onDismissed: (_) async {
                  await context.read<NotificationService>().dismiss(n.id);
                  if (!mounted) return;
                  await _reload();
                },
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    if (n.isRead) return;
                    await context.read<NotificationService>().markRead(n.id);
                    if (!mounted) return;
                    await _reload();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VyomaColors.bgCardElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: VyomaColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: n.isRead ? VyomaColors.textMuted : VyomaColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                style: GoogleFonts.inter(
                                  color: VyomaColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                n.body,
                                style: GoogleFonts.inter(color: VyomaColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _format(n.sentAt),
                                style: GoogleFonts.jetBrainsMono(
                                  color: VyomaColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationSkeletonList extends StatefulWidget {
  const _NotificationSkeletonList();

  @override
  State<_NotificationSkeletonList> createState() => _NotificationSkeletonListState();
}

class _NotificationSkeletonListState extends State<_NotificationSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = 0.22 + (_controller.value * 0.28);
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: 3,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VyomaColors.bgCardElevated.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VyomaColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 210,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: VyomaColors.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded, color: VyomaColors.accent, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              'No notifications yet',
              style: GoogleFonts.inter(
                color: VyomaColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vyoma will ping you when it matters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: VyomaColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
