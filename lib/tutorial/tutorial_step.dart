import 'package:flutter/widgets.dart';

enum TutorialArrowDirection { top, bottom, left, right }

enum TutorialHighlightShape { circle, rectangle }

/// One spotlight step in the story-mode tutorial.
class TutorialStep {
  const TutorialStep({
    required this.stepId,
    required this.targetWidgetKey,
    required this.title,
    required this.description,
    required this.arrowDirection,
    required this.highlightShape,
    this.canSkip = true,
  });

  final String stepId;
  final GlobalKey targetWidgetKey;
  final String title;
  final String description;
  final TutorialArrowDirection arrowDirection;
  final TutorialHighlightShape highlightShape;
  final bool canSkip;
}
