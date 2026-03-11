import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Add font import
import 'core/auth_manager.dart';
import 'core/auth_manager_desktop.dart';
import 'core/calendar_service.dart';
import 'core/ai_service.dart';
import 'core/memory_service.dart'; // Added
import 'ui/war_room_viewmodel.dart';
import 'ui/home_screen.dart'; // New Import
import 'ui/onboarding_screen.dart'; // Added

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
          create: (_) => AuthManagerDesktop(), // Changed to AuthManagerDesktop
        ),
        
        // 2. Services (Dependent on Auth or Standalone)
        ChangeNotifierProvider<MemoryService>(
          create: (_) => MemoryService()..init(), // Init memory immediately
        ),
        ChangeNotifierProvider<AIService>(
           create: (context) => AIService(Provider.of<MemoryService>(context, listen: false)),
        ),
        ProxyProvider<AuthManager, CalendarService>(
          update: (_, auth, __) => CalendarService(auth),
        ),

        // 3. ViewModels (Dependent on Services)
        ChangeNotifierProxyProvider2<CalendarService, AIService, WarRoomViewModel>(
          create: (context) => WarRoomViewModel(
            calendarService: Provider.of<CalendarService>(context, listen: false),
            aiService: Provider.of<AIService>(context, listen: false),
          ),
          update: (_, calendar, ai, previous) => WarRoomViewModel(
            calendarService: calendar,
            aiService: ai,
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
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
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
            home: memory.hasOnboarded ? const HomeScreen() : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
