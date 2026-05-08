import 'package:flutter/widgets.dart';

/// Global keys shared by [TutorialOverlay] targets. Attach to widgets in
/// [CommandDock], [ChatSheet], etc.
abstract final class VyomaTutorialKeys {
  static final GlobalKey chatInputBar = GlobalKey(debugLabel: 'tutorial_chat_input');
  static final GlobalKey navWarRoom = GlobalKey(debugLabel: 'tutorial_nav_war_room');
  static final GlobalKey navTimetable = GlobalKey(debugLabel: 'tutorial_nav_timetable');
  static final GlobalKey navFriends = GlobalKey(debugLabel: 'tutorial_nav_friends');
  static final GlobalKey navJournal = GlobalKey(debugLabel: 'tutorial_nav_journal');
  static final GlobalKey wakeupCard = GlobalKey(debugLabel: 'wakeupCard');
  static final GlobalKey calendarGrid = GlobalKey(debugLabel: 'calendarGrid');
  static final GlobalKey pendingActionCard = GlobalKey(debugLabel: 'pendingActionCard');
  static final GlobalKey commandDock = GlobalKey(debugLabel: 'commandDock');
}
