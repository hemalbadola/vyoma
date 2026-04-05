import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:provider/provider.dart';

import '../../core/calendar_service.dart';

class WeeklyCalendarGrid extends StatefulWidget {
  const WeeklyCalendarGrid({super.key});

  @override
  State<WeeklyCalendarGrid> createState() => _WeeklyCalendarGridState();
}

class _WeeklyCalendarGridState extends State<WeeklyCalendarGrid> {
  static const double _timeLabelWidth = 72;
  double _dayColumnWidth = 160;
  double _hourHeight = 56;

  final ScrollController _verticalController = ScrollController();
  DateTime _weekStart = _startOfWeek(DateTime.now());
  List<gcal.Event> _events = const [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshWeek();

    // Keep grid fresh so edits from chat-agent/user appear quickly.
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        _refreshWeek(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _refreshWeek({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final service = context.read<CalendarService>();
    try {
      final items = await service.syncEventsInRange(
        timeMin: _weekStart,
        timeMax: _weekStart.add(const Duration(days: 7)),
      );
      if (!mounted) return;
      setState(() {
        _events = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openEventEditor({
    required DateTime initialStart,
    gcal.Event? event,
  }) async {
    final summaryController = TextEditingController(text: event?.summary ?? '');
    final locationController = TextEditingController(text: event?.location ?? '');
    final noteController = TextEditingController(text: event?.description ?? '');

    DateTime start = _displayDateTime(event?.start) ?? initialStart;
    DateTime end = _displayDateTime(event?.end) ?? initialStart.add(const Duration(hours: 1));

    Future<void> pickStart() async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: start,
        firstDate: _weekStart.subtract(const Duration(days: 28)),
        lastDate: _weekStart.add(const Duration(days: 35)),
      );
      if (pickedDate == null) return;
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(start),
      );
      if (pickedTime == null) return;

      start = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (!end.isAfter(start)) {
        end = start.add(const Duration(hours: 1));
      }
    }

    Future<void> pickEnd() async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: end,
        firstDate: start,
        lastDate: _weekStart.add(const Duration(days: 60)),
      );
      if (pickedDate == null) return;
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(end),
      );
      if (pickedTime == null) return;

      final candidate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (candidate.isAfter(start)) {
        end = candidate;
      }
    }

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF12131A),
              title: Text(
                event == null ? 'Add Event' : 'Edit Event',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: summaryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await pickStart();
                                if (mounted) setLocalState(() {});
                              },
                              child: Text(_fmtDateTime(start)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await pickEnd();
                                if (mounted) setLocalState(() {});
                              },
                              child: Text(_fmtDateTime(end)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (event != null)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'save'),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || action == null || action == 'cancel') return;

