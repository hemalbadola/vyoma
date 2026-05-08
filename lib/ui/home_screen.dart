import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/memory_service.dart';
import '../core/permission_manager.dart';
import '../core/notification_service.dart';
import '../core/wakeup_service.dart';
import 'screens/wakeup_screen.dart';
import 'tabs/mission_tab.dart';
import 'tabs/intel_tab.dart';
import 'tabs/timetable_tab.dart'; // Added
import 'widgets/chat_sheet.dart';
import 'widgets/command_dock.dart';
import 'widgets/background_mesh.dart';
import 'widgets/vault_journal_view.dart';
import 'screens/friends_hub_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/settings_hub_screen.dart';
import 'screens/notifications_screen.dart';
import '../core/user_service.dart';
import '../core/telemetry_service.dart';
import '../tutorial/tutorial_controller.dart';
import '../tutorial/tutorial_keys.dart';

class _OpenCommsIntent extends Intent {
  const _OpenCommsIntent();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  TutorialController? _tutorialController;

  final List<Widget> _tabs = [
    const MissionTab(),
    const IntelTab(),
    const VaultJournalView(), // Tab Index 2
    const TimetableTab(), // Tab Index 3
    const FriendsHubScreen(), // Tab Index 4
  ];

  void _tutorialListener() {
    if (!mounted) return;
    final tc = _tutorialController;
    if (tc == null) return;

    if (!tc.isActive) {
      _closeChatSheetsForTutorial();
      return;
    }
    _applyTutorialPresentation(tc);
  }

  void _closeChatSheetsForTutorial() {
    final nav = Navigator.of(context, rootNavigator: true);
    var guard = 0;
    while (ChatSheetPresentation.presentCount > 0 && nav.canPop() && guard < 8) {
      nav.pop();
      guard++;
    }
  }

  void _applyTutorialPresentation(TutorialController tc) {
    final nav = Navigator.of(context, rootNavigator: true);
    final idx = tc.currentStepIndex;
    final needsChat = idx == 0 || idx == 5;

    if (needsChat) {
      if (ChatSheetPresentation.presentCount == 0) {
        nav.push(ChatSheet.slideUpRoute());
      }
    } else {
      var guard = 0;
      while (ChatSheetPresentation.presentCount > 0 && nav.canPop() && guard < 8) {
        nav.pop();
        guard++;
      }
    }

    var tabIndex = _currentIndex;
    switch (idx) {
      case 1:
        tabIndex = 0;
        break;
      case 2:
        tabIndex = 3;
        break;
      case 3:
        tabIndex = 4;
        break;
      case 4:
        tabIndex = 2;
        break;
      default:
        break;
    }
    if (tabIndex != _currentIndex) {
      setState(() => _currentIndex = tabIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSystemStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final tc = context.read<TutorialController>();
      _tutorialController = tc;
      tc.addListener(_tutorialListener);
      await tc.hydrateFromPrefs();
      if (!mounted) return;
      _tutorialListener();
    });
  }

  @override
  void dispose() {
    _tutorialController?.removeListener(_tutorialListener);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final telemetry = context.read<TelemetryService>();
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      debugPrint("LIFECYCLE_DEBUG: App Backgrounded/Paused. Entering Power Save Mode.");
      telemetry.notifyAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("LIFECYCLE_DEBUG: App Resumed. Entering High Fidelity Mode.");
      telemetry.notifyAppForegrounded();
    }
  }

  Future<void> _checkSystemStatus() async {
    // 1. Request Permissions (Silent if already granted)
    await PermissionManager.requestAll();

    // 2. Check Wakeup Protocol
    if (!mounted) return;
    final memory = Provider.of<MemoryService>(context, listen: false);
    final wakeupService = WakeupService(memory);

    if (await wakeupService.shouldTriggerProtocol()) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => WakeupScreen(
            onWakeupConfirmed: () async {
              await wakeupService.confirmWakeup();
              if (mounted) Navigator.of(context).pop();
            }
          )
        )
      );
    }
  }

  void _showComms(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(ChatSheet.slideUpRoute());
  }

  @override
  Widget build(BuildContext context) {
    final userSvc = context.watch<UserService>();
    if (!userSvc.isProfileLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4))),
      );
    }
    
    if (!userSvc.hasProfile) {
      return const ProfileSetupScreen();
    }

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, meta: true): _OpenCommsIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _OpenCommsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommsIntent: CallbackAction<_OpenCommsIntent>(
            onInvoke: (_) {
              _showComms(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // 0. Ambient Background
                const BackgroundMesh(),

                // 1. Tab Content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(_currentIndex),
                    child: _tabs[_currentIndex],
                  ),
                ),

                // 2. Floating Command Dock
                CommandDock(
                  currentIndex: _currentIndex,
                  navWarRoomKey: VyomaTutorialKeys.navWarRoom,
                  navJournalKey: VyomaTutorialKeys.navJournal,
                  navScheduleKey: VyomaTutorialKeys.navTimetable,
                  navCircleKey: VyomaTutorialKeys.navFriends,
                  onTap: (index) => setState(() => _currentIndex = index),
                  onCommand: () => _showComms(context),
                ),
                
                // 3. Utility Rail (Top Right)
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101114),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A2A2A), width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          StreamBuilder<int>(
                            stream: context.read<NotificationService>().unreadCount,
                            builder: (context, snapshot) {
                              final unread = snapshot.data ?? 0;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _UtilityButton(
                                    icon: Icons.notifications_rounded,
                                    tooltip: 'Notification Inbox',
                                    color: Colors.white70,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (unread > 0)
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          _UtilityButton(
                            icon: Icons.settings_rounded,
                            tooltip: 'Settings Hub',
                            color: Colors.white70,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsHubScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UtilityButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _UtilityButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  State<_UtilityButton> createState() => _UtilityButtonState();
}

class _UtilityButtonState extends State<_UtilityButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.color, size: 18),
          ),
        ),
      ),
    );
  }
}
