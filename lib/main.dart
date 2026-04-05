import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Add font import
import 'package:shared_preferences/shared_preferences.dart';
import 'core/auth_manager.dart';
import 'core/calendar_service.dart';
import 'core/ai_service.dart';
import 'core/memory_service.dart'; 
import 'core/timetable_service.dart'; // Added
import 'core/notification_service.dart';
import 'ui/war_room_viewmodel.dart';
import 'ui/home_screen.dart'; 
import 'ui/onboarding_screen.dart';

void main() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.deepPurple,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Text(
              "FLUTTER ERROR:\n${details.exception}\n\nStack:\n${details.stack}",
              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Courier'),
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ),
    );
  };
  runApp(const VyomaApp());
}

class VyomaApp extends StatelessWidget {
  const VyomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Auth (Singleton Factory)
        Provider<AuthManager>(
          create: (_) => AuthManager(),
        ),
        
        // 2. Services (Dependent on Auth or Standalone)
        ChangeNotifierProvider<MemoryService>(
          create: (_) => MemoryService()..init(), // Init memory immediately
        ),
        ChangeNotifierProvider<AIService>(
           create: (context) => AIService(Provider.of<MemoryService>(context, listen: false)),
        ),
        ProxyProvider<AuthManager, CalendarService>(
          update: (_, auth, previous) => previous ?? CalendarService(auth),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        ChangeNotifierProxyProvider<CalendarService, TimetableService>(
          create: (context) => TimetableService(Provider.of<CalendarService>(context, listen: false)),
          update: (_, calendar, previous) => previous ?? TimetableService(calendar),
        ),

        // 3. ViewModels (Dependent on Services)
        ChangeNotifierProxyProvider4<CalendarService, AIService, TimetableService, NotificationService, WarRoomViewModel>(
          create: (context) => WarRoomViewModel(
            calendarService: Provider.of<CalendarService>(context, listen: false),
            aiService: Provider.of<AIService>(context, listen: false),
            timetableService: Provider.of<TimetableService>(context, listen: false),
            notificationService: Provider.of<NotificationService>(context, listen: false),
          ),
          // Keep a stable VM instance; recreating it causes repeated session reloads.
          update: (_, calendar, ai, timetable, notifications, previous) =>
              previous ?? WarRoomViewModel(
                calendarService: calendar,
                aiService: ai,
                timetableService: timetable,
                notificationService: notifications,
              ),
        ),
      ],
      child: Consumer<MemoryService>(
        builder: (context, memory, _) {
          if (!memory.isInitialized) {
            return const MaterialApp(home: Scaffold(backgroundColor: Colors.black)); // Splash
          }

          return MaterialApp(
            title: 'Vyoma',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF0A0A0F),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF7C3AED),      // Deep violet
                secondary: Color(0xFF06B6D4),    // Cyan accent
                tertiary: Color(0xFFA855F7),     // Light violet
                surface: Color(0xFF0F0F1A),      // Deep space black
                onSurface: Color(0xFFE2E8F0),    // Light gray text
              ),
              textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            ),
            builder: (context, child) {
              return Stack(
                children: [
                  if (child != null) child,
                  
                  // Global Debug Status Panel
                  if (kDebugMode)
                  Positioned(
                    bottom: 120, 
                    right: 20,
                    child: Consumer<AIService>(
                      builder: (context, aiService, _) => StreamBuilder<String>(
                        stream: aiService.debugStatusStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          
                          return Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 300),
                                child: Text(
                                  snapshot.data!,
                                  style: GoogleFonts.robotoMono(
                                    color: snapshot.data!.contains('Error') || snapshot.data!.contains('Failed') 
                                        ? const Color(0xFFFF5252) 
                                        : const Color(0xFF69F0AE),
                                    fontSize: 11,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            home: const _LaunchGate(),
          );
        },
      ),
    );
  }
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    return _onboardingComplete! ? const HomeScreen() : const OnboardingScreen();
  }
}
