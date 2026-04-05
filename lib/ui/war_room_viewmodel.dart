import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../core/ai_service.dart';
import '../core/calendar_service.dart';
import '../core/models/static_context.dart'; 
import '../core/device_service.dart'; 
import '../core/weather_service.dart'; 
import '../core/timetable_service.dart'; // Added
import '../core/models/timetable.dart';
import '../core/notification_service.dart';
import '../core/chronos_service.dart';
import '../core/memory_service.dart';


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

class _UndoEntry {
  final String label;
  final Future<void> Function() undo;

  _UndoEntry({required this.label, required this.undo});
}

class _UserIntent {
  final bool scheduling;
  final bool reminder;
  final bool timetable;
  final bool eventEdit;
  final bool schedulingConfirmation;

  const _UserIntent({
    required this.scheduling,
    required this.reminder,
    required this.timetable,
    required this.eventEdit,
    required this.schedulingConfirmation,
  });
}

class _PendingActionPlan {
  final List<AIResponseAction> actions;
  final int? requestedWeekday;
  final String sourceUserText;

  const _PendingActionPlan({
    required this.actions,
    required this.requestedWeekday,
    required this.sourceUserText,
  });
}

class WarRoomViewModel extends ChangeNotifier {
  final CalendarService _calendarService;
  final AIService _aiService;
  final TimetableService _timetableService;
  final NotificationService _notificationService;
  
  // Intelligence Services
  final DeviceService _deviceService = DeviceService();
  final WeatherService _weatherService = WeatherService();

  // Explicit, user-controlled focus session state.
  bool _focusSessionActive = false;
  String? _focusSessionIntent;
  DateTime? _focusSessionStartedAt;
  
  // Chronos
  late final ChronosService _chronosService; 

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

  final List<_UndoEntry> _undoStack = [];
  bool get canUndo => _undoStack.isNotEmpty;
  _PendingActionPlan? _pendingActionPlan;

  // Live streaming text — shown in the chat as a typing bubble
  String _streamingText = '';
  String get streamingText => _streamingText;
  bool get isStreaming => _streamingText.isNotEmpty;

  bool get isFocusSessionActive => _focusSessionActive;
  String? get focusSessionIntent => _focusSessionIntent;

  // Minimal proactive loop to keep the "companion" behavior alive.
  Timer? _focusCheckTimer;

  // Metrics Logic
  ProductivityMetrics _currentMetrics = ProductivityMetrics.initial();
  ProductivityMetrics get currentMetrics => _currentMetrics;

  // Static Context
  final StaticContext _staticContext = StaticContext.initial();

  WarRoomViewModel({
    required CalendarService calendarService, 
    required AIService aiService,
    required TimetableService timetableService,
    required NotificationService notificationService,
  }) : _calendarService = calendarService,
       _aiService = aiService,
       _timetableService = timetableService,
       _notificationService = notificationService {
    _chronosService = ChronosService(_aiService.memory);
    _notificationService.restorePending(
      onDispatch: (body) {
        _addMessage("VYOMA", body);
      },
    );
    _startFocusCheckLoop();
    _initSessions(); // Load Index First
    _loadMetrics();
  }

  void _startFocusCheckLoop() {
    _focusCheckTimer?.cancel();
    _focusCheckTimer = Timer.periodic(const Duration(hours: 2), (_) {
      if (_disposed || _isProcessing) return;

      if (_focusSessionActive) {
        final startedAt = _focusSessionStartedAt;
        final elapsed = startedAt == null
            ? ''
            : ' (${DateTime.now().difference(startedAt).inMinutes}m so far)';
        _addSystemStatus(
          "Focus check: still on '${_focusSessionIntent ?? 'current task'}'$elapsed?",
          persist: false,
        );
      } else {
        _addSystemStatus(
          "Focus check: what are you working on right now? Start with /focus start <intent>",
          persist: false,
        );
      }
    });
  }

  void _addSystemStatus(String text, {bool persist = false}) {
    _addMessage("SYSTEM", "> $text", save: persist);
  }

  void _addSystemError(String context, Object error, {bool persist = false}) {
    final raw = error.toString();
    String normalized;

    if (raw.contains('SocketException') || raw.contains('timeout')) {
      normalized = '$context unavailable right now. Check your connection and retry.';
    } else if (raw.contains('401') || raw.contains('403') || raw.contains('unauthorized')) {
      normalized = '$context authorization failed. Reconnect this service in settings.';
    } else {
      normalized = '$context failed. Please try again.';
    }

    _addSystemStatus(normalized, persist: persist);
  }
  
  Future<Directory> _getDocsDir() async => await getApplicationDocumentsDirectory();

