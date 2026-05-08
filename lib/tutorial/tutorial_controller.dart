import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tutorial_keys.dart';
import 'tutorial_step.dart';

/// Drives story-mode tutorial flow and persists completion.
class TutorialController extends ChangeNotifier {
  TutorialController() : _steps = _buildDefaultSteps();

  static const String prefKeyCompleted = 'tutorial_completed_v1';

  final List<TutorialStep> _steps;
  List<TutorialStep> get steps => List.unmodifiable(_steps);

  int _currentStepIndex = 0;
  int get currentStepIndex => _currentStepIndex;

  bool _isActive = false;
  bool get isActive => _isActive;

  TutorialStep get currentStep => _steps[_currentStepIndex];

  static List<TutorialStep> _buildDefaultSteps() {
    return [
      TutorialStep(
        stepId: 'mission_console',
        targetWidgetKey: VyomaTutorialKeys.chatInputBar,
        title: 'This is your Mission Console',
        description:
            'Type anything — schedule a class, set a reminder, start a focus session. Vyoma understands natural language.',
        arrowDirection: TutorialArrowDirection.top,
        highlightShape: TutorialHighlightShape.rectangle,
      ),
      TutorialStep(
        stepId: 'war_room_nav',
        targetWidgetKey: VyomaTutorialKeys.navWarRoom,
        title: 'Your Command Center',
        description: 'The War Room is where everything happens. Start here every day.',
        arrowDirection: TutorialArrowDirection.bottom,
        highlightShape: TutorialHighlightShape.rectangle,
      ),
      TutorialStep(
        stepId: 'timetable_nav',
        targetWidgetKey: VyomaTutorialKeys.navTimetable,
        title: 'Your Weekly Map',
        description:
            'Your class schedule lives here. Vyoma uses it to plan around your real life.',
        arrowDirection: TutorialArrowDirection.bottom,
        highlightShape: TutorialHighlightShape.rectangle,
      ),
      TutorialStep(
        stepId: 'friends_nav',
        targetWidgetKey: VyomaTutorialKeys.navFriends,
        title: 'Your Squad',
        description:
            'Add friends and stay accountable together. Vyoma tracks momentum — yours and theirs.',
        arrowDirection: TutorialArrowDirection.bottom,
        highlightShape: TutorialHighlightShape.rectangle,
      ),
      TutorialStep(
        stepId: 'journal_nav',
        targetWidgetKey: VyomaTutorialKeys.navJournal,
        title: 'Your Private Space',
        description:
            'Journal, reflect, and let Vyoma extract insights from your writing.',
        arrowDirection: TutorialArrowDirection.bottom,
        highlightShape: TutorialHighlightShape.rectangle,
      ),
      TutorialStep(
        stepId: 'ready_console',
        targetWidgetKey: VyomaTutorialKeys.chatInputBar,
        title: 'You\'re ready.',
        description:
            'Try saying: \'Schedule my physics lab tomorrow at 2pm for 2 hours.\' Watch what happens.',
        arrowDirection: TutorialArrowDirection.top,
        highlightShape: TutorialHighlightShape.rectangle,
        canSkip: false,
      ),
    ];
  }

  /// Load prefs and start tutorial when not completed.
  Future<void> hydrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(prefKeyCompleted) ?? false;
      if (!completed) {
        start();
      }
    } catch (e, st) {
      debugPrint('[TutorialController] hydrateFromPrefs: $e\n$st');
    }
  }

  void start() {
    _currentStepIndex = 0;
    _isActive = true;
    notifyListeners();
  }

  void next() {
    if (!_isActive) return;
    if (_currentStepIndex >= _steps.length - 1) {
      complete();
      return;
    }
    _currentStepIndex += 1;
    notifyListeners();
  }

  void skip() {
    if (!_isActive) return;
    if (!currentStep.canSkip) return;
    complete();
  }

  Future<void> complete() async {
    _isActive = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKeyCompleted, true);
    } catch (e, st) {
      debugPrint('[TutorialController] complete: $e\n$st');
    }
    notifyListeners();
  }
}
