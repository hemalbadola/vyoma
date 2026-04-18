import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/memory_service.dart';
import '../core/permission_manager.dart';
import '../core/wakeup_service.dart';
import 'screens/wakeup_screen.dart';
import 'tabs/mission_tab.dart';
import 'tabs/intel_tab.dart';
import 'tabs/timetable_tab.dart'; // Added
import 'widgets/chat_sheet.dart';
import 'widgets/command_dock.dart';
import 'widgets/background_mesh.dart';
import 'widgets/api_key_manager.dart';
import 'widgets/vault_journal_view.dart';
import 'screens/notifications_screen.dart';
import 'screens/friends_hub_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/settings_hub_screen.dart';
import 'widgets/debug_seeder.dart';
import '../core/user_service.dart';
import '../core/telemetry_service.dart';
import 'package:google_fonts/google_fonts.dart';

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

  final List<Widget> _tabs = [
    const MissionTab(),
    const IntelTab(),
    const VaultJournalView(), // Tab Index 2
    const TimetableTab(), // Tab Index 3
    const FriendsHubScreen(), // Tab Index 4
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSystemStatus();
  }

  @override
  void dispose() {
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
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ChatSheet(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuart;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
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
                          _UtilityButton(
                            icon: Icons.notifications_active_outlined,
                            tooltip: 'Notifications',
                            color: Colors.orangeAccent,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _UtilityButton(
                            icon: Icons.bug_report_rounded,
                            tooltip: 'API Key Manager',
                            color: Colors.cyanAccent,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => const Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: ApiKeyManager(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
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
                // 4. Debug Database Seeder (Only in debug mode)
                const Positioned(
                  bottom: 120, // Above command dock
                  right: 16,
                  child: SafeArea(child: DebugSeeder()),
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
