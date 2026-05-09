import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/memory_service.dart';
import '../../ui/war_room_viewmodel.dart';

class VaultJournalView extends StatefulWidget {
  final String? initialSeed;
  final bool embedded;

  const VaultJournalView({
    super.key,
    this.initialSeed,
    this.embedded = true,
  });

  @override
  State<VaultJournalView> createState() => _VaultJournalViewState();
}

class _VaultJournalViewState extends State<VaultJournalView> {
  final TextEditingController _journalController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isAnalyzing = false;
  bool _reviewVisible = false;
  bool _showSuccess = false;
  String _selectedMood = 'focused';

  final Set<String> _selectedTags = {};
  List<String> _insights = [];
  final Set<int> _selectedInsightIndexes = {};

  static const List<String> _moods = ['focused', 'calm', 'stressed', 'unclear', 'energized'];
  static const List<String> _templates = [
    'Brain dump',
    'Daily reflection',
    'Plan tomorrow',
    'Name current blocker',
    'Capture one insight',
  ];
  static const List<String> _guidedPrompts = [
    'What happened today?',
    'What drained energy?',
    'What gave momentum?',
    'What is next concrete step?',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSeed != null && widget.initialSeed!.trim().isNotEmpty) {
      _journalController.text = widget.initialSeed!.trim();
    }
  }

  @override
  void dispose() {
    _journalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    final starter = {
      'Brain dump': 'Everything on my mind right now:\n- ',
      'Daily reflection': 'Today I noticed...\n\nThe important part was...\n\nTomorrow I will...',
      'Plan tomorrow': 'Top 3 priorities for tomorrow:\n1. \n2. \n3. ',
      'Name current blocker': 'Current blocker:\n\nWhy this is happening:\n\nFirst counter-move:',
      'Capture one insight': 'Insight:\n\nEvidence:\n\nAction I will take:',
    }[template]!;

    if (_journalController.text.trim().isEmpty) {
      _journalController.text = starter;
    } else {
      _journalController.text += '\n\n$starter';
    }

    _journalController.selection = TextSelection.fromPosition(
      TextPosition(offset: _journalController.text.length),
    );
    _focusNode.requestFocus();
  }

  Set<String> _autoTagsFromText(String text) {
    final lower = text.toLowerCase();
    final tags = <String>{};
    if (lower.contains('exam') || lower.contains('assignment') || lower.contains('study')) {
      tags.add('study');
    }
    if (lower.contains('deadline') || lower.contains('urgent')) {
      tags.add('deadline');
    }
    if (lower.contains('sleep') || lower.contains('tired')) {
      tags.add('energy');
    }
    if (lower.contains('focus') || lower.contains('distract')) {
      tags.add('focus');
    }
    if (lower.contains('project') || lower.contains('build')) {
      tags.add('project');
    }
    if (lower.contains('anxious') || lower.contains('stress') || lower.contains('overwhelmed')) {
      tags.add('stress');
    }
    return tags;
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  int _actionableEstimate(String text) {
    final lower = text.toLowerCase();
    final cues = ['will ', 'need to ', 'must ', 'tomorrow', 'next', 'plan', 'deadline'];
    int matches = 0;
    for (final cue in cues) {
      if (lower.contains(cue)) matches++;
    }
    return matches;
  }

  String _topTheme(List<JournalEntry> entries) {
    final freq = <String, int>{};
    for (final entry in entries) {
      for (final t in entry.tags) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    if (freq.isEmpty) return 'none';
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Future<void> _analyzeEntry() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAnalyzing = true);
    try {
      final vm = context.read<WarRoomViewModel>();
      final insights = await vm.previewJournalInsights(text);

      setState(() {
        _insights = insights.isEmpty ? ['No strong extraction yet. You can still commit this entry.'] : insights;
        _selectedInsightIndexes
          ..clear()
          ..addAll(List.generate(_insights.length, (i) => i));
        _selectedTags.addAll(_autoTagsFromText(text));
        _reviewVisible = true;
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _commitEntry() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;

    final accepted = _selectedInsightIndexes
        .map((i) => _insights[i].trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final vm = context.read<WarRoomViewModel>();
    await vm.submitJournalEntry(
      text: text,
      mood: _selectedMood,
      tags: _selectedTags.toList(),
      acceptedInsights: accepted,
    );

    _journalController.clear();
    _focusNode.unfocus();

    setState(() {
      _reviewVisible = false;
      _insights = [];
      _selectedInsightIndexes.clear();
      _selectedTags.clear();
      _showSuccess = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSuccess = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = widget.embedded ? 118.0 : 24.0;
    final textNow = _journalController.text;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                SingleActivator(LogicalKeyboardKey.enter, meta: true): _commitEntry,
                SingleActivator(LogicalKeyboardKey.enter, control: true): _commitEntry,
                SingleActivator(LogicalKeyboardKey.keyE, meta: true): _analyzeEntry,
                SingleActivator(LogicalKeyboardKey.keyE, control: true): _analyzeEntry,
                SingleActivator(LogicalKeyboardKey.keyL, meta: true): () => _focusNode.requestFocus(),
                SingleActivator(LogicalKeyboardKey.keyL, control: true): () => _focusNode.requestFocus(),
              },
              child: Focus(
                autofocus: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final editorHeight =
                        (constraints.maxHeight * 0.32).clamp(220.0, 420.0);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
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
                          'VAULT',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF737373),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The Vault',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Turn raw experience into usable context. Capture what happened, what it meant, and what changes next.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFA3A3A3),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Shortcuts: Cmd/Ctrl+E analyze, Cmd/Ctrl+Enter commit, Cmd/Ctrl+L focus',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF6B7280),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F1720), Color(0xFF131B28)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A3442), width: 0.9),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Context Capture Protocol',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '1) State facts clearly\n2) Mark the emotional signal\n3) Define the next controllable action',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFB6C2CF),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Consumer<WarRoomViewModel>(
                      builder: (context, vm, _) {
                        final entries = vm.recentJournalEntries;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaPill(label: 'Vault rhythm', value: '${vm.journalStreakDays}d'),
                            _MetaPill(label: 'Top theme', value: _topTheme(entries.take(20).toList())),
                            _MetaPill(label: 'Entries', value: '${entries.length}'),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'TEMPLATES',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _templates
                          .map((t) => _ChipButton(label: t, onTap: () => _applyTemplate(t)))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'GUIDED PROMPTS',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _guidedPrompts
                          .map(
                            (p) => _ChipButton(
                              label: p,
                              subtle: true,
                              onTap: () {
                                _journalController.text +=
                                    '${_journalController.text.trim().isEmpty ? '' : '\n\n'}$p\n';
                                _focusNode.requestFocus();
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Mood',
                          style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12),
                        ),
                        ..._moods.map((m) {
                          final active = m == _selectedMood;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedMood = m),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : const Color(0xFF171B22),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: active
                                      ? const Color(0xFF10B981).withValues(alpha: 0.55)
                                      : const Color(0xFF2B313B),
                                ),
                              ),
                              child: Text(
                                m,
                                style: GoogleFonts.jetBrainsMono(
                                  color: active ? const Color(0xFF34D399) : const Color(0xFF9CA3AF),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedTags
                          .map(
                            (tag) => _ChipButton(
                              label: '#$tag',
                              active: true,
                              onTap: () => setState(() => _selectedTags.remove(tag)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _MetaPill(label: 'Words', value: '${_wordCount(textNow)}'),
                        const SizedBox(width: 8),
                        _MetaPill(label: 'Action cues', value: '${_actionableEstimate(textNow)}'),
                        const SizedBox(width: 8),
                        _MetaPill(label: 'Auto tags', value: '${_autoTagsFromText(textNow).length}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: editorHeight,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0D12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF252A35), width: 0.9),
                        ),
                        child: Stack(
                          children: [
                            TextField(
                              controller: _journalController,
                              focusNode: _focusNode,
                              maxLines: null,
                              expands: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              smartDashesType: SmartDashesType.disabled,
                              smartQuotesType: SmartQuotesType.disabled,
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: false,
                              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.7,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'What happened? What does it mean? What changes next?',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF525252),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_showSuccess)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 48),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Context synchronized',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: const Color(0xFF10B981),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_reviewVisible) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1218),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF253244), width: 0.9),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Extraction Review',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Accept, edit, or deselect insights before they shape future intelligence.',
                              style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            ..._insights.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final selected = _selectedInsightIndexes.contains(idx);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedInsightIndexes.add(idx);
                                          } else {
                                            _selectedInsightIndexes.remove(idx);
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: entry.value,
                                        onChanged: (v) => _insights[idx] = v,
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: UnderlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Consumer<MemoryService>(
                      builder: (context, memory, _) {
                        final recent = memory.getJournalEntries(limit: 3);
                        if (recent.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF2A3442), width: 0.8),
                            ),
                            child: Column(
                              children: [
                                SvgPicture.asset(
                                  'vyoma-icon-192.svg',
                                  width: 48,
                                  height: 48,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Nothing here yet',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your reflections stay private — only you and Vyoma see them.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFB6C2CF),
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent captures',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9CA3AF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...recent.map((e) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131923),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  e.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(color: const Color(0xFFD1D5DB), fontSize: 12),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 640;

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAnalyzeButton(),
                              const SizedBox(height: 10),
                              _buildCommitButton(),
                              if (_reviewVisible) ...[
                                const SizedBox(height: 6),
                                _buildRejectButton(),
                              ],
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildAnalyzeButton(),
                            const SizedBox(width: 10),
                            _buildCommitButton(),
                            if (_reviewVisible) ...[
                              const SizedBox(width: 10),
                              _buildRejectButton(),
                            ],
                          ],
                        );
                      },
                    ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return AnimatedOpacity(
      opacity: _isAnalyzing ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _isAnalyzing ? null : _analyzeEntry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _reviewVisible ? 'Re-analyze' : 'Analyze Entry',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommitButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _commitEntry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE5C158),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'Commit to Memory',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _reviewVisible = false;
          _insights = [];
          _selectedInsightIndexes.clear();
        });
      },
      child: Text(
        'Reject insights',
        style: GoogleFonts.inter(
          color: const Color(0xFF9CA3AF),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetaPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141A24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A3442), width: 0.8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF94A3B8),
                fontSize: 10,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFFE2E8F0),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool subtle;
  final bool active;

  const _ChipButton({
    required this.label,
    required this.onTap,
    this.subtle = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? const Color(0xFF10B981).withValues(alpha: 0.2)
        : subtle
            ? const Color(0xFF121826)
            : const Color(0xFF171B22);
    final border = active ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF2B313B);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: active ? const Color(0xFF34D399) : const Color(0xFFB8C0CC),
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

