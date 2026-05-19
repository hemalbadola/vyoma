import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/focus_timeline_store.dart';
import '../../../../core/memory_service.dart';
import '../../../../core/services/subject_color_service.dart';
import '../../../../core/models/focus_block.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../../../ui/theme/vyoma_colors.dart';
import '../../../../ui/war_room_viewmodel.dart';
import 'focus_clock_utils.dart';
import 'focus_day_clock.dart';

class _FocusModeDef {
  const _FocusModeDef({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.targetMinutes,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final int? targetMinutes;
}

const _modes = [
  _FocusModeDef(
    id: 'flow',
    label: 'Flow',
    subtitle: 'Open-ended',
    icon: Icons.waves_rounded,
  ),
  _FocusModeDef(
    id: 'ultradian',
    label: '90m',
    subtitle: 'Ultradian',
    icon: Icons.hourglass_top_rounded,
    targetMinutes: 90,
  ),
  _FocusModeDef(
    id: 'deep',
    label: 'Deep',
    subtitle: '50–90m',
    icon: Icons.psychology_rounded,
    targetMinutes: 60,
  ),
  _FocusModeDef(
    id: 'pomodoro',
    label: '25m',
    subtitle: 'Sprint',
    icon: Icons.timer_outlined,
    targetMinutes: 25,
  ),
];

/// Today tab focus: 24h clock dial, live session ring, stats, session log.
class TodayFocusPanel extends StatefulWidget {
  const TodayFocusPanel({super.key, this.suggestedTask});

  final String? suggestedTask;

  @override
  State<TodayFocusPanel> createState() => _TodayFocusPanelState();
}

class _TodayFocusPanelState extends State<TodayFocusPanel> {
  late final TextEditingController _intentController;
  String _selectedMode = 'flow';
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _intentController = TextEditingController(text: widget.suggestedTask ?? '');
  }

  @override
  void didUpdateWidget(covariant TodayFocusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.suggestedTask != null &&
        widget.suggestedTask!.trim().isNotEmpty &&
        _intentController.text.trim().isEmpty) {
      _intentController.text = widget.suggestedTask!;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _intentController.dispose();
    super.dispose();
  }

  void _ensureTicker(bool active) {
    _tick?.cancel();
    if (!active) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  _FocusModeDef _modeFor(String id) =>
      _modes.firstWhere((m) => m.id == id, orElse: () => _modes.first);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WarRoomViewModel>();
    final memory = context.watch<MemoryService>();
    final today = DateTime.now();
    final store = FocusTimelineStore(memory);
    final subjectColors = SubjectColorService(memory);
    final blocks = store.blocksForDay(today);
    final totalMin = store.totalMinutesForDay(today);
    final byTask = store.minutesByTaskForDay(today);
    final longest = store.longestBlockForDay(today);

    _ensureTicker(vm.isFocusSessionActive);

    if (vm.isFocusSessionActive) {
      _selectedMode = vm.focusSessionMode;
      if (_intentController.text.trim().isEmpty &&
          (vm.focusSessionIntent?.isNotEmpty ?? false)) {
        _intentController.text = vm.focusSessionIntent!;
      }
    }

    final dayArcs = arcsFromBlocks(blocks, today, colors: subjectColors);
    final live = vm.isFocusSessionActive && vm.focusSessionStartedAt != null
        ? liveArc(
            sessionStart: vm.focusSessionStartedAt!,
            task: vm.focusSessionIntent ?? 'Focus',
            day: today,
            colors: subjectColors,
          )
        : null;

    final clockCenter = _clockCenterContent(vm, totalMin, blocks.length);
    final progress = _sessionProgress(vm);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'focus',
                style: VyType.sectionLabel.copyWith(
                  color: VyomaColors.textMuted,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              if (blocks.isNotEmpty)
                Text(
                  '${blocks.length} session${blocks.length == 1 ? '' : 's'}',
                  style: VyType.caption,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCard(
            child: Column(
              children: [
                Center(
                  child: FocusDayClock(
                    size: 272,
                    dayArcs: dayArcs,
                    liveArc: live,
                    sessionProgress: progress,
                    centerTitle: clockCenter.title,
                    centerSubtitle: clockCenter.subtitle,
                    centerDetail: clockCenter.detail,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatsRow(
                  totalMin: totalMin,
                  longest: longest,
                  byTask: byTask,
                ),
                if (byTask.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSubjectColorKey(byTask, subjectColors),
                  const SizedBox(height: 12),
                  _buildSubjectBreakdown(byTask, subjectColors),
                ],
                const SizedBox(height: 20),
                if (vm.isFocusSessionActive)
                  _buildActiveControls(vm)
                else
                  _buildIdleControls(vm),
                if (blocks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'sessions today',
                      style: VyType.caption.copyWith(letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...blocks.reversed.map((b) => _sessionRow(b)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String subtitle, String? detail}) _clockCenterContent(
    WarRoomViewModel vm,
    int totalMin,
    int sessionCount,
  ) {
    final now = DateTime.now();
    if (vm.isFocusSessionActive) {
      final started = vm.focusSessionStartedAt;
      final elapsed =
          started == null ? Duration.zero : now.difference(started);
      final mode = _modeFor(vm.focusSessionMode);
      final target = mode.targetMinutes;
      String? detail;
      if (target != null) {
        final left = target - elapsed.inMinutes;
        detail = left > 0 ? '~$left min to target' : 'past target — wrap or continue';
      } else {
        detail = 'flow · end when done';
      }
      return (
        title: formatFocusDuration(elapsed),
        subtitle: vm.focusSessionIntent ?? 'Focus',
        detail: detail,
      );
    }

    if (totalMin > 0) {
      return (
        title: formatTotalMinutes(totalMin),
        subtitle: 'focused today',
        detail: formatClockTime(now),
      );
    }

    return (
      title: formatClockTime(now),
      subtitle: sessionCount > 0 ? 'between sessions' : 'ready',
      detail: 'outer ring · your day',
    );
  }

  double? _sessionProgress(WarRoomViewModel vm) {
    if (!vm.isFocusSessionActive) return null;
    final mode = _modeFor(vm.focusSessionMode);
    final target = mode.targetMinutes;
    if (target == null || target <= 0) return null;
    final started = vm.focusSessionStartedAt;
    if (started == null) return 0;
    return DateTime.now().difference(started).inSeconds / (target * 60);
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildStatsRow({
    required int totalMin,
    required FocusBlock? longest,
    required Map<String, int> byTask,
  }) {
    final top = _topTaskEntry(byTask);
    return Row(
      children: [
        Expanded(
          child: _statTile(
            label: 'total',
            value: totalMin > 0 ? formatTotalMinutes(totalMin) : '—',
          ),
        ),
        Expanded(
          child: _statTile(
            label: 'longest',
            value: longest != null ? '${longest.durationMinutes}m' : '—',
            hint: longest?.task,
          ),
        ),
        Expanded(
          child: _statTile(
            label: 'top',
            value: top != null ? _shortLabel(top.key, 10) : '—',
            hint: top != null ? '${top.value}m' : null,
          ),
        ),
      ],
    );
  }

  MapEntry<String, int>? _topTaskEntry(Map<String, int> byTask) {
    if (byTask.isEmpty) return null;
    final sorted = byTask.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first;
  }

  Widget _statTile({
    required String label,
    required String value,
    String? hint,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: VyType.caption.copyWith(
            letterSpacing: 1.5,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: VyType.heading.copyWith(fontSize: 16),
        ),
        if (hint != null && hint.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _shortLabel(hint, 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VyType.caption.copyWith(fontSize: 9),
          ),
        ],
      ],
    );
  }

  Widget _buildSubjectColorKey(
    Map<String, int> byTask,
    SubjectColorService colors,
  ) {
    final sorted = byTask.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in sorted.take(8))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.colorFor(e.key).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.colorFor(e.key).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.colorFor(e.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  e.key,
                  style: VyType.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectBreakdown(
    Map<String, int> byTask,
    SubjectColorService colors,
  ) {
    final sorted = byTask.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'by subject',
          style: VyType.caption.copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 10),
        for (final e in sorted.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.colorFor(e.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyType.body.copyWith(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : e.value / max,
                      minHeight: 6,
                      backgroundColor: AppColors.surface2,
                      color: colors.colorFor(e.key),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${e.value}m',
                    textAlign: TextAlign.right,
                    style: VyType.caption.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModeSelector({required bool enabled}) {
    const cardHeight = 76.0;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _modes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final mode = _modes[i];
          final selected = _selectedMode == mode.id;
          return GestureDetector(
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedMode = mode.id);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 72,
              height: cardHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? VyomaColors.accent.withValues(alpha: 0.12)
                    : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? VyomaColors.accent : AppColors.borderSubtle,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 16,
                    color: selected
                        ? VyomaColors.accent
                        : VyomaColors.textMuted,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? VyomaColors.accent
                          : VyomaColors.textSecondary,
                    ),
                  ),
                  Text(
                    mode.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyType.caption.copyWith(fontSize: 7, height: 1.1),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdleControls(WarRoomViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildModeSelector(enabled: true),
        const SizedBox(height: 14),
        TextField(
          controller: _intentController,
          textCapitalization: TextCapitalization.sentences,
          style: VyType.body,
          decoration: InputDecoration(
            hintText: 'subject or task',
            hintStyle: VyType.bodyMuted,
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: VyomaColors.accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (_) => _onStart(vm),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _onStart(vm),
            style: FilledButton.styleFrom(
              backgroundColor: VyomaColors.accent,
              foregroundColor: VyomaColors.textOnAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'start ${_modeFor(_selectedMode).label.toLowerCase()}',
              style: VyType.accent.copyWith(color: VyomaColors.textOnAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveControls(WarRoomViewModel vm) {
    final mode = _modeFor(vm.focusSessionMode);
    return Column(
      children: [
        _buildModeSelector(enabled: false),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(mode.icon, size: 16, color: VyomaColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${mode.label} session in progress',
                style: VyType.caption.copyWith(color: VyomaColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _onStop(vm),
            style: OutlinedButton.styleFrom(
              foregroundColor: VyomaColors.textPrimary,
              side: BorderSide(color: VyomaColors.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('end session'),
          ),
        ),
      ],
    );
  }

  Widget _sessionRow(FocusBlock block) {
    final color = block.displayColor;
    final fmt = DateFormat('HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.task,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VyType.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(block.start)} – ${fmt.format(block.end)}',
                  style: VyType.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${block.durationMinutes}m',
                style: VyType.heading.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  block.mode,
                  style: VyType.caption.copyWith(fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortLabel(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1)}…';
  }

  void _onStart(WarRoomViewModel vm) {
    final intent = _intentController.text.trim();
    if (intent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name what you\'re working on first.')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    if (!vm.startFocusSession(intent: intent, mode: _selectedMode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already in a focus session.')),
      );
      return;
    }
    setState(() {});
  }

  void _onStop(WarRoomViewModel vm) {
    HapticFeedback.lightImpact();
    vm.stopFocusSession();
    setState(() {});
  }
}
