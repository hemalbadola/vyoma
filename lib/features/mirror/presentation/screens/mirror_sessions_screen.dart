import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/friend_service.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../../../core/widgets/vy_loader.dart';
import '../../data/mirror_session_models.dart';
import '../../domain/mirror_session_service.dart';

// Mirror Sessions list + propose flow. Embedded inside Circle as a separate
// screen reachable via a button. v0 keeps this small and intentional.
class MirrorSessionsScreen extends StatelessWidget {
  const MirrorSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<MirrorSessionService>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('mirror sessions', style: VyType.heading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.background,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _ProposeMirrorScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          'PROPOSE',
          style: VyType.accent.copyWith(
            color: AppColors.background,
            letterSpacing: 2.5,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MirrorSession>>(
          stream: svc.streamMine(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: VyLoader());
            }
            final sessions = snap.data!;
            if (sessions.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'no mirrors yet.',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'a mirror session is one named friend, same hour, same '
                      'kind of work. no chat. no call. just presence.',
                      style: VyType.bodyMuted.copyWith(height: 1.6),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _SessionTile(session: sessions[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final MirrorSession session;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d • HH:mm');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                session.taskType.toUpperCase(),
                style: VyType.sectionLabel.copyWith(fontSize: 10),
              ),
              const Spacer(),
              Text(
                session.status.name.toUpperCase(),
                style: VyType.sectionLabel.copyWith(
                  fontSize: 10,
                  color: _statusColor(session.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(session.scheduledFor.toLocal()).toLowerCase(),
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.durationMinutes} minutes',
            style: VyType.caption,
          ),
        ],
      ),
    );
  }

  Color _statusColor(MirrorStatus s) {
    switch (s) {
      case MirrorStatus.pending:
        return AppColors.textMuted;
      case MirrorStatus.accepted:
        return AppColors.gold;
      case MirrorStatus.completed:
        return AppColors.gold;
      case MirrorStatus.declined:
        return AppColors.errorColor;
    }
  }
}

class _ProposeMirrorScreen extends StatefulWidget {
  const _ProposeMirrorScreen();

  @override
  State<_ProposeMirrorScreen> createState() => _ProposeMirrorScreenState();
}

class _ProposeMirrorScreenState extends State<_ProposeMirrorScreen> {
  String? _partnerUid;
  DateTime _when = DateTime.now().add(const Duration(hours: 2));
  int _durationMin = 60;
  final _taskType = TextEditingController(text: 'deep work');
  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      _partnerUid != null &&
      _taskType.text.trim().isNotEmpty &&
      !_submitting;

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final svc = context.read<MirrorSessionService>();
      await svc.propose(
        partnerUid: _partnerUid!,
        scheduledFor: _when,
        durationMinutes: _durationMin,
        taskType: _taskType.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  void dispose() {
    _taskType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d • HH:mm');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('propose mirror', style: VyType.heading),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'one named partner. same hour.\nsame kind of work. no chat.',
                style: VyType.bodyMuted.copyWith(height: 1.6),
              ),
              const SizedBox(height: 32),
              Text('PARTNER', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              _PartnerPicker(
                selected: _partnerUid,
                onSelect: (uid) => setState(() => _partnerUid = uid),
              ),
              const SizedBox(height: 24),
              Text('WHEN', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickWhen,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fmt.format(_when).toLowerCase(),
                          style: VyType.body,
                        ),
                      ),
                      const Icon(
                        Icons.event_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('DURATION', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [25, 50, 60, 90, 120]
                    .map(
                      (m) => GestureDetector(
                        onTap: () => setState(() => _durationMin = m),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: m == _durationMin
                                  ? AppColors.gold
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            '$m min',
                            style: VyType.body.copyWith(
                              fontSize: 13,
                              color: m == _durationMin
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text('KIND OF WORK', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _taskType,
                style: VyType.body,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'writing, studying, deep work',
                ),
              ),
              const SizedBox(height: 36),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: VyType.caption.copyWith(color: AppColors.errorColor),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _canSubmit
                          ? AppColors.gold
                          : AppColors.borderSubtle,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18, child: VyLoader())
                      : Text(
                          'PROPOSE',
                          style: VyType.accent.copyWith(letterSpacing: 2.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerPicker extends StatelessWidget {
  const _PartnerPicker({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final friends = context.read<FriendService>();
    return StreamBuilder<List<String>>(
      stream: friends.getAcceptedFriendUidsStream(),
      builder: (context, uidsSnap) {
        final uids = uidsSnap.data ?? const <String>[];
        if (uids.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'add a friend before proposing a mirror.',
              style: VyType.bodyMuted,
            ),
          );
        }
        return StreamBuilder<List<UserProfile>>(
          stream: friends.streamProfiles(uids),
          builder: (context, profSnap) {
            final profiles = profSnap.data ?? const <UserProfile>[];
            if (profiles.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: VyLoader(),
              );
            }
            return Column(
              children: profiles
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => onSelect(p.uid),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: p.uid == selected
                                  ? AppColors.gold
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.displayName.isNotEmpty
                                      ? p.displayName
                                      : p.username,
                                  style: VyType.body,
                                ),
                              ),
                              if (p.uid == selected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.gold,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}
