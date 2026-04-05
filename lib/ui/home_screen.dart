import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const MissionTab(),
    const IntelTab(),
    const VaultJournalView(), // Tab Index 2
    const TimetableTab(), // Tab Index 3
  ];

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
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
    return Scaffold(
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
                  ],
                ),
              ),
            ),
          ),
        ],
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