    final service = context.read<CalendarService>();
    try {
      if (action == 'delete' && event?.id != null) {
        await service.deleteEvent(event!.id!);
      } else if (action == 'save') {
        final updated = gcal.Event(
          summary: summaryController.text.trim().isEmpty ? 'Untitled' : summaryController.text.trim(),
          location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
          description: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
          start: gcal.EventDateTime(dateTime: start),
          end: gcal.EventDateTime(dateTime: end),
        );

        if (event?.id != null) {
          await service.updateEvent(event!.id!, updated);
        } else {
          await service.addEvent(updated);
        }
      }

      await _refreshWeek();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calendar operation failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = MediaQuery.of(context).size;
    final availableWidth = view.width - _timeLabelWidth - 36;
    _dayColumnWidth = (availableWidth / 7).clamp(122.0, 170.0);
    _hourHeight = view.height > 900 ? 60 : 52;

    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
                  _refreshWeek();
                },
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_fmtMonthDay(days.first)} - ${_fmtMonthDay(days.last)}',
                    style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
                  _refreshWeek();
                },
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
              ),
              IconButton(
                onPressed: _refreshWeek,
                icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildGrid(days),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.redAccent, size: 34),
            const SizedBox(height: 12),
            Text(
              'Calendar sync unavailable',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _refreshWeek, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<DateTime> days) {
    final totalHeight = 24 * _hourHeight;

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              _buildHeader(days),
              SizedBox(
                height: totalHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeColumn(),
                    ...List.generate(days.length, (index) {
                      return _buildDayColumn(days[index], index);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<DateTime> days) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Container(
            width: _timeLabelWidth,
            height: 44,
            alignment: Alignment.center,
            child: Text(
              'Time',
              style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 11),
            ),
          ),
          ...days.map((d) {
            return Container(
              width: _dayColumnWidth,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayLabel(d),
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${d.day}/${d.month}',
                    style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    return SizedBox(
      width: _timeLabelWidth,
      child: Column(
        children: List.generate(24, (hour) {
          return Container(
            height: _hourHeight,
            alignment: Alignment.topCenter,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white30,
                  fontSize: 10,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(DateTime day, int dayIndex) {
    final dayEvents = _eventsForDay(day);

    return SizedBox(
      width: _dayColumnWidth,
      child: Stack(
        children: [
          Column(
            children: List.generate(24, (hour) {
              return GestureDetector(
                onTap: () {
                  final slotStart = DateTime(day.year, day.month, day.day, hour);
                  _openEventEditor(initialStart: slotStart);
                },
                child: Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ),
                  child: hour == DateTime.now().hour && _isSameDate(day, DateTime.now())
                      ? Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 2),
                            height: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : null,
                ),
              );
            }),
          ),
          ...dayEvents.map((event) {
            final startLocal = _displayDateTime(event.start) ?? day;
            final endLocal = _displayDateTime(event.end) ?? startLocal.add(const Duration(hours: 1));
            final minutesFromTop = (startLocal.hour * 60) + startLocal.minute;
            final durationMinutes = endLocal.difference(startLocal).inMinutes.clamp(15, 24 * 60);

            final top = (minutesFromTop / 60) * _hourHeight;
            final height = (durationMinutes / 60) * _hourHeight;

            return Positioned(
              left: 6,
              right: 6,
              top: top,
              height: height < 28 ? 28 : height,
              child: GestureDetector(
                onTap: () => _openEventEditor(initialStart: startLocal, event: event),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.summary ?? 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtTime(startLocal)} - ${_fmtTime(endLocal)}',
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<gcal.Event> _eventsForDay(DateTime day) {
    return _events.where((event) {
      final dt = _displayDateTime(event.start);
      if (dt == null) return false;
      return _isSameDate(dt, day);
    }).toList();
  }

  DateTime? _displayDateTime(gcal.EventDateTime? value) {
    final dt = value?.dateTime;
    if (dt == null) return null;

    final tz = value?.timeZone;
    final offsetMinutes = _offsetMinutesForTimeZone(tz);
    return dt.toUtc().add(Duration(minutes: offsetMinutes));
  }

  int _offsetMinutesForTimeZone(String? timeZone) {
    switch (timeZone) {
      case 'UTC':
        return 0;
      case 'Asia/Kolkata':
        return 330;
      case 'Europe/Berlin':
        return 60;
      case 'Europe/Athens':
        return 120;
      case 'Asia/Dubai':
        return 240;
      case 'Asia/Singapore':
        return 480;
      case 'Asia/Tokyo':
        return 540;
      case 'America/New_York':
        return -300;
      case 'America/Chicago':
        return -360;
      case 'America/Denver':
        return -420;
      case 'America/Los_Angeles':
        return -480;
      default:
        return DateTime.now().timeZoneOffset.inMinutes;
    }
  }

  static DateTime _startOfWeek(DateTime source) {
    final normalized = DateTime(source.year, source.month, source.day);
    final int offset = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: offset));
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayLabel(DateTime d) {
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return names[d.weekday - 1];
  }

  String _fmtMonthDay(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _fmtTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDateTime(DateTime d) {
    return '${_weekdayLabel(d)} ${d.day}/${d.month} ${_fmtTime(d)}';
  }
}
