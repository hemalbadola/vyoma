import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/models/timetable.dart';
import '../../core/timetable_service.dart';
import '../theme/vyoma_colors.dart';
import '../theme/vyoma_text_styles.dart';
import '../widgets/weekly_calendar_grid.dart';

class TimetableTab extends StatefulWidget {
  const TimetableTab({super.key});

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  static const List<String> _orderedDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _openSlotModal({
    TimetableSlot? existing,
    int? editIndex,
  }) async {
    final result = await showModalBottomSheet<TimetableSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TimetableSlotModal(existing: existing),
    );
    if (!mounted || result == null) return;

    final service = context.read<TimetableService>();
    if (existing == null) {
      await service.addSlot(result);
      return;
    }

    final current = service.slots.toList();
    if (editIndex == null || editIndex < 0 || editIndex >= current.length) return;
    current[editIndex] = result;
    await service.updateTimetable(current);
  }

  Future<void> _deleteSlot(TimetableSlot slot) async {
    await context.read<TimetableService>().removeSlot(slot);
  }

  int _dayRank(String day) {
    final idx = _orderedDays.indexOf(day);
    return idx == -1 ? 99 : idx;
  }

  List<MapEntry<int, TimetableSlot>> _sortedEntries(List<TimetableSlot> slots) {
    final entries = slots.asMap().entries.toList();
    entries.sort((a, b) {
      final dayCmp = _dayRank(a.value.dayOfWeek).compareTo(_dayRank(b.value.dayOfWeek));
      if (dayCmp != 0) return dayCmp;
      return a.value.startTime.compareTo(b.value.startTime);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: VyomaColors.accent,
        foregroundColor: VyomaColors.textOnAccent,
        onPressed: () => _openSlotModal(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Class'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'vyoma-icon-192.svg',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SCHEDULE',
                        style: VyomaTextStyles.label.copyWith(
                          color: VyomaColors.textMuted,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your week',
                    style: VyomaTextStyles.displayMedium.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Consumer<TimetableService>(
                      builder: (context, tt, _) {
                        final sorted = _sortedEntries(tt.slots);
                        if (tt.slots.isEmpty) {
                          return _TimetableEmptyState(onAdd: () => _openSlotModal());
                        }
                        return Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: VyomaColors.bgCardElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: VyomaColors.borderDefault, width: 0.9),
                                ),
                                child: const WeeklyCalendarGrid(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Class slots',
                                style: VyomaTextStyles.headingSmall.copyWith(
                                  color: VyomaColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: sorted.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final entry = sorted[index];
                                  final slot = entry.value;
                                  return Dismissible(
                                    key: ValueKey(
                                      '${slot.dayOfWeek}_${slot.startTime}_${slot.subject}_$index',
                                    ),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      decoration: BoxDecoration(
                                        color: VyomaColors.error.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, color: VyomaColors.error),
                                    ),
                                    onDismissed: (_) => _deleteSlot(slot),
                                    child: _TimetableSlotRow(
                                      slot: slot,
                                      onTap: () => _openSlotModal(
                                        existing: slot,
                                        editIndex: entry.key,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimetableEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _TimetableEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'vyoma-icon-192.svg',
              width: 56,
              height: 56,
            ),
            const SizedBox(height: 20),
            Text(
              'No classes yet',
              textAlign: TextAlign.center,
              style: VyomaTextStyles.headingLarge.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              'Add your timetable slots here. Vyoma syncs same changes used by chat path.',
              textAlign: TextAlign.center,
              style: VyomaTextStyles.bodyMedium.copyWith(
                color: VyomaColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, color: VyomaColors.accent),
              label: Text(
                'Add first class',
                style: VyomaTextStyles.button.copyWith(color: VyomaColors.accentBright),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableSlotRow extends StatelessWidget {
  final TimetableSlot slot;
  final VoidCallback onTap;

  const _TimetableSlotRow({
    required this.slot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final room = slot.venue.trim().isEmpty ? 'No room' : slot.venue.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: VyomaColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VyomaColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: VyomaColors.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.subject,
                    style: VyomaTextStyles.headingSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${slot.dayOfWeek} • ${slot.startTime} - ${slot.endTime} • $room',
                    style: VyomaTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.edit_outlined, color: VyomaColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TimetableSlotModal extends StatefulWidget {
  final TimetableSlot? existing;
  const _TimetableSlotModal({this.existing});

  @override
  State<_TimetableSlotModal> createState() => _TimetableSlotModalState();
}

class _TimetableSlotModalState extends State<_TimetableSlotModal> {
  static const List<String> _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;
  late String _selectedDay;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _subjectController = TextEditingController(text: existing?.subject ?? '');
    _roomController = TextEditingController(text: existing?.venue ?? '');
    _selectedDay = _days.contains(existing?.dayOfWeek) ? existing!.dayOfWeek : _days.first;
    _start = _parseTime(existing?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = _parseTime(existing?.endTime) ?? const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _format(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked == null) return;
    setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _end);
    if (picked == null) return;
    setState(() => _end = picked);
  }

  void _save() {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject required.')),
      );
      return;
    }
    if (_minutes(_end) <= _minutes(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    Navigator.of(context).pop(
      TimetableSlot(
        dayOfWeek: _selectedDay,
        startTime: _format(_start),
        endTime: _format(_end),
        subject: subject,
        venue: _roomController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'Add class' : 'Edit class',
              style: VyomaTextStyles.headingLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedDay,
              items: _days
                  .map((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedDay = value);
              },
              decoration: const InputDecoration(
                labelText: 'Day',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStart,
                    child: Text('Start ${_format(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEnd,
                    child: Text('End ${_format(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: VyomaColors.accent,
                  foregroundColor: VyomaColors.textOnAccent,
                ),
                child: Text(widget.existing == null ? 'Add class' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
