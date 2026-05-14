import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/memory_service.dart';
import '../../core/services/daily_stats_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/vyoma_tokens.dart' show VyColors, VyType;
import '../../core/widgets/vy_card.dart';
import '../../core/widgets/vy_chip.dart';
import '../../core/widgets/vy_loader.dart';
import '../../core/widgets/vy_logo.dart';
import '../../ui/war_room_viewmodel.dart';

class VaultJournalView extends StatefulWidget {
  final String? initialSeed;
  final bool embedded;
  final bool oneLineMode;

  const VaultJournalView({
    super.key,
    this.initialSeed,
    this.embedded = true,
    this.oneLineMode = false,
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
  bool _streakPopped = false;
  bool _moreToolsExpanded = false;

  static const List<String> _moods = [
    'focused',
    'calm',
    'stressed',
    'unclear',
    'energized',
  ];
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
    if (widget.oneLineMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
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
      'Daily reflection':
          'Today I noticed...\n\nThe important part was...\n\nTomorrow I will...',
      'Plan tomorrow': 'Top 3 priorities for tomorrow:\n1. \n2. \n3. ',
      'Name current blocker':
          'Current blocker:\n\nWhy this is happening:\n\nFirst counter-move:',
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
    if (lower.contains('exam') ||
        lower.contains('assignment') ||
        lower.contains('study')) {
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
    if (lower.contains('anxious') ||
        lower.contains('stress') ||
        lower.contains('overwhelmed')) {
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
    final cues = [
      'will ',
      'need to ',
      'must ',
      'tomorrow',
      'next',
      'plan',
      'deadline',
    ];
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
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Future<void> _analyzeEntry() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;
    if (widget.oneLineMode) {
      await _commitEntry();
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final vm = context.read<WarRoomViewModel>();
      final insights = await vm.previewJournalInsights(text);

      setState(() {
        _insights = insights.isEmpty
            ? ['No strong extraction yet. You can still commit this entry.']
            : insights;
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
    final statsStore = context.read<DailyStatsStore>();
    final today = DateTime.now();
    final previousStreak = vm.journalStreakDays;
    await vm.submitJournalEntry(
      text: text,
      mood: _selectedMood,
      tags: _selectedTags.toList(),
      acceptedInsights: accepted,
    );

    final currentStats = await statsStore.loadForDate(today);
    await statsStore.save(
      currentStats.copyWith(
        journaled: true,
        focusMinutes: vm.currentMetrics.focusMinutes,
        tasksCompleted: vm.currentMetrics.tasksCompleted,
      ),
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

    if (mounted && vm.journalStreakDays > previousStreak) {
      if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
        setState(() => _streakPopped = true);
        Future<void>.delayed(const Duration(milliseconds: 260), () {
          if (mounted) setState(() => _streakPopped = false);
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Streak +1',
            style: VyType.body.copyWith(color: VyColors.textPrimary),
          ),
          backgroundColor: VyColors.surface1,
        ),
      );
    }

    if (widget.oneLineMode && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reflection saved, streak protected.')),
      );
      Navigator.of(context).maybePop();
    }
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
                SingleActivator(LogicalKeyboardKey.enter, meta: true):
                    _commitEntry,
                SingleActivator(LogicalKeyboardKey.enter, control: true):
                    _commitEntry,
                SingleActivator(LogicalKeyboardKey.keyE, meta: true):
                    _analyzeEntry,
                SingleActivator(LogicalKeyboardKey.keyE, control: true):
                    _analyzeEntry,
                SingleActivator(LogicalKeyboardKey.keyL, meta: true): () =>
                    _focusNode.requestFocus(),
                SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
                    _focusNode.requestFocus(),
              },
              child: Focus(
                autofocus: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final editorHeight = (constraints.maxHeight * 0.32).clamp(
                      220.0,
                      420.0,
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!widget.embedded &&
                              Navigator.of(context).canPop())
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: VyColors.textMuted,
                                  size: 18,
                                ),
                                tooltip: 'Back',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const VyMark(size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'VAULT',
                                style: VyType.sectionLabel.copyWith(
                                  fontSize: 10,
                                  color: VyColors.textMuted,
                                  letterSpacing: 2.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The Vault',
                            style: VyType.display.copyWith(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Turn raw experience into usable context. Capture what happened, what it meant, and what changes next.',
                            style: VyType.bodyMuted.copyWith(height: 1.45),
                          ),
                          const SizedBox(height: 10),
                          Consumer<WarRoomViewModel>(
                            builder: (context, vm, _) {
                              final streak = vm.journalStreakDays;
                              return Row(
                                children: [
                                  AnimatedScale(
                                    scale: _streakPopped ? 1.08 : 1.0,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    child: Text(
                                      'Journal streak: $streak day${streak == 1 ? '' : 's'}',
                                      style: VyType.bodyMuted.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedOpacity(
                                    opacity: streak >= 3 ? 1 : 0,
                                    duration: const Duration(milliseconds: 180),
                                    child: const Icon(
                                      Icons.local_fire_department_outlined,
                                      color: AppColors.goldDim,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          if (widget.oneLineMode) ...[
                            VyCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'One-line reflection',
                                    style: VyText.titleMedium,
                                  ),
                                  const SizedBox(height: VySpacing.xs),
                                  Text(
                                    'Write one sentence about how today went.',
                                    style: VyText.bodyMedium,
                                  ),
                                  const SizedBox(height: VySpacing.md),
                                  TextField(
                                    controller: _journalController,
                                    focusNode: _focusNode,
                                    maxLines: 2,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    smartDashesType: SmartDashesType.disabled,
                                    smartQuotesType: SmartQuotesType.disabled,
                                    spellCheckConfiguration:
                                        const SpellCheckConfiguration.disabled(),
                                    style: VyText.bodyLarge,
                                    decoration: InputDecoration(
                                      hintText:
                                          'One line that captures your day...',
                                      hintStyle: VyText.bodyMedium.copyWith(
                                        color: VyColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            GestureDetector(
                              onTap: () {
                                setState(
                                  () =>
                                      _moreToolsExpanded = !_moreToolsExpanded,
                                );
                              },
                              child: VyCard(
                                child: Row(
                                  children: [
                                    Text(
                                      'More tools',
                                      style: VyText.titleMedium,
                                    ),
                                    const Spacer(),
                                    Icon(
                                      _moreToolsExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_moreToolsExpanded) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: VyColors.surface2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: VyColors.border,
                                    width: 0.9,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Context Capture Protocol',
                                      style: VyType.heading.copyWith(fontSize: 15),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '1) State facts clearly\n2) Mark the emotional signal\n3) Define the next controllable action',
                                      style: VyType.caption.copyWith(
                                        color: VyColors.textMuted,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                          Consumer2<WarRoomViewModel, MemoryService>(
                            builder: (context, vm, memory, _) {
                              final allForTheme =
                                  memory.getJournalEntries(limit: 500);
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaPill(
                                    label: 'Streak',
                                    value: '${vm.journalStreakDays}d',
                                  ),
                                  _MetaPill(
                                    label: 'Top theme',
                                    value: _topTheme(allForTheme),
                                  ),
                                  _MetaPill(
                                    label: 'Entries',
                                    value: '${memory.getJournalEntryCount()}',
                                  ),
                                ],
                              );
                            },
                          ),
                          if (!widget.oneLineMode && _moreToolsExpanded) ...[
                            const SizedBox(height: 20),
                            Text(
                              'TEMPLATES',
                              style: VyType.sectionLabel.copyWith(fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _templates
                                  .map(
                                    (t) => _ChipButton(
                                      label: t,
                                      onTap: () => _applyTemplate(t),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'GUIDED PROMPTS',
                              style: VyType.sectionLabel.copyWith(fontSize: 10),
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
                                  style: VyType.caption.copyWith(
                                    color: VyColors.textMuted,
                                  ),
                                ),
                                ..._moods.map((m) {
                                  final active = m == _selectedMood;
                                  return VyChip(
                                    label: m,
                                    selected: active,
                                    onTap: () =>
                                        setState(() => _selectedMood = m),
                                  );
                                }),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedTags
                                .map(
                                  (tag) => _ChipButton(
                                    label: '#$tag',
                                    active: true,
                                    onTap: () => setState(
                                      () => _selectedTags.remove(tag),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _MetaPill(
                                label: 'Words',
                                value: '${_wordCount(textNow)}',
                              ),
                              const SizedBox(width: 8),
                              _MetaPill(
                                label: 'Action cues',
                                value: '${_actionableEstimate(textNow)}',
                              ),
                              const SizedBox(width: 8),
                              _MetaPill(
                                label: 'Auto tags',
                                value: '${_autoTagsFromText(textNow).length}',
                              ),
                            ],
                          ),
                          if (!widget.oneLineMode) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: editorHeight,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: VyColors.surface1,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: VyColors.border,
                                    width: 0.9,
                                  ),
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
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      obscureText: false,
                                      spellCheckConfiguration:
                                          SpellCheckConfiguration.disabled(),
                                      style: VyType.body.copyWith(height: 1.7),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText:
                                            'What happened? What does it mean? What changes next?',
                                        hintStyle: VyType.bodyMuted.copyWith(
                                          color: VyColors.textFaint,
                                        ),
                                      ),
                                    ),
                                    if (_showSuccess)
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              color: AppColors.gold,
                                              size: 48,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Context synchronized',
                                              style: VyType.accent.copyWith(
                                                fontSize: 13,
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
                          if (_reviewVisible) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: VyColors.surface2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: VyColors.border,
                                  width: 0.9,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Extraction Review',
                                    style: VyType.heading.copyWith(fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Accept, edit, or deselect insights before they shape future intelligence.',
                                    style: VyType.caption.copyWith(
                                      color: VyColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ..._insights.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final selected = _selectedInsightIndexes
                                        .contains(idx);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: selected,
                                            onChanged: (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selectedInsightIndexes.add(
                                                    idx,
                                                  );
                                                } else {
                                                  _selectedInsightIndexes
                                                      .remove(idx);
                                                }
                                              });
                                            },
                                          ),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: entry.value,
                                              onChanged: (v) =>
                                                  _insights[idx] = v,
                                              style: VyType.body.copyWith(
                                                fontSize: 13,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                filled: true,
                                                fillColor: VyColors.surface1,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: const BorderSide(
                                                    color: VyColors.border,
                                                  ),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: const BorderSide(
                                                    color: VyColors.border,
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: const BorderSide(
                                                    color: VyColors.goldDim,
                                                  ),
                                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 28,
                                  ),
                                  decoration: BoxDecoration(
                                    color: VyColors.surface1,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: VyColors.border,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const VyMark(size: 48),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Nothing here yet',
                                        textAlign: TextAlign.center,
                                        style: VyType.heading.copyWith(
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Your reflections stay private — only you and Vyoma see them.',
                                        textAlign: TextAlign.center,
                                        style: VyType.bodyMuted.copyWith(
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
                                    style: VyType.sectionLabel.copyWith(
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...recent.map((e) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: VyColors.surface2,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: VyColors.borderSubtle,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.text,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: VyType.caption.copyWith(
                                              color: VyColors.textMuted,
                                            ),
                                          ),
                                          if (e.tags.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: e.tags
                                                  .take(6)
                                                  .map(
                                                    (t) => Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: VyColors.surface1,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                999),
                                                        border: Border.all(
                                                          color:
                                                              VyColors.border,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        t,
                                                        style: VyType.caption
                                                            .copyWith(
                                                          fontSize: 10,
                                                          color:
                                                              VyColors.goldDim,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ],
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: VyLoader(),
                    )
                  : Text(
                      _reviewVisible ? 'Re-analyze' : 'Analyze Entry',
                      style: VyType.accent.copyWith(
                        color: VyColors.textPrimary,
                        letterSpacing: 1.2,
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
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'Commit to Memory',
              style: VyType.accent.copyWith(
                color: VyColors.background,
                letterSpacing: 1.2,
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
        style: VyType.caption.copyWith(color: VyColors.textMuted),
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
    final labelStyle = VyType.caption.copyWith(
      fontSize: 11,
      color: VyColors.textMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final valueStyle = VyType.caption.copyWith(
      fontSize: 11,
      color: VyColors.textPrimary,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VyColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VyColors.border, width: 0.8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: labelStyle),
            TextSpan(text: value, style: valueStyle),
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
        ? AppColors.gold.withValues(alpha: 0.12)
        : subtle
            ? VyColors.surface2
            : VyColors.surface1;
    final border = active
        ? AppColors.gold.withValues(alpha: 0.45)
        : VyColors.border;

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
            style: VyType.caption.copyWith(
              fontSize: 11,
              color: active ? VyColors.gold : VyColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
