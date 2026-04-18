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
import 'core/task_service.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'core/notification_service.dart';
import 'core/user_service.dart';
import 'core/friend_service.dart';
import 'core/cofocus_service.dart';
import 'core/accountability_service.dart';
import 'core/ping_service.dart';
import 'core/telemetry_service.dart';
import 'ui/war_room_viewmodel.dart';
import 'ui/home_screen.dart'; 
import 'ui/onboarding_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  if (!kReleaseMode) {
    try {
      await dotenv.load(fileName: '.env.local');
    } catch (_) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('Failed to load local env file: $e');
      }
    }
  }

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
          create: (_) {
            debugPrint('PROVIDER_DEBUG: Creating AuthManager...');
            final a = AuthManager();
            debugPrint('PROVIDER_DEBUG: AuthManager CREATED OK');
            return a;
          },
        ),
        
        // 2. Services (Dependent on Auth or Standalone)
        ChangeNotifierProvider<MemoryService>(
          create: (_) {
            debugPrint('PROVIDER_DEBUG: Creating MemoryService...');
            final m = MemoryService()..init();
            debugPrint('PROVIDER_DEBUG: MemoryService CREATED OK');
            return m;
          },
        ),
        ChangeNotifierProvider<UserService>(
          create: (_) {
            debugPrint('PROVIDER_DEBUG: Creating UserService...');
            return UserService();
          },
        ),
        ChangeNotifierProvider<FriendService>(
          create: (_) {
            debugPrint('PROVIDER_DEBUG: Creating FriendService...');
            return FriendService();
          },
        ),
        ChangeNotifierProvider<CoFocusService>(
          create: (_) {
            debugPrint('PROVIDER_DEBUG: Creating CoFocusService...');
            return CoFocusService();
          },
        ),
        Provider<AccountabilityService>(
          create: (_) {
            debugPrint('PROVIDER_DEBUG: Creating AccountabilityService...');
            return AccountabilityService();
          },
        ),
        ChangeNotifierProvider<AIService>(
           create: (context) {
             debugPrint('PROVIDER_DEBUG: Creating AIService...');
             final ai = AIService(Provider.of<MemoryService>(context, listen: false));
             debugPrint('PROVIDER_DEBUG: AIService CREATED OK');
             return ai;
           },
        ),
        ProxyProvider<AuthManager, CalendarService>(
          update: (_, auth, previous) {
            if (previous != null) return previous;
            debugPrint('PROVIDER_DEBUG: Creating CalendarService...');
            final c = CalendarService(auth);
            debugPrint('PROVIDER_DEBUG: CalendarService CREATED OK');
            return c;
          },
        ),
        Provider<NotificationService>(
          create: (_) {
            debugPrint('PROVIDER_DEBUG: Creating NotificationService...');
            final n = NotificationService();
            debugPrint('PROVIDER_DEBUG: NotificationService CREATED OK');
            return n;
          },
        ),
        Provider<PingService>(
          create: (context) {
            debugPrint('PROVIDER_DEBUG: Creating PingService...');
            return PingService(Provider.of<NotificationService>(context, listen: false));
          },
        ),
        ProxyProvider<UserService, TelemetryService>(
          lazy: false,
          update: (context, userService, previous) {
            final t = previous ?? TelemetryService();
            t.setUserService(userService);
            return t;
          },
        ),
        ChangeNotifierProxyProvider<CalendarService, TimetableService>(
          create: (context) {
            debugPrint('PROVIDER_DEBUG: Creating TimetableService...');
            final t = TimetableService(Provider.of<CalendarService>(context, listen: false));
            debugPrint('PROVIDER_DEBUG: TimetableService CREATED OK');
            return t;
          },
          update: (_, calendar, previous) => previous ?? TimetableService(calendar),
        ),
        ChangeNotifierProvider<TaskService>(
          create: (context) {
            debugPrint('PROVIDER_DEBUG: Creating TaskService...');
            final t = TaskService(
              accountability: Provider.of<AccountabilityService>(context, listen: false),
              coFocusService: Provider.of<CoFocusService>(context, listen: false),
              userService: Provider.of<UserService>(context, listen: false),
            );
            debugPrint('PROVIDER_DEBUG: TaskService CREATED OK');
            return t;
          },
        ),

        // 3. ViewModels (Dependent on Services)
        ChangeNotifierProxyProvider6<CalendarService, AIService, TimetableService, NotificationService, FriendService, AccountabilityService, WarRoomViewModel>(
          create: (context) {
            debugPrint('PROVIDER_DEBUG: Creating WarRoomViewModel...');
            final vm = WarRoomViewModel(
              calendarService: Provider.of<CalendarService>(context, listen: false),
              aiService: Provider.of<AIService>(context, listen: false),
              timetableService: Provider.of<TimetableService>(context, listen: false),
              notificationService: Provider.of<NotificationService>(context, listen: false),
              friendService: Provider.of<FriendService>(context, listen: false),
              accountabilityService: Provider.of<AccountabilityService>(context, listen: false),
              telemetryService: Provider.of<TelemetryService>(context, listen: false),
            );
            debugPrint('PROVIDER_DEBUG: WarRoomViewModel CREATED OK');
            return vm;
          },
          update: (context, calendar, ai, timetable, notifications, friend, acc, previous) =>
              previous ?? WarRoomViewModel(
                calendarService: calendar,
                aiService: ai,
                timetableService: timetable,
                notificationService: notifications,
                friendService: friend,
                accountabilityService: acc,
                telemetryService: Provider.of<TelemetryService>(context, listen: false),
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
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // Check initial link if app was cold-started by a link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri);
    });

    // Listen to incoming links when app is running or in background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    }, onError: (err) {
      debugPrint("Deep Link Error: $err");
    });
  }

  void _handleLink(Uri uri) {
    debugPrint("Received deep link: $uri");
    if (uri.scheme == 'vyoma' && uri.host == 'pact') {
      final pactId = uri.queryParameters['id'];
      if (pactId != null) {
        // Wait a frame for providers to be ready if cold-starting
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<CoFocusService>().handleDeepLinkInvite(pactId);
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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

    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        bool isOffline = false;
        if (snapshot.hasData) {
          final results = snapshot.data!;
          isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
        }

        if (isOffline) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F1A),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white54),
                  SizedBox(height: 24),
                  Text(
                    "CONNECTION LOST",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Vyoma requires an active internet connection\nfor AI generation and accountability sync.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return _onboardingComplete! ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }
}
