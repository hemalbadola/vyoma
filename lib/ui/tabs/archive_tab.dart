import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/memory_service.dart';
import '../vyoma_theme.dart';
import '../war_room_viewmodel.dart';

class ArchiveTab extends StatefulWidget {
  const ArchiveTab({super.key});

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _freeWriteController = TextEditingController();
  final FocusNode _freeWriteFocus = FocusNode();

  bool _isAnalyzing = false;
  bool _reviewVisible = false;
  bool _showSuccess = false;
  int _currentPromptIndex = 0;
  String _selectedMood = 'focused';

  final Map<int, String> _answers = {};
  final Set<String> _selectedTags = {};
  List<String> _insights = [];
  final Set<int> _selectedInsightIndexes = {};

  static const List<String> _moods = [
    'focused',
    'calm',
    'stretched',
    'grateful',
    'uncertain',
  ];

  static const List<_DebriefPrompt> _prompts = [
    _DebriefPrompt(
      question: 'What was the most meaningful moment in your day?',
      starters: [
        'I felt most alive when...',
        'The key moment was...',
        'I noticed a shift when...',
      ],
    ),
    _DebriefPrompt(
      question: 'What drained your focus or emotional energy?',
      starters: [
        'I lost momentum because...',
        'A recurring distraction was...',
        'I felt resistance around...',
      ],
    ),
    _DebriefPrompt(
      question: 'What gave you momentum and clarity?',
      starters: [
        'I made progress once I...',
        'Support that helped me was...',
        'My best focus window was...',
      ],
    ),
    _DebriefPrompt(
      question: 'What is your next concrete move tomorrow?',
      starters: [
        'Before noon tomorrow I will...',
        'The first step is...',
        'I will protect time for...',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _freeWriteController.dispose();
    _freeWriteFocus.dispose();
    super.dispose();
  }

  int get _answeredCount {
    final staged = Map<int, String>.from(_answers);
    final liveText = _answerController.text.trim();
    if (liveText.isNotEmpty) {
      staged[_currentPromptIndex] = liveText;
    }
    return staged.values.where((value) => value.trim().isNotEmpty).length;
  }

  double get _progress {
    return (_answeredCount / _prompts.length).clamp(0.0, 1.0);
  }

  void _stashCurrentAnswer() {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      _answers.remove(_currentPromptIndex);
    } else {
      _answers[_currentPromptIndex] = text;
    }
  }

  void _jumpToPrompt(int index) {
    _stashCurrentAnswer();
    final safeIndex = index.clamp(0, _prompts.length - 1).toInt();
    setState(() {
      _currentPromptIndex = safeIndex;
      _answerController.text = _answers[_currentPromptIndex] ?? '';
      _answerController.selection = TextSelection.fromPosition(
        TextPosition(offset: _answerController.text.length),
      );
    });
  }

  void _applyStarter(String starter) {
    _answerController.text = starter;
    _answerController.selection = TextSelection.fromPosition(
      TextPosition(offset: _answerController.text.length),
    );
  }

  Set<String> _autoTagsFromText(String text) {
    final lower = text.toLowerCase();
    final tags = <String>{};

    if (lower.contains('exam') ||
        lower.contains('study') ||
        lower.contains('assignment')) {
      tags.add('study');
    }
    if (lower.contains('deadline') || lower.contains('urgent')) {
      tags.add('deadline');
    }
    if (lower.contains('focus') ||
        lower.contains('distract') ||
        lower.contains('deep work')) {
      tags.add('focus');
    }
    if (lower.contains('tired') ||
        lower.contains('sleep') ||
        lower.contains('energy')) {
      tags.add('energy');
    }
    if (lower.contains('anxious') ||
        lower.contains('stress') ||
        lower.contains('overwhelmed')) {
      tags.add('stress');
    }
    if (lower.contains('friend') ||
        lower.contains('team') ||
        lower.contains('group')) {
      tags.add('social');
    }

    return tags;
  }

  String _composeEntryText() {
    final staged = Map<int, String>.from(_answers);
    final liveText = _answerController.text.trim();
    if (liveText.isNotEmpty) {
      staged[_currentPromptIndex] = liveText;
    }

    final buffer = StringBuffer();
    for (var i = 0; i < _prompts.length; i++) {
      final answer = staged[i]?.trim();
      if (answer != null && answer.isNotEmpty) {
        buffer.writeln('Prompt: ${_prompts[i].question}');
        buffer.writeln('Reflection: $answer');
        buffer.writeln();
      }
    }

    final freeWrite = _freeWriteController.text.trim();
    if (freeWrite.isNotEmpty) {
      buffer.writeln('Open notes:');
      buffer.writeln(freeWrite);
    }

    return buffer.toString().trim();
  }

  Future<void> _analyzeEntry() async {
    final text = _composeEntryText();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a reflection before analyzing.')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final vm = context.read<WarRoomViewModel>();
      final insights = await vm.previewJournalInsights(text);

      if (!mounted) return;
      setState(() {
        _insights = insights.isEmpty
            ? ['No major extraction yet. You can still commit this reflection.']
            : insights;
        _selectedInsightIndexes
          ..clear()
          ..addAll(List<int>.generate(_insights.length, (i) => i));
        _selectedTags.addAll(_autoTagsFromText(text));
        _reviewVisible = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _commitEntry() async {
    final text = _composeEntryText();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture at least one response first.')),
      );
      return;
    }

    final accepted = _selectedInsightIndexes
        .map((i) => _insights[i].trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final mergedTags = <String>{..._selectedTags, ..._autoTagsFromText(text)};

    final vm = context.read<WarRoomViewModel>();
    await vm.submitJournalEntry(
      text: text,
      mood: _selectedMood,
      tags: mergedTags.toList(),
      acceptedInsights: accepted,
    );

    _answerController.clear();
    _freeWriteController.clear();
    _freeWriteFocus.unfocus();

    if (!mounted) return;
    setState(() {
      _answers.clear();
      _selectedTags.clear();
      _insights = [];
      _selectedInsightIndexes.clear();
      _reviewVisible = false;
      _currentPromptIndex = 0;
      _showSuccess = true;
      _selectedMood = 'focused';
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showSuccess = false);
      }
    });
  }

  String _relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    const bottomPadding = 118.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                    _commitEntry,
                const SingleActivator(LogicalKeyboardKey.enter, control: true):
                    _commitEntry,
                const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
                    _analyzeEntry,
                const SingleActivator(LogicalKeyboardKey.keyE, control: true):
                    _analyzeEntry,
                const SingleActivator(
                  LogicalKeyboardKey.keyL,
                  meta: true,
                ): () =>
                    _freeWriteFocus.requestFocus(),
                const SingleActivator(
                  LogicalKeyboardKey.keyL,
                  control: true,
                ): () =>
                    _freeWriteFocus.requestFocus(),
              },
              child: Focus(
                autofocus: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY DEBRIEF',
                        style: GoogleFonts.spaceGrotesk(
                          color: VyomaColors.textMuted,
                          fontSize: 12,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Journal as a guided conversation',
                        style: GoogleFonts.bitter(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Answer a few focused prompts, let AI extract context, then commit a clean memory record.',
                        style: GoogleFonts.ibmPlexSans(
                          color: VyomaColors.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Shortcuts: Cmd/Ctrl+E analyze, Cmd/Ctrl+Enter commit, Cmd/Ctrl+L focus notes',
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFF6C7E78),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: VyomaColors.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Debrief progress: $_answeredCount/${_prompts.length} prompts',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: _progress,
                                minHeight: 8,
                                backgroundColor: const Color(0xFF1D2A27),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  VyomaColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showSuccess) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: VyomaColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF83FFC9),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Debrief committed to Vault memory.',
                                style: GoogleFonts.ibmPlexSans(
                                  color: const Color(0xFF83FFC9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 920;
                          if (compact) {
                            return Column(
                              children: [
                                _buildInterviewCard(),
                                const SizedBox(height: 12),
                                _buildFreeWriteCard(),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: _buildInterviewCard()),
                              const SizedBox(width: 12),
                              Expanded(flex: 5, child: _buildFreeWriteCard()),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMoodPicker(),
                      const SizedBox(height: 10),
                      _buildTagRow(),
                      if (_reviewVisible) ...[
                        const SizedBox(height: 14),
                        _buildReviewPanel(),
                      ],
                      const SizedBox(height: 14),
                      _buildRecentCaptures(),
                      const SizedBox(height: 14),
                      _buildActionRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterviewCard() {
    final prompt = _prompts[_currentPromptIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VyomaColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: VyomaColors.bgCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
                ),
                child: Text(
                  'Question ${_currentPromptIndex + 1} of ${_prompts.length}',
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color(0xFF98EBC8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Previous prompt',
                onPressed: _currentPromptIndex == 0
                    ? null
                    : () => _jumpToPrompt(_currentPromptIndex - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: Colors.white70,
              ),
              IconButton(
                tooltip: 'Next prompt',
                onPressed: _currentPromptIndex == _prompts.length - 1
                    ? null
                    : () => _jumpToPrompt(_currentPromptIndex + 1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VyomaColors.bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              prompt.question,
              style: GoogleFonts.bitter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _answerController,
            minLines: 5,
            maxLines: 8,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Write your reflection here...',
              hintStyle: GoogleFonts.ibmPlexSans(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0B1110),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF273632)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF273632)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VyomaColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Quick starters',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF98AFA7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prompt.starters
                .map(
                  (starter) => _StarterChip(
                    label: starter,
                    onTap: () => _applyStarter(starter),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeWriteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VyomaColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Open notes',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Anything that did not fit the prompts can live here.',
            style: GoogleFonts.ibmPlexSans(
              color: VyomaColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: TextField(
              controller: _freeWriteController,
              focusNode: _freeWriteFocus,
              expands: true,
              maxLines: null,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 14,
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText:
                    'Capture context, loose thoughts, patterns, or unresolved threads...',
                hintStyle: GoogleFonts.ibmPlexSans(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0F0D0C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3D342D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3D342D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE9BE64)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VyomaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Mood signal',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          ..._moods.map((mood) {
            final active = mood == _selectedMood;
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = mood),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? VyomaColors.accent.withValues(alpha: 0.22)
                      : const Color(0xFF192320),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? VyomaColors.accent.withValues(alpha: 0.7)
                        : const Color(0xFF34443F),
                  ),
                ),
                child: Text(
                  mood,
                  style: GoogleFonts.ibmPlexMono(
                    color: active
                        ? const Color(0xFF90FFD2)
                        : const Color(0xFFB4C0BC),
                    fontSize: 11,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTagRow() {
    if (_selectedTags.isEmpty) {
      return Text(
        'No tags selected yet. Analyze once to auto-suggest tags.',
        style: GoogleFonts.ibmPlexSans(color: Colors.white38, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedTags
          .map(
            (tag) => GestureDetector(
              onTap: () => setState(() => _selectedTags.remove(tag)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: VyomaColors.bgCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
                ),
                child: Text(
                  '#$tag',
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color(0xFF8BFFD4),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildReviewPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VyomaColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI insight review',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Uncheck anything you do not want written into memory context.',
            style: GoogleFonts.ibmPlexSans(
              color: VyomaColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ..._insights.asMap().entries.map((entry) {
            final index = entry.key;
            final selected = _selectedInsightIndexes.contains(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedInsightIndexes.add(index);
                        } else {
                          _selectedInsightIndexes.remove(index);
                        }
                      });
                    },
                    activeColor: VyomaColors.accent,
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: entry.value,
                      onChanged: (value) => _insights[index] = value,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 13,
                      ),
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
    );
  }

  Widget _buildRecentCaptures() {
    return Consumer<MemoryService>(
      builder: (context, memory, _) {
        final recent = memory.getJournalEntries(limit: 3);
        if (recent.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VyomaColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
            ),
            child: Text(
              'No prior captures yet. Finish one debrief to start your memory timeline.',
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF9CA9B5),
                fontSize: 12,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent captures',
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFAFC5BC),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...recent.map(
              (entry) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VyomaColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: VyomaColors.accent.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.mood}  ${_relativeTime(entry.timestamp)}',
                            style: GoogleFonts.ibmPlexMono(
                              color: const Color(0xFF88A89E),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFFD1D9D6),
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
          ],
        );
      },
    );
  }

  Widget _buildActionRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;

        final buttons = <Widget>[
          _ActionButton(
            label: _isAnalyzing ? 'Analyzing...' : 'Analyze with AI',
            icon: Icons.auto_awesome,
            onTap: _isAnalyzing ? null : _analyzeEntry,
            tone: _ActionTone.secondary,
          ),
          _ActionButton(
            label: 'Commit to Vault',
            icon: Icons.cloud_upload_rounded,
            onTap: _commitEntry,
            tone: _ActionTone.primary,
          ),
          if (_reviewVisible)
            _ActionButton(
              label: 'Reset review',
              icon: Icons.restart_alt_rounded,
              onTap: () {
                setState(() {
                  _reviewVisible = false;
                  _insights = [];
                  _selectedInsightIndexes.clear();
                });
              },
              tone: _ActionTone.ghost,
            ),
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final button in buttons) ...[
                button,
                const SizedBox(height: 8),
              ],
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              buttons[i],
              if (i != buttons.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _DebriefPrompt {
  final String question;
  final List<String> starters;

  const _DebriefPrompt({required this.question, required this.starters});
}

class _StarterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StarterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF16211E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: VyomaColors.borderSubtle, width: 0.5),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFFBFD7CE),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

enum _ActionTone { primary, secondary, ghost }

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final _ActionTone tone;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    final colors = switch (tone) {
      _ActionTone.primary => (
        bg: const Color(0xFFE7BF69),
        fg: Colors.black,
        border: const Color(0xFFE7BF69),
      ),
      _ActionTone.secondary => (
        bg: const Color(0xFF1A2A26),
        fg: const Color(0xFF9BFFD7),
        border: const Color(0xFF36574E),
      ),
      _ActionTone.ghost => (
        bg: const Color(0xFF101718),
        fg: const Color(0xFFC8CFD2),
        border: const Color(0xFF3A4447),
      ),
    };

    return Opacity(
      opacity: isEnabled ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: colors.fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: colors.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
