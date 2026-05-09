import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vyoma/agent_debug_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tutorial_keys.dart';
import 'tutorial_step.dart';

/// Drives story-mode tutorial flow and persists completion.
class TutorialController extends ChangeNotifier {
  TutorialController() : _steps = _buildDefaultSteps();

  static const String prefKeyCompleted = 'tutorial_completed_v1';
  static const String _prefKeyLastTutorialUid = 'tutorial_last_uid_v1';

  final List<TutorialStep> _steps;
  List<TutorialStep> get steps => List.unmodifiable(_steps);

  int _currentStepIndex = 0;
  int get currentStepIndex => _currentStepIndex;

  bool _isActive = false;
  bool get isActive => _isActive;

  TutorialStep get currentStep => _steps[_currentStepIndex];

  Future<void> _debugLog({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // #region agent log
    await agentDebugNdjsonLog(
      runId: 'pre-fix-1',
      hypothesisId: hypothesisId,
      location: location,
      message: message,
      data: data,
    );
    // #endregion
  }

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
        description:
            'The War Room is where everything happens. Start here every day.',
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
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      final lastTutorialUid = prefs.getString(_prefKeyLastTutorialUid);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final isDifferentSignedInUser =
          currentUid != null &&
          lastTutorialUid != null &&
          currentUid != lastTutorialUid;
      await _debugLog(
        hypothesisId: 'H2',
        location: 'tutorial_controller.dart:hydrateFromPrefs',
        message: 'Hydrate tutorial prefs',
        data: {
          'completed': completed,
          'onboardingComplete': onboardingComplete,
          'currentUid': currentUid,
          'lastTutorialUid': lastTutorialUid,
          'isDifferentSignedInUser': isDifferentSignedInUser,
          'isActiveBefore': _isActive,
        },
      );
      if (onboardingComplete && (!completed || isDifferentSignedInUser)) {
        start();
      }
    } catch (e, st) {
      debugPrint('[TutorialController] hydrateFromPrefs: $e\n$st');
    }
  }

  void start() {
    _currentStepIndex = 0;
    _isActive = true;
    _debugLog(
      hypothesisId: 'H2',
      location: 'tutorial_controller.dart:start',
      message: 'Tutorial started',
      data: {'stepCount': _steps.length},
    );
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await prefs.setString(_prefKeyLastTutorialUid, uid);
      }
    } catch (e, st) {
      debugPrint('[TutorialController] complete: $e\n$st');
    }
    notifyListeners();
  }
}
