import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../core/ai_service.dart';
import '../core/calendar_service.dart';
import '../core/models/static_context.dart'; 
import '../core/device_service.dart'; 
import '../core/weather_service.dart'; 
import '../core/window_spy.dart'; 
import 'dart:typed_data';
import '../core/chronos_service.dart';
import '../core/watchtower_service.dart';
import '../core/sentinel_service.dart';
import '../core/models/user_preferences.dart';

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;

  ChatSession({required this.id, required this.title, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class ChatMessage {
  final String sender; // "USER" or "VYOMA" or "SYSTEM"
  final String text;
  final DateTime timestamp;
  final Uint8List? imageBytes;

  ChatMessage({
    required this.sender, 
    required this.text, 
    required this.timestamp,
    this.imageBytes,
  });
}

class WarRoomViewModel extends ChangeNotifier {
  final CalendarService _calendarService;
  final AIService _aiService;
  
  // Intelligence Services
  final DeviceService _deviceService = DeviceService();
  final WeatherService _weatherService = WeatherService();
  final WindowSpy _windowSpy = WindowSpy();
  
  // Watchtower & Chronos
  late final WatchtowerService _watchtowerService;
  late final ChronosService _chronosService; 
  late final SentinelService _sentinelService;
  SentinelService get sentinelService => _sentinelService;

  // Session Management
  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  
  String? _currentSessionId;
  String? get currentSessionId => _currentSessionId;

  List<ChatMessage> _messages = []; 
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isSavingMemory = false;
  bool get isSavingMemory => _isSavingMemory;

  // Metrics Logic
  ProductivityMetrics _currentMetrics = ProductivityMetrics.initial();
  ProductivityMetrics get currentMetrics => _currentMetrics;

  // Static Context
  final StaticContext _staticContext = StaticContext.initial();

  WarRoomViewModel({
    required CalendarService calendarService, 
    required AIService aiService
  }) : _calendarService = calendarService, _aiService = aiService {
    _watchtowerService = WatchtowerService(_calendarService);
    _watchtowerService.startWatch(); // ACTIVATE SURVEILLANCE
    
    _chronosService = ChronosService(_aiService.memory);
    
    // Sentinel Service - Proactive Intelligence
    _sentinelService = SentinelService(
      calendar: _calendarService,
      weather: _weatherService,
      device: _deviceService,
      windowSpy: _windowSpy,
      memory: _aiService.memory,
    );
    _sentinelService.setAIService(_aiService);
    _sentinelService.onAlert = _handleProactiveAlert;
    _sentinelService.startPatrol(); // ACTIVATE PROACTIVE MONITORING
    
    _initSessions(); // Load Index First
    _loadMetrics();
  }

  /// Handle incoming proactive alerts from Sentinel
  void _handleProactiveAlert(ProactiveAlert alert) {
    // Add alert as VYOMA message in current chat
    _addMessage("VYOMA", "🔔 ${alert.title}\n\n${alert.body}");
  }
  
  Future<Directory> _getDocsDir() async => await getApplicationDocumentsDirectory();

  Future<void> _initSessions() async {
    final dir = await _getDocsDir();
    final indexFile = File('${dir.path}/sessions_index.json');
    final legacyFile = File('${dir.path}/chat_history.json');

    if (await indexFile.exists()) {
       final jsonStr = await indexFile.readAsString();
       final ListList = jsonDecode(jsonStr) as List;
       _sessions = ListList.map((e) => ChatSession.fromJson(e)).toList();
       
       // Sort by date desc
       _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (await legacyFile.exists()) {
       // Migration
       final legacyId = DateTime.now().millisecondsSinceEpoch.toString();
       final session = ChatSession(id: legacyId, title: "Legacy Chat", createdAt: DateTime.now());
       _sessions.add(session);
       await _saveSessionIndex();
       
       // Rename file
       await legacyFile.rename('${dir.path}/session_$legacyId.json');
    }

    if (_sessions.isEmpty) {
      await startNewSession(); 
    } else {
      await loadSession(_sessions.first.id);
    }
  }

  Future<void> _saveSessionIndex() async {
    final dir = await _getDocsDir();
    final file = File('${dir.path}/sessions_index.json');
    await file.writeAsString(jsonEncode(_sessions.map((e) => e.toJson()).toList()));
  }

  Future<void> startNewSession() async {
    _messages = [];
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSessionId = id;
    
    final newSession = ChatSession(id: id, title: "New Operation", createdAt: DateTime.now());
    _sessions.insert(0, newSession);
    await _saveSessionIndex();

    // TEMPORAL CHECK
    final temporalGap = _chronosService.getTimeGap();
    final status = _chronosService.analyzeTemporalState();
    
    _addMessage("SYSTEM", "✧ VYOMA // Cosmic Guide Awakened", save: true);
    
    // Greeting based on Gap
    if (status == TemporalStatus.longAbsence) {
      _addMessage("VYOMA", "The stars have shifted in your absence — ${temporalGap.inDays} days have passed. Let us realign your path.", save: true);
    } else if (status == TemporalStatus.awol) {
       _addMessage("VYOMA", "A day has slipped by. What shadows need clearing?", save: true);
    } else {
       _addMessage("VYOMA", "I am here. What wisdom do you seek?", save: true); 
    }
    
    await _chronosService.updateHeartbeat();
    notifyListeners();
  }

  Future<void> loadSession(String id) async {
    _currentSessionId = id;
    _messages = [];
    notifyListeners();

    final dir = await _getDocsDir();
    final file = File('${dir.path}/session_$id.json');
    
    if (await file.exists()) {
      try {
        final jsonStr = await file.readAsString();
        final List list = jsonDecode(jsonStr);
        _messages = list.map((e) => ChatMessage(
          sender: e['sender'], 
          text: e['text'], 
          timestamp: DateTime.parse(e['timestamp']),
          imageBytes: e['imageBytes'] != null ? base64Decode(e['imageBytes']) : null,
        )).toList();
        
        _addMessage("SYSTEM", "--- SESSION RESTORED ---", save: false);
      } catch (e) {
        print("Corrupt Session: $e");
         _addMessage("SYSTEM", "ERROR: SESSION DATA CORRUPTED", save: false);
      }
    }
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    final dir = await _getDocsDir();
    final file = File('${dir.path}/session_$id.json');
    if (await file.exists()) await file.delete();

    _sessions.removeWhere((s) => s.id == id);
    await _saveSessionIndex();

    if (_currentSessionId == id) {
      if (_sessions.isNotEmpty) {
        await loadSession(_sessions.first.id);
      } else {
        await startNewSession();
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> _saveCurrentChat() async {
    if (_currentSessionId == null) return;
    final dir = await _getDocsDir();
    final file = File('${dir.path}/session_$_currentSessionId.json');
    
    final jsonList = _messages.where((m) => m.sender != 'SYSTEM' || !m.text.contains('---')).map((m) => {
      'sender': m.sender,
      'text': m.text,
      'timestamp': m.timestamp.toIso8601String(),
      'imageBytes': m.imageBytes != null ? base64Encode(m.imageBytes!) : null,
    }).toList();
    
    await file.writeAsString(jsonEncode(jsonList));
  }

  void _addMessage(String sender, String text, {bool save = true, Uint8List? imageBytes}) {
    final msg = ChatMessage(
      sender: sender,
      text: text,
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    );
    _messages.add(msg);
    notifyListeners();
    if (save) _saveCurrentChat();
    
    // Auto-Title Logic (if first user message and title is generic)
    if (sender == "USER" && _currentSessionId != null) {
       final session = _sessions.firstWhere((s) => s.id == _currentSessionId);
       if (session.title == "New Operation") {
         session.title = text.length > 20 ? "${text.substring(0, 20)}..." : (text.isEmpty ? "Image Upload" : text);
         _saveSessionIndex();
       }
    }
  }

  // --- ADVANCED CHAT FEATURES ---

  bool _abortRequest = false;

  void cancelRequest() {
    if (_isProcessing) {
      _abortRequest = true;
      _isProcessing = false;
      _addMessage("SYSTEM", "> SIGNAL JAMMED. REQUEST ABORTED.");
      notifyListeners();
    }
  }

  Future<void> clearSession() async {
     await startNewSession();
  }

  // --- EXECUTION ---
  Uint8List? _selectedImageBytes;
  Uint8List? get selectedImageBytes => _selectedImageBytes;

  void selectImage(Uint8List? bytes) {
    _selectedImageBytes = bytes;
    notifyListeners();
  }

  Future<void> submitCommand(String text) async {
    if (text.trim().isEmpty && _selectedImageBytes == null) return; // Allow image only

    // Display User Message
    _addMessage(
      "USER", 
      text, 
      imageBytes: _selectedImageBytes
    );
    
    _isProcessing = true;
    notifyListeners();

    try {
      _abortRequest = false; // Reset flag

      // 1. Fetch Context
      _isSyncing = true;
      notifyListeners();
      
      if (_abortRequest) return;

      final events = await _calendarService.syncEvents();
      if (_abortRequest) return;
      
      final eventStrings = events.map((e) {
        final time = e.start?.dateTime ?? e.start?.date;
        return "[${e.summary} @ $time]";
      }).toList();

      // 2. Consult General
      // Silent Uplink
      
      // Parallel Intelligence Gathering
      Map<String, dynamic> telemetry = {};
      
      try {
        final deviceData = await _deviceService.getDeviceStatus();
        telemetry.addAll(deviceData);
      } catch (e) { print("Device Telemetry Error: $e"); }

      // ... (Rest of telemetry fetching remains same)

      try {
        final weatherData = await _weatherService.getWeather();
        telemetry.addAll(weatherData); 
      } catch (e) { print("Weather Telemetry Error: $e"); }

      try {
        final windowData = await _windowSpy.spyOnUser();
        telemetry.addAll(windowData);
      } catch (e) { print("Window Spy Error: $e"); }
      
      _isSyncing = false;
      notifyListeners();

      // Pass image if exists
      // Pass image if exists
      final aiResponse = await _aiService.sendMessage(
        text, 
        eventStrings, 
        _currentMetrics, 
        _staticContext,
        telemetry, 
        imageBytes: _selectedImageBytes,
        temporalContext: _chronosService.getTemporalContext()
      );
      
      await _chronosService.updateHeartbeat(); // Pulse check

      if (_abortRequest) return; 

      _selectedImageBytes = null;

      // 3. Update Metrics (If AI commands it)
      if (aiResponse.metricDelta != null) {
        final delta = aiResponse.metricDelta!;
        if (delta.focusChange != 0 || delta.distractionChange != 0 || delta.taskChange != 0) {
           _updateMetrics(
             focusDelta: delta.focusChange,
             distractionDelta: delta.distractionChange,
             taskDelta: delta.taskChange,
           );
           String updateMessage = "> METRICS UPDATED:";
           if (delta.focusChange != 0) updateMessage += " Focus ${delta.focusChange > 0 ? '+' : ''}${delta.focusChange}m";
           if (delta.distractionChange != 0) updateMessage += " Distractions ${delta.distractionChange > 0 ? '+' : ''}${delta.distractionChange}";
           if (delta.taskChange != 0) updateMessage += " Tasks ${delta.taskChange > 0 ? '+' : ''}${delta.taskChange}";
           if (delta.note != null && delta.note!.isNotEmpty) updateMessage += " (${delta.note})";
           _addMessage("SYSTEM", updateMessage);
        }
      }

      // 4. Memory Update (Super Memory)
      if (aiResponse.memoryUpdate != null) {
        final mem = aiResponse.memoryUpdate!;
        if (mem.action == "learn") {
           _isSavingMemory = true;
           notifyListeners();
           
           // Save to local memory (short-term)
           await _aiService.memory.learnFact(mem.key, mem.value ?? "");
           
           // Save to Supermemory (long-term vector memory)
           await _aiService.supermemory.saveMemory(
             "${mem.key}: ${mem.value}",
             tags: ['fact', 'learned'],
           );
           
           Future.delayed(const Duration(seconds: 2), () {
             _isSavingMemory = false;
             notifyListeners();
           });
           
        } else if (mem.action == "forget") {
           await _aiService.memory.forgetFact(mem.key);
           // Also forget from Supermemory
           await _aiService.supermemory.forgetMemory(mem.key);
        }
      }

      // 5. Executing Orders (Batch)
      if (aiResponse.actions.isNotEmpty) {
        for (final action in aiResponse.actions) {
          if (action.type != 'none') {
             await _executeOrder(action);
          }
        }
      }

      // 6. Speak
      _addMessage("VYOMA", aiResponse.response);
      if (aiResponse.thoughtProcess != null && kDebugMode) {
        print("VYOMA THOUGHT: ${aiResponse.thoughtProcess}");
      }

    } catch (e) {
      _addMessage("SYSTEM", "> ERROR: $e");
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void _updateMetrics({int focusDelta = 0, int distractionDelta = 0, int taskDelta = 0}) {
    _currentMetrics = ProductivityMetrics(
      focusMinutes: _currentMetrics.focusMinutes + focusDelta,
      distractionCount: _currentMetrics.distractionCount + distractionDelta,
      tasksCompleted: _currentMetrics.tasksCompleted + taskDelta,
    );
    _saveMetrics();
    notifyListeners();
  }

  Future<File> _getMetricsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/productivity_stats.json');
  }

  Future<void> _saveMetrics() async {
    try {
      final file = await _getMetricsFile();
      await file.writeAsString(jsonEncode(_currentMetrics.toJson()));
    } catch (e) {
      print("Errors saving metrics: $e");
    }
  }

  Future<void> _loadMetrics() async {
    try {
      final file = await _getMetricsFile();
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString);
        _currentMetrics = ProductivityMetrics.fromJson(json);
        notifyListeners();
      }
    } catch (e) {
      print("Error loading metrics: $e");
    }
  }

  // --- DISPOSE SAFETY ---
  bool _disposed = false;
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> _executeOrder(AIResponseAction action) async {
    _addMessage("SYSTEM", "> EXECUTING ORDER: ${action.type.toUpperCase()} ${action.summary}...");
    
    // FETCH EVENTS FOR MATCHING (Needed for Delete/Move)
    final events = await _calendarService.syncEvents();
    String? targetEventId;
    
    // Fuzzy Search for Target ID based on Summary
    if (action.type == 'delete' || action.type == 'move') {
       if (action.summary != null) {
          try {
            // Find event containing summary (case insensitive)
            final target = events.firstWhere((e) => 
               (e.summary?.toLowerCase().contains(action.summary!.toLowerCase()) ?? false)
            );
            targetEventId = target.id;
            print("DEBUG: Target Locked. ID: $targetEventId");
          } catch (e) {
            _addMessage("SYSTEM", "> ERROR: Target '${action.summary}' not found on radar.");
            return;
          }
       }
    }

    if (action.type == 'create') {
      if (action.startTime == null) {
        _addMessage("SYSTEM", "> ERROR: Missing parameters for create.");
        return;
      }

      try {
        final rawTime = action.startTime!;
        DateTime startDt = DateTime.parse(rawTime);
        final endDt = startDt.add(Duration(minutes: action.durationMinutes ?? 60));

        final event = calendar.Event(
          summary: action.summary,
          start: calendar.EventDateTime(dateTime: startDt),
          end: calendar.EventDateTime(dateTime: endDt),
        );
        
        // Handle recurrence
        List<String>? recurrenceRule;
        if (action.recurrence != null && action.recurrence!.isNotEmpty) {
           String rule = action.recurrence!;
           if (!rule.startsWith("RRULE:")) {
             rule = "RRULE:$rule";
           }
           recurrenceRule = [rule];
        }

        final createdEvent = await _calendarService.addEvent(event, recurrence: recurrenceRule);
        _addMessage("SYSTEM", "> CONFIRMED. TARGET LOCKED. (ID: ${createdEvent.id})");
        
        if (createdEvent.id != null) {
           await _aiService.memory.addPendingDebrief(
             createdEvent.id!, 
             action.summary ?? "Mission", 
             endDt
           );
        }
      } catch (e, stack) {
        print("Calendar Error: $e\n$stack");
        _addMessage("SYSTEM", "> EXECUTION FAILED: $e");
      }
    } 
    else if (action.type == 'delete') {
       if (targetEventId != null) {
         await _calendarService.deleteEvent(targetEventId);
         _addMessage("SYSTEM", "> TARGET DESTROYED.");
       }
    }
    else if (action.type == 'move') {
       if (targetEventId != null && action.startTime != null) {
          // 1. Delete Old
          await _calendarService.deleteEvent(targetEventId);
          // 2. Create New (Simplest 'Move')
          DateTime startDt = DateTime.parse(action.startTime!);
          final endDt = startDt.add(Duration(minutes: action.durationMinutes ?? 60));
          
          final event = calendar.Event(
            summary: action.summary,
            start: calendar.EventDateTime(dateTime: startDt),
            end: calendar.EventDateTime(dateTime: endDt),
          );
          
          await _calendarService.addEvent(event);
          _addMessage("SYSTEM", "> TARGET RELOCATED.");
       } else {
          _addMessage("SYSTEM", "> ERROR: Move requires valid target and new time.");
       }
    }
  }
}