  Future<void> _initSessions() async {
    final dir = await _getDocsDir();
    final indexFile = File('${dir.path}/sessions_index.json');
    final legacyFile = File('${dir.path}/chat_history.json');

    if (await indexFile.exists()) {
       final jsonStr = await indexFile.readAsString();
       final sessionList = jsonDecode(jsonStr) as List;
       _sessions = sessionList.map((e) => ChatSession.fromJson(e)).toList();
       
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
    
    _addMessage("SYSTEM", "VYOMA // Cognitive Companion Online", save: true);
    
    // Greeting based on Gap
     if (status == TemporalStatus.longAbsence) {
      _addMessage("VYOMA", "${temporalGap.inDays} days since we last checked in. What matters most to move today?", save: true);
     } else if (status == TemporalStatus.awol) {
       _addMessage("VYOMA", "A day has passed. What is the next concrete move?", save: true);
     } else {
       _addMessage("VYOMA", "I am here. What do you want to focus on right now?", save: true);
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
      } catch (e) {
        debugPrint("Corrupt Session: $e");
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

  Future<void> undoLastAction() async {
    if (_undoStack.isEmpty) {
      _addMessage("SYSTEM", "> NOTHING TO UNDO.");
      return;
    }

    final last = _undoStack.removeLast();
    try {
      await last.undo();
      _addMessage("SYSTEM", "> UNDONE: ${last.label}");
    } catch (e) {
      _addMessage("SYSTEM", "> UNDO FAILED: $e");
    }
    notifyListeners();
  }

  // --- VAULT / JOURNAL ---
  Future<List<String>> previewJournalInsights(String text) async {
    return _aiService.extractDeepContextInsights(text);
  }

  int _countActionableSentences(String text) {
    final lower = text.toLowerCase();
    final cues = ['will ', 'need to ', 'must ', 'tomorrow', 'next', 'plan', 'deadline'];
    int matches = 0;
    for (final cue in cues) {
      if (lower.contains(cue)) matches++;
    }
    return matches;
  }

  Future<void> submitJournalEntry({
    required String text,
    required String mood,
    required List<String> tags,
    required List<String> acceptedInsights,
  }) async {
    _isSavingMemory = true;
    notifyListeners();

    try {
      var resolvedInsights = acceptedInsights
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Zero-friction path: if user commits directly, still extract core context.
      if (resolvedInsights.isEmpty && text.trim().length >= 24) {
        resolvedInsights = await _aiService.extractDeepContextInsights(text);
      }

      for (final insight in resolvedInsights) {
        await _aiService.supermemory.saveMemory(
          "User core context: $insight",
          tags: ['journal_insight', 'psychology', 'vault'],
        );
      }

      final entry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        text: text,
        mood: mood,
        tags: tags,
        actionableCount: _countActionableSentences(text),
        acceptedInsights: resolvedInsights,
      );

      await _aiService.memory.addJournalEntry(entry);
    } finally {
      _isSavingMemory = false;
      notifyListeners();
    }
  }

  List<JournalEntry> get recentJournalEntries => _aiService.memory.getJournalEntries(limit: 30);
  int get journalStreakDays => _aiService.memory.getJournalStreakDays();

  // --- EXECUTION ---
  Uint8List? _selectedImageBytes;
  Uint8List? get selectedImageBytes => _selectedImageBytes;

  void selectImage(Uint8List? bytes) {
    _selectedImageBytes = bytes;
    notifyListeners();
  }

  Future<void> submitCommand(String text) async {
    if (_handleControlCommand(text.trim())) return;

    if (text.trim().isEmpty && _selectedImageBytes == null) return; // Allow image only

    // Display User Message
    _addMessage(
      "USER", 
      text, 
      imageBytes: _selectedImageBytes
    );

    final lowerInput = text.toLowerCase().trim();
    if (_pendingActionPlan != null) {
      if (_isApprovalPhrase(lowerInput)) {
        await _approvePendingActionPlan();
        _selectedImageBytes = null;
        return;
      }
      if (_isDenialPhrase(lowerInput)) {
        _pendingActionPlan = null;
        _addMessage("VYOMA", "Understood. I did not make any scheduling changes.");
        _selectedImageBytes = null;
        return;
      }

      _addMessage(
        "VYOMA",
        "I still have a pending action plan. Reply \"go ahead\" to execute it, or \"no\" to cancel.",
      );
      _selectedImageBytes = null;
      return;
    }

    if (_isTimetableReadRequest(text)) {
      await _respondWithTimetableForRequest(text);
      _selectedImageBytes = null;
      return;
    }

    if (_isTimetableClearRequest(text)) {
      await _handleTimetableClearRequest(text);
      _selectedImageBytes = null;
      return;
    }

    if (_isTimetableDeleteRequest(text) || _isTimetableDeleteFollowUp(text)) {
      await _handleTimetableDeleteRequest(text);
      _selectedImageBytes = null;
      return;
    }

    if (_isCalendarDeleteRequest(text)) {
      await _handleCalendarDeleteRequest(text);
      _selectedImageBytes = null;
      return;
    }

    await _captureDeferredTaskSignals(text);
    
    _isProcessing = true;
    notifyListeners();

    try {
      _abortRequest = false; // Reset flag

      // 1. Fetch Context
      _isSyncing = true;
      notifyListeners();
      
      if (_abortRequest) return;

      // Fetch calendar events — gracefully degrade if auth fails
      List<String> eventStrings = [];
      try {
        final events = await _calendarService.syncEvents();
        if (_abortRequest) return;
        eventStrings = events.map((e) {
          final time = e.start?.dateTime ?? e.start?.date;
          return "[${e.summary} @ $time]";
        }).toList();
      } catch (e) {
        debugPrint("Calendar Sync Error: $e");
        _addSystemStatus("Calendar is unavailable right now. Continuing without schedule context.");
      }

      // 2. Consult General
      // Silent Uplink
      
      // Parallel Intelligence Gathering
      Map<String, dynamic> telemetry = {};
      
      try {
        final deviceData = await _deviceService.getDeviceStatus();
        telemetry.addAll(deviceData);
      } catch (e) { debugPrint("Device Telemetry Error: $e"); }

      try {
        final weatherData = await _weatherService.getWeather();
        telemetry.addAll(weatherData); 
      } catch (e) { debugPrint("Weather Telemetry Error: $e"); }

      if (_focusSessionActive) {
        final startedAt = _focusSessionStartedAt;
        telemetry['focus_session_active'] = true;
        telemetry['focus_session_intent'] = _focusSessionIntent ?? '';
        if (startedAt != null) {
          telemetry['focus_session_minutes'] = DateTime.now().difference(startedAt).inMinutes;
        }
      }
      
      _isSyncing = false;
      notifyListeners();

      // Pass image if exists
      debugPrint("DEBUG_TRACE: Pre-Fetch Checks Passed. Calling AI Service (streaming)...");
      
      // Live streaming — each token updates the UI immediately
      _streamingText = '';
      notifyListeners();
      
      final aiResponse = await _aiService.sendMessageWithStream(
        userText: text,
        calendarEvents: eventStrings,
        metrics: _currentMetrics,
        staticContext: _staticContext,
        deviceTelemetry: telemetry,
        imageBytes: _selectedImageBytes,
        conversationTimeline: _conversationTimeline(limit: 20),
        temporalContext: null, // sendMessage accepts String? — temporal context is built inside AIService
        onToken: (token) {
          _streamingText += token;
          notifyListeners(); // triggers live ChatSheet rebuild
        },
      );
      
      // Clear streaming buffer — full message replaces it below
      _streamingText = '';
      notifyListeners();
      
      debugPrint("DEBUG_TRACE: AI Service Returned. Updating Heartbeat...");
      await _chronosService.updateHeartbeat(); // Pulse check

      debugPrint("DEBUG_TRACE: Heartbeat Updated. Checking Abort...");
      if (_abortRequest) {
        debugPrint("DEBUG_TRACE: Abort Request was true. Exiting early.");
        return; 
      }

      _selectedImageBytes = null;

      debugPrint("DEBUG_TRACE: Processing Metrics...");
      // 3. Update Metrics (If AI commands it)
      if (aiResponse.metricDelta != null) {
        final delta = aiResponse.metricDelta!;
        final blocked = _isMetricManipulationAttempt(text);
        if (blocked && (delta.focusChange != 0 || delta.distractionChange != 0 || delta.taskChange != 0)) {
           _addSystemStatus("Metric integrity: direct metric set/reset commands are ignored.", persist: false);
        } else if (delta.focusChange != 0 || delta.distractionChange != 0 || delta.taskChange != 0) {
           _updateMetrics(
             focusDelta: delta.focusChange,
             distractionDelta: delta.distractionChange,
             taskDelta: delta.taskChange,
           );
           String updateMessage = "> METRICS UPDATED:";
           if (delta.focusChange != 0) updateMessage += " Focus ${delta.focusChange > 0 ? '+' : ''}${delta.focusChange}m";
           if (delta.distractionChange != 0) updateMessage += " Distractions ${delta.distractionChange > 0 ? '+' : ''}${delta.distractionChange}";
           if (delta.taskChange != 0) updateMessage += " Tasks ${delta.taskChange > 0 ? '+' : ''}${delta.taskChange}";
           if (delta.note.isNotEmpty) updateMessage += " (${delta.note})";
           _addSystemStatus(updateMessage.replaceFirst('> ', ''), persist: false);
        }
      }

      debugPrint("DEBUG_TRACE: Processing Memories...");
      // 4. Memory Update (Super Memory)
      if (aiResponse.memoryUpdate != null) {
        final mem = aiResponse.memoryUpdate!;
        if (mem.action == "learn") {
            debugPrint("DEBUG_TRACE: Learning Memory: ${mem.key}");
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
           debugPrint("DEBUG_TRACE: Forgetting Memory: ${mem.key}");
           await _aiService.memory.forgetFact(mem.key);
           // Also forget from Supermemory
           await _aiService.supermemory.forgetMemory(mem.key);
        }
      }

      final userIntent = _inferUserIntent(text);
      final requestedWeekday = _extractRequestedWeekday(text);
      var executedActionCount = 0;

      debugPrint("DEBUG_TRACE: Processing Batch Actions...");
      String? transactionPrompt;
      // 5. Stage Orders (Batch) - fail-closed, explicit confirm required
      if (aiResponse.actions.isNotEmpty) {
        final bulkScheduleRequest = RegExp(r'\b(all|full|entire|whole|class|classes|timetable|weekly)\b')
            .hasMatch(text.toLowerCase());
        final maxActionsThisTurn = bulkScheduleRequest ? 12 : 4;
        final stagedActions = <AIResponseAction>[];
        final blockedActions = <String>[];

        for (final action in aiResponse.actions) {
          if (action.type != 'none') {
             if (!_isActionAllowed(action, userIntent)) {
               blockedActions.add(action.type);
               _addSystemStatus(
                 "Action blocked by firewall: ${action.type}. Ask explicitly for scheduling/reminder edits to enable it.",
                 persist: false,
               );
               continue;
             }

             if (!_isActionExecutable(action)) {
               _addSystemStatus(
                 "Action rejected: ${action.type} is missing required fields.",
                 persist: false,
               );
               continue;
             }

             if (stagedActions.length >= maxActionsThisTurn) {
               _addSystemStatus("Action limit reached for this turn. Ignoring extra actions.", persist: false);
               break;
             }

             stagedActions.add(action);
          }
        }

        if (stagedActions.isNotEmpty) {
          _pendingActionPlan = _PendingActionPlan(
            actions: stagedActions,
            requestedWeekday: requestedWeekday,
            sourceUserText: text,
          );
          transactionPrompt = _buildActionConfirmationPrompt(stagedActions);
        } else if (blockedActions.isNotEmpty) {
          transactionPrompt = "I prepared no executable action from that request. Rephrase with explicit date, time, and event title.";
        } else {
          transactionPrompt = "I could not build an executable scheduling action from that response, so no calendar changes were made.";
        }
      }

      debugPrint("DEBUG_TRACE: Adding AI Message to UI...");
      // 6. Show thought process as a collapsed SYSTEM message (if present)
      if (aiResponse.thoughtProcess != null && aiResponse.thoughtProcess!.isNotEmpty) {
        _addMessage("SYSTEM", "[THOUGHT] ${aiResponse.thoughtProcess}", save: false);
      }
      
      // 7. Speak (with anti-repeat stabilization)
      var verbal = transactionPrompt ?? aiResponse.response;
      if (_isHallucinatedScheduleMutationClaim(verbal, aiResponse.actions, executedActionCount)) {
        final count = _timetableService.slots.length;
        verbal = count == 0
        ? 'No timetable changes were executed in that step. Your timetable is already empty.'
        : 'No timetable changes were executed in that step. Your timetable still has $count slots.';
      }

      final stabilized = _stabilizeAssistantResponse(verbal, text);
      _addMessage("VYOMA", stabilized);
      debugPrint("DEBUG_TRACE: Message Added Successfully.");

    } catch (e, stacktrace) {
      debugPrint("\n**************************************************");
      debugPrint("DEBUG_TRACE: CRASH IN SUBMIT COMMAND");
      debugPrint("ERROR: $e");
      debugPrint("STACKTRACE: $stacktrace");
      debugPrint("**************************************************\n");
      _addSystemError("Assistant response", e);
    } finally {
      debugPrint("DEBUG_TRACE: Reached Finally Block. Setting isProcessing to false.");
      _isProcessing = false;
      notifyListeners();
    }
  }

  bool _isTimetableReadRequest(String text) {
    final lower = text.toLowerCase();
    final asksToRead = RegExp(r'\b(show|list|what|display|give|see|provide)\b').hasMatch(lower);
    final hasWeekday = RegExp(r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b').hasMatch(lower);
    final mentionsTimetable = RegExp(r'\b(timetable|time\s*table|schedule|classes|class)\b').hasMatch(lower);
    final editWords = _isTimetableEditIntent(text);
    final followUpRead = hasWeekday && _hasRecentTimetableContext();
    return !editWords && ((asksToRead && mentionsTimetable) || followUpRead);
  }

  bool _isTimetableEditIntent(String text) {
    final lower = text.toLowerCase();
    final directEdit = RegExp(
      r'\b(reschedule|shift|move|change|update|set|add|create|delete|cancel|remove|schedule\s+(this|it|them|for|at|on|from|to|me)|every\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday))\b',
    ).hasMatch(lower);

    if (directEdit) return true;

    final hasScheduleVerb = RegExp(r'\bschedule\b').hasMatch(lower);
    final hasActionObject = RegExp(r'\b(class|classes|slot|slots|event|events|this|it|them)\b').hasMatch(lower);
    return hasScheduleVerb && hasActionObject;
  }

  bool _hasRecentTimetableContext() {
    final recent = _messages.reversed.take(8);
    for (final msg in recent) {
      final lower = msg.text.toLowerCase();
      if (RegExp(r'\b(timetable|time\s*table|schedule|classes|class)\b').hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  bool _isTimetableDeleteRequest(String text) {
    final lower = text.toLowerCase();
    final deleteIntent = RegExp(r'\b(delete|remove|drop|cancel)\b').hasMatch(lower);
    final timetableContext = RegExp(r'\b(timetable|time\s*table|schedule|class|classes)\b').hasMatch(lower);
    return deleteIntent && timetableContext;
  }

  bool _isTimetableDeleteFollowUp(String text) {
    final lower = text.toLowerCase();
    final confirmDelete = RegExp(r'\b(cancel it|delete it|remove it|do it|yes|go ahead)\b').hasMatch(lower);
    if (!confirmDelete) return false;

    final recent = _messages.reversed.take(10);
    for (final msg in recent) {
      if (msg.sender != 'VYOMA') continue;
      final m = msg.text.toLowerCase();
      if (m.contains('which day to update') ||
          m.contains('upcoming scheduled events') ||
          m.contains('your current timetable')) {
        return true;
      }
    }
    return false;
  }

  bool _isCalendarDeleteRequest(String text) {
    final lower = text.toLowerCase();
    final deleteIntent = RegExp(r'\b(cancel|delete|remove|drop)\b').hasMatch(lower);
    if (!deleteIntent) return false;

    // Let timetable clear logic own explicit bulk deletes.
    if (RegExp(r'\b(all|everything|entire|whole)\b').hasMatch(lower)) {
      return false;
    }

    final hasCalendarObject = RegExp(r'\b(event|events|meeting|reminder|class|classes|lab|session|it|this|that|them)\b').hasMatch(lower);
    final hasSubjectTail = _extractDeletionSubjectHint(text) != null;
    return hasCalendarObject || hasSubjectTail;
  }

  Future<void> _handleCalendarDeleteRequest(String text) async {
    try {
      final deleted = await _tryDeleteCalendarEventFromText(text);
      if (deleted) return;
      _addMessage(
        "VYOMA",
        "I could not find a matching upcoming event to cancel. Tell me the event name, or ask me to list your schedule first.",
      );
    } catch (_) {
      _addMessage(
        "VYOMA",
        "I could not access calendar events right now. Please try again in a moment.",
      );
    }
  }

  String _normalizeSearchText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extractDeletionSubjectHint(String text) {
    var hint = _normalizeSearchText(text);
    hint = hint.replaceAll(
      RegExp(r'\b(cancel|delete|remove|drop|it|this|that|them|from|my|the|event|events|class|classes|schedule|timetable|please)\b'),
      ' ',
    );
    hint = hint.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (hint.isEmpty) return null;
    return hint;
  }

  Future<bool> _tryDeleteCalendarEventFromText(String text) async {
    final normalized = _normalizeSearchText(text);
    final pronounOnly = RegExp(r'^(cancel|delete|remove|drop)(\s+(it|this|that|them))?$').hasMatch(normalized);

    final events = await _calendarService.syncEvents(maxResults: 50);
    if (events.isEmpty) return false;

    calendar.Event? target;
    if (pronounOnly) {
      target = events.first;
    } else {
      final hint = _extractDeletionSubjectHint(text);
      if (hint == null) return false;
      final hintTokens = hint.split(' ').where((t) => t.length >= 3).toList();
      if (hintTokens.isEmpty) return false;

      int scoreEvent(calendar.Event e) {
        final summary = _normalizeSearchText(e.summary ?? '');
        if (summary.isEmpty) return 0;

        var score = 0;
        if (summary.contains(hint)) score += 5;
        for (final token in hintTokens) {
          if (summary.contains(token)) score += 1;
        }
        return score;
      }

      final scored = events
          .map((e) => MapEntry(e, scoreEvent(e)))
          .where((entry) => entry.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (scored.isEmpty) return false;
      target = scored.first.key;
    }

    final eventId = target.id;
    if (eventId == null || eventId.isEmpty) return false;

    await _calendarService.deleteEvent(eventId);

    final summary = (target.summary == null || target.summary!.trim().isEmpty)
        ? 'Event'
        : target.summary!.trim();
    final start = target.start?.dateTime?.toLocal();
    if (start != null) {
      final date = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      _addMessage("VYOMA", "$summary on $date at ${_to12hFromDateTime(start)} has been cancelled.");
    } else {
      _addMessage("VYOMA", "$summary has been cancelled.");
    }
    return true;
  }

  bool _isTimetableClearRequest(String text) {
    final lower = text.toLowerCase();
    final clearWords = RegExp(r'\b(clear|wipe|reset|empty|cancel all|delete all|remove all)\b').hasMatch(lower);
    final timetableContext = RegExp(r'\b(timetable|time\s*table|schedule|classes|class)\b').hasMatch(lower);
    return clearWords && timetableContext;
  }

  Future<void> _handleTimetableClearRequest(String text) async {
    final existing = _timetableService.slots;
    if (existing.isEmpty) {
      _addMessage("VYOMA", "Your timetable is already empty.");
      return;
    }

    await _timetableService.updateTimetable([]);
    _addMessage("VYOMA", "Done. Cleared your timetable and synced the change.");
  }

  bool _isHallucinatedScheduleMutationClaim(
    String verbal,
    List<AIResponseAction> actions,
    int executedActionCount,
  ) {
    if (executedActionCount > 0) return false;

    final lower = verbal.toLowerCase();
    final claimsMutation = RegExp(r'\b(cleared|cancelled|canceled|deleted|removed|rescheduled|updated|shifted|moved)\b').hasMatch(lower);
    final scheduleContext = RegExp(r'\b(timetable|schedule|class|classes|event|calendar)\b').hasMatch(lower);

    final hasExecutableAction = actions.any((a) => a.type != 'none');
    if (hasExecutableAction) return false;

    return claimsMutation && scheduleContext;
  }

  Future<void> _handleTimetableDeleteRequest(String text) async {
    final requestedWeekday = _extractRequestedWeekday(text);
    if (requestedWeekday == null) {
      try {
        final deletedFromCalendar = await _tryDeleteCalendarEventFromText(text);
        if (deletedFromCalendar) return;
      } catch (_) {}

      _addMessage(
        "VYOMA",
        "Tell me which day to update, for example Monday or Thursday.",
      );
      return;
    }

    final dayName = _weekdayName(requestedWeekday);
    final lower = text.toLowerCase();

    final courseCode = RegExp(r'\b([a-z]{2,5}\s*\d{3})\b', caseSensitive: false)
        .firstMatch(text)
        ?.group(1)
        ?.toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');

    final removePlacements = RegExp(r'\bplacement|placements\b').hasMatch(lower);
    final deleteAllForDay = !removePlacements && courseCode == null;

    final existing = _timetableService.slots;
    final daySlots = existing.where((s) => s.dayOfWeek.toLowerCase() == dayName.toLowerCase()).toList();

    bool shouldDelete(TimetableSlot slot) {
      final subjectLower = slot.subject.toLowerCase();
      if (deleteAllForDay) return true;
      if (removePlacements && subjectLower.contains('placement')) return true;
      if (courseCode != null) {
        final slotNorm = subjectLower.replaceAll(RegExp(r'\s+'), ' ');
        if (slotNorm.contains(courseCode)) return true;
      }
      return false;
    }

    final toDelete = daySlots.where(shouldDelete).toList();
    if (toDelete.isEmpty) {
      _addMessage("VYOMA", "I could not find matching classes to delete in your $dayName timetable.");
      return;
    }

    final updated = existing.where((s) => !toDelete.contains(s)).toList();
    await _timetableService.updateTimetable(updated);

    final removedNames = toDelete.map((s) => s.subject).toSet().join(', ');
    _addMessage(
      "VYOMA",
      "Done. Removed ${toDelete.length} class${toDelete.length > 1 ? 'es' : ''} from your $dayName timetable: $removedNames.",
    );
  }

  String _weekdayName(int weekday) {
    const names = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return names[weekday] ?? 'Unknown';
  }

  String? _canonicalWeekdayName(String raw) {
    final lower = raw.toLowerCase();
    if (RegExp(r'\bmonday\b').hasMatch(lower)) return 'Monday';
    if (RegExp(r'\btuesday\b').hasMatch(lower)) return 'Tuesday';
    if (RegExp(r'\bwednesday\b').hasMatch(lower)) return 'Wednesday';
    if (RegExp(r'\bthursday\b').hasMatch(lower)) return 'Thursday';
    if (RegExp(r'\bfriday\b').hasMatch(lower)) return 'Friday';
    if (RegExp(r'\bsaturday\b').hasMatch(lower)) return 'Saturday';
    if (RegExp(r'\bsunday\b').hasMatch(lower)) return 'Sunday';
    return null;
  }

  DateTime _nextDateForWeekday(int weekday) {
    final now = DateTime.now();
    final delta = (weekday - now.weekday + 7) % 7;
    return DateTime(now.year, now.month, now.day).add(Duration(days: delta));
  }

  String _to12h(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;

    final ampm = h >= 12 ? 'PM' : 'AM';
    var hr = h % 12;
    if (hr == 0) hr = 12;
    return '${hr.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
  }

  String _to12hFromDateTime(DateTime dt) {
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    var hr = dt.hour % 12;
    if (hr == 0) hr = 12;
    return '${hr.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  String _formatCalendarEventLine(calendar.Event e) {
    final start = e.start?.dateTime?.toLocal();
    final end = e.end?.dateTime?.toLocal();
    final summary = (e.summary == null || e.summary!.trim().isEmpty) ? 'Untitled Event' : e.summary!.trim();
    final venue = (e.location == null || e.location!.trim().isEmpty) ? '' : ' (${e.location!.trim()})';

    if (start == null || end == null) {
      return summary + venue;
    }

    return '${_to12hFromDateTime(start)} - ${_to12hFromDateTime(end)} -> $summary$venue';
  }

  Future<void> _respondWithTimetableForRequest(String text) async {
    final requestedWeekday = _extractRequestedWeekday(text);
    final allSlots = _timetableService.slots.toList()
      ..sort((a, b) {
        const dayOrder = {
          'monday': 1,
          'tuesday': 2,
          'wednesday': 3,
          'thursday': 4,
          'friday': 5,
          'saturday': 6,
          'sunday': 7,
        };
        final da = dayOrder[(_canonicalWeekdayName(a.dayOfWeek) ?? '').toLowerCase()] ?? 99;
        final db = dayOrder[(_canonicalWeekdayName(b.dayOfWeek) ?? '').toLowerCase()] ?? 99;
        final dcmp = da.compareTo(db);
        if (dcmp != 0) return dcmp;
        return a.startTime.compareTo(b.startTime);
      });

    if (requestedWeekday == null) {
      if (allSlots.isEmpty) {
        try {
          final upcoming = await _calendarService.syncEvents(maxResults: 20);
          if (upcoming.isNotEmpty) {
            final lines = upcoming
                .map(_formatCalendarEventLine)
                .where((line) => line.trim().isNotEmpty)
                .join('\n');

            _addMessage(
              "VYOMA",
              'I could not find weekly timetable slots, but here are your upcoming scheduled events:\n$lines',
            );
            return;
          }
        } catch (_) {}

        _addMessage("VYOMA", "Your current timetable is empty.");
        return;
      }

      final byDay = <String, List<TimetableSlot>>{};
      for (final slot in allSlots) {
        final canonicalDay = _canonicalWeekdayName(slot.dayOfWeek);
        if (canonicalDay == null) continue;
        byDay.putIfAbsent(canonicalDay, () => []).add(slot);
      }

      const orderedDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final sections = <String>[];
      for (final day in orderedDays) {
        final slots = byDay[day];
        if (slots == null || slots.isEmpty) continue;
        final lines = slots
            .map((s) => '${_to12h(s.startTime)} - ${_to12h(s.endTime)} -> ${s.subject}${s.venue.isNotEmpty ? ' (${s.venue})' : ''}')
            .join('\n');
        sections.add('$day:\n$lines');
      }

      _addMessage("VYOMA", 'Your current timetable:\n\n${sections.join('\n\n')}');
      return;
    }

    final dayName = _weekdayName(requestedWeekday);
    final nextDate = _nextDateForWeekday(requestedWeekday);
    final slots = _timetableService.slots
        .where((s) => (_canonicalWeekdayName(s.dayOfWeek) ?? '').toLowerCase() == dayName.toLowerCase())
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (slots.isEmpty) {
      try {
        final dayStart = DateTime(nextDate.year, nextDate.month, nextDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final dayEvents = await _calendarService.syncEventsInRange(
          timeMin: dayStart,
          timeMax: dayEnd,
          maxResults: 50,
        );

        if (dayEvents.isNotEmpty) {
          final lines = dayEvents
              .map(_formatCalendarEventLine)
              .where((line) => line.trim().isNotEmpty)
              .join('\n');

          _addMessage(
            "VYOMA",
            'Your $dayName scheduled events (${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}):\n$lines',
          );
          return;
        }
      } catch (_) {}

      _addMessage("VYOMA", "No timetable slots found for $dayName.");
      return;
    }

    final lines = slots
        .map((s) => '${_to12h(s.startTime)} - ${_to12h(s.endTime)} -> ${s.subject}${s.venue.isNotEmpty ? ' (${s.venue})' : ''}')
        .join('\n');

    _addMessage(
      "VYOMA",
      'Your $dayName timetable (${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}):\n$lines',
    );
  }

  String _normalizeForRepeat(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isRepetitiveAssistantReply(String candidate) {
    final norm = _normalizeForRepeat(candidate);
    if (norm.isEmpty) return false;

    final recentVyoma = _messages
        .where((m) => m.sender == 'VYOMA')
        .toList();

    final start = recentVyoma.length > 3 ? recentVyoma.length - 3 : 0;
    for (int i = start; i < recentVyoma.length; i++) {
      final prior = _normalizeForRepeat(recentVyoma[i].text);
      if (prior.isEmpty) continue;
      if (prior == norm) return true;

      // Near-duplicate guard: one contains the other and lengths are close.
      final contains = prior.contains(norm) || norm.contains(prior);
      final lenDiff = (prior.length - norm.length).abs();
      if (contains && lenDiff < 24) return true;
    }
    return false;
  }

  String _fallbackProgressPrompt(String userText) {
    final lower = userText.toLowerCase();
    if (lower.contains('array') || lower.contains('dsa')) {
      return 'Good. Pick one and we start now: 1) 20-minute arrays basics refresh 2) solve 2 array questions 3) quick revision plan for today.';
    }

    final short = userText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 3;
    if (short) {
      return 'Understood. Pick one concrete next move so we can proceed now: define the task, set a 20-minute block, or start the first step.';
    }

    return 'Noted. Let\'s convert this into action: what is one concrete step you can complete in the next 20 minutes?';
  }

  String _stabilizeAssistantResponse(String candidate, String userText) {
    if (_isRepetitiveAssistantReply(candidate)) {
      return _fallbackProgressPrompt(userText);
    }
    return candidate;
  }

  bool _isMetricManipulationAttempt(String text) {
    final lower = text.toLowerCase();
    final hasMetricWord =
        lower.contains('focus') ||
        lower.contains('distraction') ||
        lower.contains('task') ||
        lower.contains('score') ||
        lower.contains('metrics');

    final hasManipulationVerb =
        lower.contains('set ') ||
        lower.contains('reset') ||
        lower.contains('increase') ||
        lower.contains('decrease') ||
        lower.contains('make it') ||
        lower.contains('change ');

    return hasMetricWord && hasManipulationVerb;
  }

  _UserIntent _inferUserIntent(String text) {
    final lower = text.toLowerCase();
    final schedulingConfirmation = _isSchedulingConfirmation(lower);
    final hasImage = _selectedImageBytes != null;

    final scheduling =
        RegExp(r'\b(schedul|plan|block|book|add|create|calendar|slot|class|classes|timetable|lecture|extract|set)').hasMatch(lower) ||
        schedulingConfirmation;
    final reminder = RegExp(r'\b(remind|reminder|notify|nudge)\b').hasMatch(lower);
    final timetable = RegExp(r'\b(timetable|class list|weekly schedule|classes|class|lecture|college|extract|blocks)\b').hasMatch(lower) || hasImage;
    final eventEdit = RegExp(r'\b(move|reschedule|delete|cancel event|change event|shift|edit)\b').hasMatch(lower);

    return _UserIntent(
      scheduling: scheduling,
      reminder: reminder,
      timetable: timetable,
      eventEdit: eventEdit,
      schedulingConfirmation: schedulingConfirmation,
    );
  }

  bool _isSchedulingConfirmation(String lowerText) {
    final confirmation = RegExp(
      r'\b(do it|go ahead|yes|yep|yeah|schedule them|add them|do that|make it happen|please do)\b',
    ).hasMatch(lowerText);
    if (!confirmation) return false;

    final recent = _messages.reversed.take(6);
    for (final m in recent) {
      if (m.sender != 'VYOMA') continue;
      final t = m.text.toLowerCase();
      if (RegExp(r'\b(schedule|scheduled|calendar|event|class|classes|timetable|reminder)\b').hasMatch(t)) {
        return true;
      }
    }
    return false;
  }

  bool _isActionAllowed(AIResponseAction action, _UserIntent intent) {
    switch (action.type) {
      case 'create':
        return intent.scheduling || intent.schedulingConfirmation;
      case 'notify':
        return intent.reminder || intent.scheduling;
      case 'update_timetable':
        return intent.timetable || intent.scheduling;
      case 'move':
      case 'delete':
        return intent.eventEdit || intent.scheduling;
      case 'none':
        return true;
      default:
        return false;
    }
  }

  bool _isActionExecutable(AIResponseAction action) {
    switch (action.type) {
      case 'create':
        return action.startTime?.trim().isNotEmpty ?? false;
      case 'move':
        return (action.summary?.trim().isNotEmpty ?? false) && (action.startTime?.trim().isNotEmpty ?? false);
      case 'delete':
        return true; // Empty summary can imply 'delete all'
      case 'update_timetable':
        final hasSlots = action.slots != null && action.slots!.isNotEmpty;
        final hasTargetedEdit = (action.summary?.trim().isNotEmpty ?? false) && (action.startTime?.trim().isNotEmpty ?? false);
        return hasSlots || hasTargetedEdit;
      case 'notify':
        return (action.message?.trim().isNotEmpty ?? false) || (action.summary?.trim().isNotEmpty ?? false);
      default:
        return false;
    }
  }

  bool _isApprovalPhrase(String lowerText) {
    
    return RegExp(
      r"\b(do it|go ahead|yes|yep|yeah|approve|confirm|proceed|ok|okay|exactly|precisely|correct|that's right|affirmative|sounds good|sure)\b",
    ).hasMatch(lowerText);
  }

  bool _isDenialPhrase(String lowerText) {
    return RegExp(r"\b(no|nope|deny|cancel|stop|don't|do not)\b").hasMatch(lowerText);
  }

  String _summarizeActionForConfirmation(AIResponseAction action) {
    final title = (action.summary ?? 'untitled').trim();
    final time = action.startTime?.trim();
    switch (action.type) {
      case 'create':
        return 'Create "$title"${time != null && time.isNotEmpty ? ' at $time' : ''}';
      case 'move':
        return 'Move "$title"${time != null && time.isNotEmpty ? ' to $time' : ''}';
      case 'delete':
        return 'Delete "$title"';
      case 'update_timetable':
        if (action.slots != null && action.slots!.isNotEmpty) {
          return 'Update weekly timetable (${action.slots!.length} slots)';
        }
        return 'Update "$title"${time != null && time.isNotEmpty ? ' to $time' : ''}';
      case 'notify':
        return 'Send reminder "${(action.message ?? action.summary ?? 'message').trim()}"';
      default:
        return 'Action ${action.type}';
    }
  }

  String _buildActionConfirmationPrompt(List<AIResponseAction> actions) {
    final lines = actions
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${_summarizeActionForConfirmation(e.value)}')
        .join('\n');
    return 'I drafted the following actions:\n$lines\n\nReply "go ahead" to execute, or "no" to cancel.';
  }

  Future<void> _approvePendingActionPlan() async {
    final plan = _pendingActionPlan;
    if (plan == null) {
      _addSystemStatus('No pending action plan to approve.', persist: false);
      return;
    }

    _pendingActionPlan = null;
    var executed = 0;
    for (final action in plan.actions) {
      await _executeOrder(
        action,
        requestedWeekday: plan.requestedWeekday,
        sourceUserText: plan.sourceUserText,
      );
      executed++;
    }

    _addMessage(
      'VYOMA',
      executed == 0
          ? 'No actions were executed.'
          : 'Executed $executed action${executed > 1 ? 's' : ''} successfully.',
    );
  }

  bool _isPmCorrectionRequest(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    final hasPm = lower.contains('pm');
    final hasShiftVerb = RegExp(r'\b(shift|move|set|change|fix|convert)\b').hasMatch(lower);
    return hasPm && hasShiftVerb;
  }

  String? _inferCreateSummaryFromText(String? sourceText) {
    if (sourceText == null || sourceText.trim().isEmpty) return null;

    final m = RegExp(
      r'\b(?:schedule|add|create|book)\s+(?:my\s+)?(.+?)(?:\s+(?:in|at|on|for)\b|$)',
      caseSensitive: false,
    ).firstMatch(sourceText.trim());

    final candidate = (m?.group(1) ?? '').trim();
    if (candidate.isEmpty) return null;
    return candidate;
  }

  Future<void> _captureDeferredTaskSignals(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    final lower = text.toLowerCase();

    final promiseTomorrow =
        lower.contains('tomorrow') &&
        RegExp(r"\b(i('| wi)?ll|i am going to|gonna)\b").hasMatch(lower) &&
        RegExp(r"\b(start|begin|do|work on|study|write|build|finish|complete)\b").hasMatch(lower);

    if (promiseTomorrow) {
      await _aiService.memory.addDeferredTask(
        description: text,
        promisedFor: 'tomorrow',
      );
      _addSystemStatus('Noted. I will remember this is deferred to tomorrow.', persist: false);
      return;
    }

    final startedNow = RegExp(
      r"\b(starting|started|beginning|began|working on|doing it now|i'm on it|i am on it)\b",
    ).hasMatch(lower);

    if (startedNow) {
      final updated = await _aiService.memory.markLatestDeferredTaskStarted();
      if (updated != null) {
        _addSystemStatus('Marked deferred task as started.', persist: false);
      }
      return;
    }

    final completedNow = RegExp(
      r"\b(done|finished|completed|shipped|wrapped up|i did it|i've done it|i have done it)\b",
    ).hasMatch(lower);

    if (completedNow) {
      final updated = await _aiService.memory.markLatestDeferredTaskCompleted();
      if (updated != null) {
        _addSystemStatus('Marked deferred task as completed.', persist: false);
      }
    }
  }

  // Available slash commands for UI autocomplete: {command: [description, paramHint]}
  static const Map<String, List<String>> commandHelp = {
    '/focus start': ['Start a distraction-free focus session', '<intent>'],
    '/focus stop': ['End the current focus session', ''],
    '/focus status': ['Check current focus session runtime', ''],
    '/approve': ['Approve pending AI action plan', ''],
    '/deny': ['Deny pending AI action plan', ''],
    '/debug reset': ['[DEBUG] Wipe all data and restart from onboarding', ''],
  };

  int get todaysFocusMinutes => _currentMetrics.focusMinutes;

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
      debugPrint("Errors saving metrics: $e");
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
      debugPrint("Error loading metrics: $e");
    }
  }

  // --- DISPOSE SAFETY ---
  bool _disposed = false;
  
  @override
  void dispose() {
    _disposed = true;
    _focusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Parses a time string from the AI — handles both full ISO datetimes and bare
  /// HH:mm or HH:mm:ss strings (auto-prefixes today's date for bare times).
  DateTime _parseEventDateTime(String rawTime) {
    // Try full ISO first (e.g. "2026-03-16T08:00:00")
    try { return DateTime.parse(rawTime); } catch (_) {}

    // Bare time string — prefix today's date
    final now = DateTime.now();
    final iso = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}T$rawTime';
    try { return DateTime.parse(iso); } catch (_) {}

    // Last resort: just use now
    debugPrint("WARN: Could not parse time '$rawTime', defaulting to now.");
    return now;
  }

  DateTime _applyClockToDate(String rawTime, DateTime baseDateTime) {
    final parsed = rawTime.trim();

    final hm = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(parsed);
    if (hm != null) {
      final h = int.tryParse(hm.group(1) ?? '0') ?? 0;
      final m = int.tryParse(hm.group(2) ?? '0') ?? 0;
      final s = int.tryParse(hm.group(3) ?? '0') ?? 0;
      return DateTime(baseDateTime.year, baseDateTime.month, baseDateTime.day, h, m, s);
    }

    final ampm = RegExp(r'^(\d{1,2})[:.](\d{2})\s*(am|pm)$', caseSensitive: false).firstMatch(parsed);
    if (ampm != null) {
      final converted = _fromAmPmClock(parsed, baseDateTime);
      return DateTime(baseDateTime.year, baseDateTime.month, baseDateTime.day, converted.hour, converted.minute, converted.second);
    }

    final full = _parseEventDateTime(rawTime);
    return DateTime(baseDateTime.year, baseDateTime.month, baseDateTime.day, full.hour, full.minute, full.second);
  }

  int? _extractRequestedWeekday(String text) {
    int? scan(String source) {
      final lower = source.toLowerCase();
      if (RegExp(r'\bmonday\b').hasMatch(lower)) return DateTime.monday;
      if (RegExp(r'\btuesday\b').hasMatch(lower)) return DateTime.tuesday;
      if (RegExp(r'\bwednesday\b').hasMatch(lower)) return DateTime.wednesday;
      if (RegExp(r'\bthursday\b').hasMatch(lower)) return DateTime.thursday;
      if (RegExp(r'\bfriday\b').hasMatch(lower)) return DateTime.friday;
      if (RegExp(r'\bsaturday\b').hasMatch(lower)) return DateTime.saturday;
      if (RegExp(r'\bsunday\b').hasMatch(lower)) return DateTime.sunday;
      return null;
    }

    final current = scan(text);
    if (current != null) return current;

    // If current turn is a follow-up like "schedule them", inherit weekday from recent user turns.
    final recentUser = _messages.reversed.where((m) => m.sender == 'USER').take(8);
    for (final msg in recentUser) {
      final found = scan(msg.text);
      if (found != null) return found;
    }
    return null;
  }

  DateTime _nextOccurrenceForWeekday(int weekday, DateTime timeSource) {
    final now = DateTime.now();
    final deltaDays = (weekday - now.weekday + 7) % 7;
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      timeSource.hour,
      timeSource.minute,
      timeSource.second,
    ).add(Duration(days: deltaDays));

    if (deltaDays == 0 && candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  DateTime _alignToRequestedWeekday(DateTime parsed, int? requestedWeekday) {
    if (requestedWeekday == null) return parsed;

    final now = DateTime.now();
    if (parsed.weekday == requestedWeekday && parsed.isAfter(now.subtract(const Duration(minutes: 1)))) {
      return parsed;
    }

    final corrected = _nextOccurrenceForWeekday(requestedWeekday, parsed);
    debugPrint('WEEKDAY_GUARD: corrected ${parsed.toIso8601String()} -> ${corrected.toIso8601String()}');
    return corrected;
  }

  DateTime _fromAmPmClock(String hhmmAmPm, DateTime anchorDate) {
    final m = RegExp(r'^(\d{1,2})[:.](\d{2})\s*(am|pm)$', caseSensitive: false)
        .firstMatch(hhmmAmPm.trim());
    if (m == null) return anchorDate;

    var hour = int.tryParse(m.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ampm = (m.group(3) ?? '').toLowerCase();

    if (ampm == 'pm' && hour != 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;

    return DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
      hour,
      minute,
      0,
    );
  }

  String _normalizeLoose(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extractCourseCode(String text) {
    final m = RegExp(r'\b([A-Za-z]{2,5}\s*\d{3})\b').firstMatch(text);
    if (m == null) return null;
    return m.group(1)?.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  ({DateTime start, DateTime end})? _extractRangeFromScheduleText(
    String text,
    String subject,
    DateTime anchorDate,
  ) {
    final subjectNorm = _normalizeLoose(subject);
    final subjectCode = _extractCourseCode(subject);

    final pattern = RegExp(
      r'(\d{1,2}[:.]\d{2}\s*(?:AM|PM|am|pm))\s*(?:-|–|—|to)\s*(\d{1,2}[:.]\d{2}\s*(?:AM|PM|am|pm))\s*(?:→|->|>)\s*([^\n]+?)(?=(?:\d{1,2}[:.]\d{2}\s*(?:AM|PM|am|pm)\s*(?:-|–|—|to))|$)',
      dotAll: true,
    );

    for (final m in pattern.allMatches(text.replaceAll('\n', ' '))) {
      final segStart = m.group(1) ?? '';
      final segEnd = m.group(2) ?? '';
      final segSubject = (m.group(3) ?? '').trim();
      if (segSubject.isEmpty) continue;

      final segNorm = _normalizeLoose(segSubject);
      final segCode = _extractCourseCode(segSubject);

      final codeMatch = subjectCode != null && segCode != null && subjectCode == segCode;
      final textMatch = segNorm.contains(subjectNorm) || subjectNorm.contains(segNorm);
      if (!codeMatch && !textMatch) continue;

      final start = _fromAmPmClock(segStart, anchorDate);
      final end = _fromAmPmClock(segEnd, anchorDate);
      if (!end.isAfter(start)) {
        return (start: start, end: start.add(const Duration(minutes: 60)));
      }
      return (start: start, end: end);
    }
    return null;
  }

  ({DateTime start, DateTime end})? _extractTimeRangeForSubject(
    String userText,
    String subject,
    DateTime anchorDate,
  ) {
    final direct = _extractRangeFromScheduleText(userText, subject, anchorDate);
    if (direct != null) return direct;

    // Fallback: scan recent user turns so follow-up messages still keep AM/PM fidelity.
    final recentUser = _messages.reversed.where((m) => m.sender == 'USER').take(20);
    for (final msg in recentUser) {
      final parsed = _extractRangeFromScheduleText(msg.text, subject, anchorDate);
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool _shouldDefaultWeeklyRecurrence(String userText, int? requestedWeekday) {
    if (requestedWeekday == null) return false;
    final lower = userText.toLowerCase();
    final scheduleWord = RegExp(r'\b(schedule|timetable|routine|classes|class|college schedule)\b').hasMatch(lower);
    final dayWord = RegExp(r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b').hasMatch(lower);
    return scheduleWord && dayWord;
  }

  bool _handleControlCommand(String text) {
    final cmd = text.toLowerCase();
    if (cmd.startsWith('/focus start')) {
      final intent = text.substring('/focus start'.length).trim();
      if (intent.isEmpty) {
        _addSystemStatus("Usage: /focus start <intent>", persist: false);
        return true;
      }

      _focusSessionActive = true;
      _focusSessionIntent = intent;
      _focusSessionStartedAt = DateTime.now();
      _addSystemStatus("Focus session started: $intent", persist: false);
      notifyListeners();
      return true;
    }

    if (cmd == '/focus stop') {
      if (!_focusSessionActive) {
        _addSystemStatus("No active focus session to stop.", persist: false);
        return true;
      }

      final startedAt = _focusSessionStartedAt;
      final mins = startedAt == null ? 0 : DateTime.now().difference(startedAt).inMinutes;
      _focusSessionActive = false;
      _focusSessionIntent = null;
      _focusSessionStartedAt = null;
      _addSystemStatus("Focus session ended. Duration: ${mins}m", persist: false);
      notifyListeners();
      return true;
    }

    if (cmd == '/focus status') {
      if (!_focusSessionActive) {
        _addSystemStatus("No active focus session.", persist: false);
      } else {
        final startedAt = _focusSessionStartedAt;
        final mins = startedAt == null ? 0 : DateTime.now().difference(startedAt).inMinutes;
        _addSystemStatus("Active focus: '${_focusSessionIntent ?? 'current task'}' (${mins}m)", persist: false);
      }
      return true;
    }

    if (cmd == '/debug reset') {
      if (!kDebugMode) {
        _addSystemStatus("Debug commands are disabled in release mode.", persist: false);
        return true;
      }
      _performFactoryReset();
      return true;
    }

    if (cmd != '/approve' && cmd != '/deny') return false;

    _addMessage("USER", text);

    if (_pendingActionPlan != null) {
      if (cmd == '/deny') {
        _pendingActionPlan = null;
        _addSystemStatus("Pending action plan denied.", persist: false);
        return true;
      }

      unawaited(_approvePendingActionPlan());
      return true;
    }

    _addSystemStatus("No pending action plan.", persist: false);
    return true;
  }

  List<Map<String, dynamic>> _conversationTimeline({int limit = 20}) {
    final recent = _messages.length <= limit
        ? _messages
        : _messages.sublist(_messages.length - limit);

    return recent
        .where((m) => m.sender != 'SYSTEM')
        .map((m) => {
              'sender': m.sender,
              'text': m.text,
              'timestamp': m.timestamp.toIso8601String(),
            })
        .toList();
  }

  Future<void> _executeOrder(
    AIResponseAction action, {
    int? requestedWeekday,
    String? sourceUserText,
  }) async {
    _addSystemStatus("Executing ${action.type.toUpperCase()} ${action.summary ?? ''}".trim(), persist: false);
    
    // FETCH EVENTS FOR MATCHING (Needed for Delete/Move)
    List<dynamic> events = [];
    try { events = await _calendarService.syncEvents(); } catch (e) {
      _addSystemError("Calendar", e);
      return;
    }
    String? targetEventId;
    calendar.Event? targetEvent;
    
     // Fuzzy Search for Target ID based on Summary
     final isBulkDelete = action.type == 'delete' && 
         (action.summary == null || 
          action.summary!.toLowerCase().contains('all') || 
          action.summary!.toLowerCase().contains('timetable') || 
          action.summary!.toLowerCase().contains('schedule'));

     if (!isBulkDelete && (action.type == 'delete' || action.type == 'move' || (action.type == 'update_timetable' && action.summary != null && action.startTime != null))) {
       if (action.summary != null) {
          try {
            final target = events.firstWhere((e) => 
               (e.summary?.toLowerCase().contains(action.summary!.toLowerCase()) ?? false)
            );
            targetEventId = target.id;
            targetEvent = target;
            debugPrint("DEBUG: Target Locked. ID: $targetEventId");
          } catch (e) {
            _addSystemStatus("Could not find an event matching '${action.summary}'.", persist: false);
            return;
          }
       }
    }

    if (action.type == 'create') {
      if (action.startTime == null) {
        _addSystemStatus("Cannot create event: missing start time.", persist: false);
        return;
      }

      try {
        final parsedStart = _parseEventDateTime(action.startTime!);
        var startDt = _alignToRequestedWeekday(parsedStart, requestedWeekday);
        var endDt = startDt.add(Duration(minutes: action.durationMinutes ?? 60));

        if (sourceUserText != null && action.summary != null && action.summary!.trim().isNotEmpty) {
          final extracted = _extractTimeRangeForSubject(sourceUserText, action.summary!, startDt);
          if (extracted != null) {
            startDt = _alignToRequestedWeekday(extracted.start, requestedWeekday);
            endDt = _alignToRequestedWeekday(extracted.end, requestedWeekday);
          }
        }

        // If user explicitly asks to shift to PM, fix ambiguous early-hour times (e.g., 02:10 -> 14:10).
        if (_isPmCorrectionRequest(sourceUserText) && startDt.hour <= 6) {
          startDt = startDt.add(const Duration(hours: 12));
          endDt = endDt.add(const Duration(hours: 12));
        }

        final resolvedSummary = (action.summary?.trim().isNotEmpty ?? false)
            ? action.summary!.trim()
            : (_inferCreateSummaryFromText(sourceUserText) ?? 'Scheduled Event');

        final event = calendar.Event(
          summary: resolvedSummary,
          start: calendar.EventDateTime(dateTime: startDt),
          end: calendar.EventDateTime(dateTime: endDt),
        );
        
        List<String>? recurrenceRule;
        if (action.recurrence != null && action.recurrence!.isNotEmpty) {
           String rule = action.recurrence!;
           if (!rule.startsWith("RRULE:")) rule = "RRULE:$rule";
           recurrenceRule = [rule];
          } else if (sourceUserText != null && _shouldDefaultWeeklyRecurrence(sourceUserText, requestedWeekday)) {
            recurrenceRule = ['RRULE:FREQ=WEEKLY'];
        }

          final createdEvent = await _calendarService.addEvent(event, recurrence: recurrenceRule);
        _addSystemStatus("Scheduled '$resolvedSummary' at ${startDt.hour}:${startDt.minute.toString().padLeft(2,'0')}.", persist: false);

        if (createdEvent.id != null) {
          final eventId = createdEvent.id!;
          _undoStack.add(
            _UndoEntry(
              label: "CREATE $resolvedSummary",
              undo: () => _calendarService.deleteEvent(eventId),
            ),
          );
        }
        
        if (createdEvent.id != null) {
           await _aiService.memory.addPendingDebrief(
             createdEvent.id!, 
             resolvedSummary,
             endDt
           );
        }
      } catch (e, stack) {
        debugPrint("Calendar Create Error: $e\n$stack");
        _addSystemError("Calendar create", e);
      }
    } 
    else if (action.type == 'update_timetable') {
       if (action.slots != null && action.slots!.isNotEmpty) {
          try {
             await _timetableService.updateTimetable(action.slots!);
           _addSystemStatus("Weekly timetable updated and synced to calendar.", persist: false);
          } catch (e) {
           _addSystemError("Timetable sync", e);
          }
       } else if (targetEventId != null && targetEvent != null && action.startTime != null) {
         try {
           final backup = targetEvent;
           final existingStart = backup.start?.dateTime?.toLocal() ?? DateTime.now();
           var startDt = _applyClockToDate(action.startTime!, existingStart);
           startDt = _alignToRequestedWeekday(startDt, requestedWeekday);

           final existingEnd = backup.end?.dateTime?.toLocal();
           final existingDuration = (existingEnd != null && existingEnd.isAfter(existingStart))
               ? existingEnd.difference(existingStart).inMinutes
               : (action.durationMinutes ?? 60);
           var endDt = startDt.add(Duration(minutes: existingDuration));

           if (_isPmCorrectionRequest(sourceUserText) && startDt.hour <= 6) {
             startDt = startDt.add(const Duration(hours: 12));
             endDt = endDt.add(const Duration(hours: 12));
           }

           final editableEventId =
               (backup.recurringEventId != null && backup.recurringEventId!.isNotEmpty)
                   ? backup.recurringEventId!
                   : targetEventId;

           final patch = calendar.Event(
             summary: backup.summary ?? action.summary,
             start: calendar.EventDateTime(dateTime: startDt),
             end: calendar.EventDateTime(dateTime: endDt),
             recurrence: backup.recurrence,
           );

           final updatedEvent = await _calendarService.updateEvent(editableEventId, patch);

           _addSystemStatus(
             "Updated '${backup.summary ?? action.summary}' to ${startDt.hour.toString().padLeft(2, '0')}:${startDt.minute.toString().padLeft(2, '0')}",
             persist: false,
           );

           _undoStack.add(
             _UndoEntry(
               label: "UPDATE ${backup.summary ?? 'event'}",
               undo: () async {
                 final restore = calendar.Event(
                   summary: backup.summary,
                   start: backup.start,
                   end: backup.end,
                   recurrence: backup.recurrence,
                 );
                 await _calendarService.updateEvent(editableEventId, restore);
               },
             ),
           );

           if (updatedEvent.id == null) {
             debugPrint('WARN: Timetable edit update returned null id for ${backup.summary ?? action.summary}');
           }
         } catch (e) {
           _addSystemError("Timetable edit", e);
         }
       } else {
         _addSystemStatus("Cannot update timetable: slots were missing.", persist: false);
       }
    }
    else if (action.type == 'delete') {
       final isBulkDelete = action.summary == null || 
          action.summary!.toLowerCase().contains('all') || 
          action.summary!.toLowerCase().contains('timetable') || 
          action.summary!.toLowerCase().contains('schedule');

       if (isBulkDelete) {
         try {
           final backup = List<TimetableSlot>.from(_timetableService.slots);
           await _timetableService.updateTimetable([]);
           _addSystemStatus("Cleared all timetable schedules.", persist: false);
           
           if (backup.isNotEmpty) {
             _undoStack.add(
               _UndoEntry(
                 label: "CLEAR TIMETABLE",
                 undo: () => _timetableService.updateTimetable(backup),
               ),
             );
           }
         } catch (e) {
           _addSystemError("Timetable clear", e);
         }
       } else if (targetEventId != null) {
         try {
           final backup = targetEvent;
           await _calendarService.deleteEvent(targetEventId);
          _addSystemStatus("Event deleted.", persist: false);

           if (backup != null) {
             _undoStack.add(
               _UndoEntry(
                 label: "DELETE ${backup.summary ?? 'event'}",
                 undo: () => _calendarService.addEvent(backup),
               ),
             );
           }
         } catch (e) {
           _addSystemError("Event delete", e);
         }
       }
    }
    else if (action.type == 'move') {
       if (targetEventId != null && action.startTime != null) {
          try {
            final backup = targetEvent;
            await _calendarService.deleteEvent(targetEventId);
            final parsedStart = _parseEventDateTime(action.startTime!);
            var startDt = _alignToRequestedWeekday(parsedStart, requestedWeekday);
            var endDt = startDt.add(Duration(minutes: action.durationMinutes ?? 60));

            if (_isPmCorrectionRequest(sourceUserText) && startDt.hour <= 6) {
              startDt = startDt.add(const Duration(hours: 12));
              endDt = endDt.add(const Duration(hours: 12));
            }
            
            final event = calendar.Event(
              summary: action.summary,
              start: calendar.EventDateTime(dateTime: startDt),
              end: calendar.EventDateTime(dateTime: endDt),
            );
            
            final movedEvent = await _calendarService.addEvent(event);
            _addSystemStatus("Event moved to ${startDt.hour}:${startDt.minute.toString().padLeft(2,'0')}.", persist: false);

            if (backup != null && movedEvent.id != null) {
              final movedId = movedEvent.id!;
              _undoStack.add(
                _UndoEntry(
                  label: "MOVE ${backup.summary ?? 'event'}",
                  undo: () async {
                    await _calendarService.deleteEvent(movedId);
                    await _calendarService.addEvent(backup);
                  },
                ),
              );
            }
          } catch (e) {
            _addSystemError("Event move", e);
          }
       } else {
          _addSystemStatus("Cannot move event: target or new time is missing.", persist: false);
       }
    }
    else if (action.type == 'notify') {
      final body = (action.message ?? action.summary ?? '').trim();
      if (body.isEmpty) {
        _addSystemStatus("Cannot send notification: message body is empty.", persist: false);
        return;
      }

      final notifyAtRaw = action.notifyAt?.trim();
      if (notifyAtRaw == null || notifyAtRaw.isEmpty) {
        await _notificationService.notifyNow(title: "Vyoma", body: body);
        _addSystemStatus("Proactive message sent.", persist: false);
      } else {
        final at = _parseEventDateTime(notifyAtRaw);
        await _notificationService.scheduleInApp(
          title: "Vyoma",
          body: body,
          when: at,
          onDispatch: () {
            _addMessage("VYOMA", body);
          },
        );
        _addSystemStatus("Proactive message scheduled for ${at.toLocal()}.", persist: false);
      }
    }
  }

  // --- DEBUG: FACTORY RESET ---
  Future<void> _performFactoryReset() async {
    _addSystemStatus("⚠️ FACTORY RESET: Wiping all data...", persist: false);
    notifyListeners();

    try {
      // 1. Clear SharedPreferences (onboarding flag, timetable, synced IDs, etc.)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Delete productivity metrics file
      try {
        final metricsFile = await _getMetricsFile();
        if (await metricsFile.exists()) {
          await metricsFile.delete();
        }
      } catch (_) {}

      // 3. Wipe timetable in-memory
      await _timetableService.updateTimetable([]);

      // 4. Clear in-memory state
      _messages.clear();
      _currentMetrics = ProductivityMetrics(focusMinutes: 0, distractionCount: 0, tasksCompleted: 0);
      _focusSessionActive = false;
      _focusSessionIntent = null;
      _focusSessionStartedAt = null;
      _pendingActionPlan = null;
      _undoStack.clear();

      _addSystemStatus("✅ All data wiped. Restarting app...", persist: false);
      notifyListeners();

      // 5. Force restart — exit the process so Flutter re-launches from main()
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (e) {
      _addSystemStatus("Reset failed: $e", persist: false);
      notifyListeners();
    }
  }
}
