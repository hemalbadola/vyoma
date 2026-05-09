import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../data/dharma_chapter_models.dart';
import '../../domain/dharma_map_service.dart';

class DharmaMapScreen extends StatelessWidget {
  const DharmaMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DharmaMapService>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('dharma map', style: VyType.heading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.background,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _NewChapterScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          'NEW CHAPTER',
          style: VyType.accent.copyWith(
            color: AppColors.background,
            letterSpacing: 2.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'three-month chapters.\none theme. one master skill. three outcomes.',
                style: VyType.bodyMuted.copyWith(height: 1.6),
              ),
              const SizedBox(height: 28),
              if (svc.currentChapter != null) ...[
                Text('CURRENT', style: VyType.sectionLabel),
                const SizedBox(height: 8),
                _ChapterCard(chapter: svc.currentChapter!, isOpen: true),
                const SizedBox(height: 28),
              ],
              if (svc.chapters.where((c) => !c.isOpen).isNotEmpty) ...[
                Text('CLOSED', style: VyType.sectionLabel),
                const SizedBox(height: 8),
                ...svc.chapters.reversed
                    .where((c) => !c.isOpen)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChapterCard(chapter: c, isOpen: false),
                      ),
                    ),
              ],
              if (svc.chapters.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'no chapter yet.',
                    style: VyType.bodyMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.isOpen});

  final DharmaChapter chapter;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? AppColors.gold : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter.themeWord,
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 36,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chapter.masterSkill,
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 16,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 16),
          ...chapter.outcomes.map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.goldDim,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Text(o, style: VyType.body)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isOpen
                ? 'started ${fmt.format(chapter.startedAt)}'
                : 'closed ${fmt.format(chapter.closedAt!)}',
            style: VyType.caption,
          ),
          if (isOpen) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  context.read<DharmaMapService>().closeCurrent(),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'close chapter',
                style: VyType.caption.copyWith(
                  color: AppColors.errorColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NewChapterScreen extends StatefulWidget {
  const _NewChapterScreen();

  @override
  State<_NewChapterScreen> createState() => _NewChapterScreenState();
}

class _NewChapterScreenState extends State<_NewChapterScreen> {
  final _theme = TextEditingController();
  final _skill = TextEditingController();
  final _o1 = TextEditingController();
  final _o2 = TextEditingController();
  final _o3 = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _theme.dispose();
    _skill.dispose();
    _o1.dispose();
    _o2.dispose();
    _o3.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<DharmaMapService>().startChapter(
            themeWord: _theme.text,
            masterSkill: _skill.text,
            outcomes: [_o1.text, _o2.text, _o3.text],
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('new chapter', style: VyType.heading),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THEME WORD', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _theme,
                style: VyType.body,
                decoration:
                    const InputDecoration(hintText: 'rigor, softness, shipping'),
              ),
              const SizedBox(height: 24),
              Text('MASTER SKILL', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _skill,
                style: VyType.body,
                decoration: const InputDecoration(
                  hintText: 'writing, mandarin, research',
                ),
              ),
              const SizedBox(height: 24),
              Text('THREE OUTCOMES', style: VyType.sectionLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _o1,
                style: VyType.body,
                decoration:
                    const InputDecoration(hintText: 'concrete deliverable'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _o2,
                style: VyType.body,
                decoration:
                    const InputDecoration(hintText: 'concrete deliverable'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _o3,
                style: VyType.body,
                decoration:
                    const InputDecoration(hintText: 'concrete deliverable'),
              ),
              const SizedBox(height: 32),
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
                  onPressed: _submitting ? null : _submit,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'BEGIN',
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
