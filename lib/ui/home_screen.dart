import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/memory_service.dart';
import '../core/permission_manager.dart';
import '../core/wakeup_service.dart';
import '../core/ai_service.dart'; // Add AIService import
import 'screens/wakeup_screen.dart';
import 'tabs/mission_tab.dart';
import 'tabs/intel_tab.dart';
import 'widgets/chat_sheet.dart';
import 'widgets/command_dock.dart';
import 'widgets/background_mesh.dart';
import 'widgets/api_key_manager.dart';

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
          _tabs[_currentIndex],

          // 2. Floating Command Dock
          CommandDock(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            onCommand: () => _showComms(context),
          ),
          
          // 3. Debug Button (Top Right)
          Positioned(
            top: 50,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white24,
              child: const Icon(Icons.bug_report, color: Colors.cyanAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const Dialog(
                    backgroundColor: Colors.transparent,
                    child: ApiKeyManager(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
