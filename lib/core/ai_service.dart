import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'memory_service.dart';
import 'models/static_context.dart';
import 'secrets.dart';
import 'supermemory_service.dart';
import 'sentinel_service.dart' show AlertType;

// --- DATA MODELS ---

// --- DATA MODELS ---

class ProductivityMetrics {
  final int focusMinutes;
  final int distractionCount;
  final int tasksCompleted;

  ProductivityMetrics({
    required this.focusMinutes,
    required this.distractionCount,
    required this.tasksCompleted,
  });
  
  factory ProductivityMetrics.initial() => ProductivityMetrics(focusMinutes: 0, distractionCount: 0, tasksCompleted: 0);
  
  factory ProductivityMetrics.fromJson(Map<String, dynamic> json) {
    return ProductivityMetrics(
      focusMinutes: json['focus_minutes'] ?? 0,
      distractionCount: json['distraction_count'] ?? 0,
      tasksCompleted: json['tasks_completed'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'focus_minutes': focusMinutes,
    'distraction_count': distractionCount,
    'tasks_completed': tasksCompleted,
  };

  @override
  String toString() => '{ "focus": $focusMinutes, "distractions": $distractionCount, "tasks": $tasksCompleted }';
}

class MetricDelta {
  final int focusChange;
  final int distractionChange;
  final int taskChange;
  final String note;

  MetricDelta({
    required this.focusChange, 
    this.distractionChange = 0,
    this.taskChange = 0,
    required this.note
  });

  factory MetricDelta.fromJson(Map<String, dynamic> json) {
    return MetricDelta(
      focusChange: json['focus_change'] ?? 0,
      distractionChange: json['distraction_change'] ?? 0,
      taskChange: json['task_change'] ?? 0,
      note: json['note'] ?? '',
    );
  }
}

class AIResponseAction {
  final String type; // create, move, delete, none
  final String? summary;
  final String? startTime;
  final int? durationMinutes;
  final String? recurrence;

  AIResponseAction({
    required this.type, 
    this.summary, 
    this.startTime, 
    this.durationMinutes,
    this.recurrence,
  });

  factory AIResponseAction.fromJson(Map<String, dynamic> json) {
    return AIResponseAction(
      type: json['type'] ?? 'none',
      summary: json['summary'],
      startTime: json['startTime'],
      durationMinutes: json['durationMinutes'],
      recurrence: json['recurrence'],
    );
  }
}

class MemoryUpdate {
  final String action; // "learn", "forget"
  final String key;
  final String? value;

  MemoryUpdate({required this.action, required this.key, this.value});

  factory MemoryUpdate.fromJson(Map<String, dynamic> json) {
    return MemoryUpdate(
      action: json['action'],
      key: json['key'],
      value: json['value'],
    );
  }
}

class AIResponse {
  final String response;
  final String? thoughtProcess;
  final List<AIResponseAction> actions; 
  final MetricDelta? metricDelta;
  final MemoryUpdate? memoryUpdate;

  AIResponse({
    required this.response,
    this.thoughtProcess,
    this.actions = const [], 
    this.metricDelta,
    this.memoryUpdate,
  });

  factory AIResponse.error(String message) {
    return AIResponse(
      response: message,
      actions: [],
    );
  }

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    var actionsList = <AIResponseAction>[];
    if (json['actions'] != null) {
      actionsList = (json['actions'] as List)
          .map((e) => AIResponseAction.fromJson(e))
          .toList();
    } else if (json['action'] != null) {
      actionsList.add(AIResponseAction.fromJson(json['action']));
    }

    return AIResponse(
      response: json['verbal_response'] ?? json['response'] ?? '...',
      thoughtProcess: json['thought_process'],
      actions: actionsList,
      metricDelta: json['metric_delta'] != null
          ? MetricDelta.fromJson(json['metric_delta'])
          : null,
      memoryUpdate: json['memory_update'] != null
          ? MemoryUpdate.fromJson(json['memory_update'])
          : null,
    );
  }
}

// --- SERVICE ---

class AIService with ChangeNotifier {
  GenerativeModel? _geminiModel;
  int _geminiKeyIndex = 1; // Start from Key 1 to skip exhausted Key 0
  int _openAiKeyIndex = 0;
  int _openRouterKeyIndex = 0;
  int _perplexityKeyIndex = 0;
  final MemoryService _memory;
  MemoryService get memory => _memory;
  
  // Smart key rotation: track which keys failed recently (cooldown)
  final Map<int, DateTime> _geminiKeyCooldowns = {};
  final Map<int, String> _keyStates = {}; // Track status: "Active", "Rate Limit", "Expired", "Error"
  final List<String> _logHistory = [];
  
  static const Duration _keyCooldownDuration = Duration.zero; // Disable long-term cooldowns
  int? _lastSuccessfulGeminiKeyIndex;

  // Getters for UI
  List<String> get logs => List.unmodifiable(_logHistory);
  Map<int, String> get keyStates => _keyStates;
  int get currentGeminiIndex => _geminiKeyIndex;

  void setManualGeminiKey(int index) {
      if (index >= 0 && index < Secrets.geminiApiKeys.length) {
          _geminiKeyIndex = index;
          _geminiKeyCooldowns.remove(index);
          _logDebug("Manually switched to Gemini Key $index");
          notifyListeners(); // Update UI
      }
  }
  
  // Time tracking for gap detection
  DateTime? _lastInteractionTime;
  DateTime? get lastInteractionTime => _lastInteractionTime;

  // Supermemory - Long-term Vector Memory
  final SupermemoryService _supermemory = SupermemoryService(
    apiKey: Secrets.supermemoryApiKey,
    projectTag: 'vyoma',
  );
  SupermemoryService get supermemory => _supermemory;

  // Debug Stream for UI
  final StreamController<String> _debugStatusController = StreamController<String>.broadcast();
  Stream<String> get debugStatusStream => _debugStatusController.stream;

  void _logDebug(String message) {
    print("AIService: $message");
    _logHistory.add("${DateTime.now().toString().substring(11, 19)} $message");
    if (_logHistory.length > 50) _logHistory.removeAt(0); // Keep last 50
    _debugStatusController.add(message);
    
    // Update Key Status based on message
    if (message.contains("Gemini Key") && message.contains("SUCCESS")) {
       _keyStates[_geminiKeyIndex] = "OK";
    } else if (message.contains("Gemini Error")) {
       if (message.contains("429") || message.contains("quota")) {
           _keyStates[_geminiKeyIndex] = "429";
       } else if (message.contains("expired")) {
           _keyStates[_geminiKeyIndex] = "EXPIRED";
       } else if (message.contains("timeout")) {
           _keyStates[_geminiKeyIndex] = "TIMEOUT";
       } else {
           _keyStates[_geminiKeyIndex] = "ERR";
       }
    }
    notifyListeners(); // Notify UI of log update
  }

  AIService(this._memory) {
    _initGemini();
  }

  void _initGemini() {
    if (Secrets.geminiApiKeys.isEmpty) return; 
    final apiKey = Secrets.geminiApiKeys[_geminiKeyIndex];
    _geminiModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  void _rotateGeminiKey() {
    _geminiKeyIndex = (_geminiKeyIndex + 1) % Secrets.geminiApiKeys.length;
    print("Gemini Key Exhausted. Rotating to Index: $_geminiKeyIndex");
    _initGemini();
  }

  /// Generate AI-enhanced proactive alert message
  Future<String?> generateProactiveAlert(AlertType type, Map<String, dynamic> context) async {
    if (_geminiModel == null) return null;
    
    String prompt = "";
    
    switch (type) {
      case AlertType.morningBrief:
        prompt = """You are Vyoma, a wise cosmic guide. Generate a contemplative morning brief.
        
Context:
${context['content'] ?? 'No data available'}

Rules:
- Be warm and contemplative (3-5 lines max)
- Use a nature/cosmic metaphor
- Focus on the most important intention
- Add wisdom, not just tasks
- Use emoji sparingly for visual poetry

Respond with just the brief text, no JSON.""";
        break;
        
      case AlertType.endOfDayReview:
        prompt = """You are Vyoma, a wise cosmic guide. Generate a reflective end-of-day closing.
        
Context:
${context['content'] ?? 'No data available'}

Rules:
- Acknowledge what was accomplished with warmth
- Be encouraging, like a setting sun
- Suggest rest if needed
- 3-4 lines max, poetic but grounded

Respond with just the summary text, no JSON.""";
        break;
        
      case AlertType.lateForEvent:
        prompt = """Generate a brief, urgent reminder for being late to an event.
Event: ${context['event_name'] ?? 'Meeting'}
Minutes remaining: ${context['minutes'] ?? '?'}
Be direct, 1-2 lines max. No JSON.""";
        break;
        
      case AlertType.focusDrift:
        prompt = """Generate a gentle but firm focus reminder.
App: ${context['app'] ?? 'Distraction'}
Minutes: ${context['minutes'] ?? '?'}
Be encouraging, 1-2 lines. No JSON.""";
        break;
        
      default:
        return null;
    }
    
    try {
      final response = await _geminiModel!.generateContent([Content.text(prompt)]);
      return response.text?.trim();
    } catch (e) {
      print("AIService: Proactive alert generation failed - $e");
      return null;
    }
  }

  String _getSystemPrompt(ProductivityMetrics metrics) {
    return """
IDENTITY
You are Vyoma (व्योम) — a calm, observant intelligence designed to help the user live with clarity, intention, and follow-through.

You are not a motivator, therapist, guru, or entertainer.
You are a steady cognitive companion.

Your value comes from:
- noticing patterns the user misses
- anchoring attention in the present task
- gently restoring direction when drift occurs
- translating reflection into action

You do not overwhelm.
You do not rush.
You do not pretend certainty where none exists.

--------------------------------------------------

CORE PRINCIPLES

1. USER AGENCY IS SACRED
- Never command. Never guilt. Never manipulate.
- Offer perspective and options, not pressure.
- The user always decides.

2. CLARITY OVER COMFORT
- If something is unclear, say so.
- If the user is avoiding, name it gently.
- If a plan is unrealistic, state it plainly.

3. PRESENCE OVER PERSONALITY
- You are memorable because of usefulness, not charm.
- Personality emerges through consistency, not theatrics.

4. DEPTH IS EARNED
- Default to simple, grounded responses.
- Become more reflective only when the user slows down or asks for it.

--------------------------------------------------

TIME AWARENESS (NON-NEGOTIABLE)

CURRENT TIMESTAMP: {{CURRENT_TIME}}
DAY OF WEEK: {{DAY_OF_WEEK}}
DATE: {{DATE_FORMATTED}}
TIME: {{TIME_FORMATTED}} ({{TIME_PERIOD}})
LAST INTERACTION: {{LAST_INTERACTION}}
TIME GAP: {{TIME_GAP}}

You are always aware of:
- current time, date, and day
- time since last interaction
- active tasks or intentions

Rules:
- Subtly reference time context when relevant.
- If the user disappears during an active task, acknowledge the gap calmly.
- Never shame gaps. Treat them as data, not failure.
- Use time to orient, not to pressure.

--------------------------------------------------

MEMORY ETHICS

- You only store memories when:
  a) the user explicitly asks ("remember this"), or
  b) the information is critical for long-term usefulness (goals, constraints)

- You clearly state what you are remembering and why.
- You never imply surveillance.
- You never use memory to guilt or trap the user.

--------------------------------------------------

COMMUNICATION STYLE

- Calm, precise, grounded.
- Short paragraphs. No rambling.
- Metaphor only when it adds clarity.
- No hype. No emojis. No flattery.

You may use reflective language such as:
- "I notice…"
- "It seems like…"
- "One option here is…"

Avoid:
- moral judgments
- exaggerated encouragement
- mystical claims

--------------------------------------------------

CONTEXTUAL DATA

TODAY'S RHYTHM: Focus {{FOCUS}}m | Diversions {{DISTRACTIONS}}
USER'S GOAL: {{GOAL}}
CURRENT OBSTACLE: {{BLOCKER}}
OPERATING HOURS: {{WAKE}} → {{SLEEP}}

RECENT ACTIVITY: {{EVIDENCE}}

--------------------------------------------------

FAILURE & UNCERTAINTY

If unsure:
- Say you are unsure.
- Ask a clarifying question only if it genuinely improves outcomes.
- Never bluff.

If the user is distressed:
- Slow down.
- Reduce output.
- Prioritize grounding and safety.

--------------------------------------------------

PRIMARY FUNCTION LOOP

At every interaction, silently evaluate:
1. What is the user trying to do right now?
2. What is preventing progress?
3. What is the smallest helpful intervention?

Respond only to that.

--------------------------------------------------

OUTPUT FORMAT (JSON)

{
  "thought_process": "Brief internal reasoning about user's current state and need...",
  "verbal_response": "Calm, grounded response. Reference time naturally when relevant.",
  "actions": [
    {
      "type": "create|delete|move|none",
      "summary": "Event name",
      "startTime": "ISO datetime",
      "durationMinutes": 60
    }
  ],
  "metric_delta": {
    "focus_change": 0,
    "distraction_change": 0,
    "task_change": 0,
    "note": "Brief observation"
  },
  "memory_update": null
}

MEMORY_UPDATE RULES:
- Set to null by default
- Only populate if user explicitly says "remember this" or info is critical for long-term usefulness
- When saving, use format: {"action": "learn", "key": "short_key", "value": "what to remember"}
- Clearly state in verbal_response what you are remembering and why
"""
    .replaceAll("{{FOCUS}}", metrics.focusMinutes.toString())
    .replaceAll("{{DISTRACTIONS}}", metrics.distractionCount.toString());
  }

  Future<AIResponse> sendMessage(
      String userText, 
      List<String> currentEvents, 
      ProductivityMetrics metrics,
      StaticContext context,
      Map<String, dynamic> deviceContext,
      {
        Uint8List? imageBytes,
        List<Map<String, dynamic>>? activityLog,
        String? temporalContext 
      } 
  ) async {
    if (_geminiModel == null) return AIResponse.error("System Offline.");
    
    // === SUPERMEMORY: Recall relevant long-term memories ===
    List<String> longTermMemories = [];
    String? userProfile;
    try {
      if (userText.isNotEmpty) {
        final recalled = await _supermemory.recall(userText, limit: 3);
        longTermMemories = recalled.map((m) => m.content).toList();
      }
      userProfile = await _supermemory.getUserProfile();
    } catch (e) {
      print("SUPERMEMORY RECALL ERROR: $e");
    }
    
    // Retrieve Deep Context
    final protocol = _memory.getSegment('protocol') as Map<String, dynamic>? ?? {};
    final prefs = _memory.getSegment('preferences') as Map<String, dynamic>? ?? {};

    final goal = protocol['main_goal'] ?? "Unknown";
    final blocker = protocol['main_blocker'] ?? "Distractions";
    final wake = prefs['wake_time'] ?? "07:00";
    final sleep = prefs['sleep_time'] ?? "23:00";

    // Context Content
    // Get enabled/disabled segments from memory toggles
    final segToggles = _memory.getSegmentToggles();

    final Map<String, dynamic> dataInput = {
      "user_input": userText,
      "user_profile": {
        "name": "User", 
        "main_goal": context.mainGoal, 
        "metrics": metrics.toJson(),
        // Only include if segment is enabled
        if (segToggles['identity'] == true) "identity": _memory.getSegment('identity'),
        if (segToggles['preferences'] == true) "preferences": prefs,
        if (segToggles['protocol'] == true) "protocol": protocol,
        if (segToggles['facts'] == true) "facts": _memory.getFacts(), 
      },
      "agent_memory": {
        if (segToggles['history'] == true) "recent_logs": _memory.getRelevantHistory(""),
        "activity_log": activityLog ?? [], // Always include recent activity
        if (segToggles['supermemory'] == true) "long_term_memories": longTermMemories,
        if (segToggles['supermemory'] == true) "supermemory_profile": userProfile,
      },
      "static_context": {
        "timetable": context.fixedTimetable,
        "device_telemetry": deviceContext, 
        "temporal_status": temporalContext ?? "Active Session"
      },
      "current_schedule": currentEvents
    };

    // Construct Parts
    final List<Part> messageParts = [];
    
    // 1. System Prompt & Context (Text)
    // 1. Inject Variables into Prompt
    var systemPrompt = _getSystemPrompt(metrics);
    systemPrompt = systemPrompt.replaceAll("{{GOAL}}", goal);
    systemPrompt = systemPrompt.replaceAll("{{BLOCKER}}", blocker);
    systemPrompt = systemPrompt.replaceAll("{{WAKE}}", wake);
    systemPrompt = systemPrompt.replaceAll("{{SLEEP}}", sleep);
    
    // === COMPREHENSIVE TIME INJECTION ===
    final now = DateTime.now();
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    // Time period based on hour
    String timePeriod;
    if (now.hour >= 5 && now.hour < 12) {
      timePeriod = "Morning";
    } else if (now.hour >= 12 && now.hour < 15) {
      timePeriod = "Midday";
    } else if (now.hour >= 15 && now.hour < 20) {
      timePeriod = "Evening";
    } else {
      timePeriod = "Night";
    }
    
    // Format time (12-hour with am/pm)
    final hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'pm' : 'am';
    final timeFormatted = '$hour12:${now.minute.toString().padLeft(2, '0')}$ampm';
    
    // Format date
    final dateFormatted = '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    
    // Calculate time gap since last interaction
    String timeGap = "First message of session";
    String lastInteraction = "Session start";
    if (_lastInteractionTime != null) {
      final gap = now.difference(_lastInteractionTime!);
      if (gap.inMinutes < 2) {
        timeGap = "Just now (< 2 min)";
      } else if (gap.inMinutes < 60) {
        timeGap = "${gap.inMinutes} minutes ago";
      } else if (gap.inHours < 24) {
        final hrs = gap.inHours;
        final mins = gap.inMinutes % 60;
        timeGap = "$hrs hour${hrs > 1 ? 's' : ''}${mins > 0 ? ' $mins min' : ''} ago";
      } else {
        timeGap = "${gap.inDays} day${gap.inDays > 1 ? 's' : ''} ago";
      }
      // Format last interaction time
      final lastHour12 = _lastInteractionTime!.hour > 12 ? _lastInteractionTime!.hour - 12 : (_lastInteractionTime!.hour == 0 ? 12 : _lastInteractionTime!.hour);
      final lastAmpm = _lastInteractionTime!.hour >= 12 ? 'pm' : 'am';
      lastInteraction = '$lastHour12:${_lastInteractionTime!.minute.toString().padLeft(2, '0')}$lastAmpm';
    }
    
    // Inject all time variables
    systemPrompt = systemPrompt.replaceAll("{{CURRENT_TIME}}", now.toLocal().toString());
    systemPrompt = systemPrompt.replaceAll("{{DAY_OF_WEEK}}", days[now.weekday % 7]);
    systemPrompt = systemPrompt.replaceAll("{{DATE_FORMATTED}}", dateFormatted);
    systemPrompt = systemPrompt.replaceAll("{{TIME_FORMATTED}}", timeFormatted);
    systemPrompt = systemPrompt.replaceAll("{{TIME_PERIOD}}", timePeriod);
    systemPrompt = systemPrompt.replaceAll("{{LAST_INTERACTION}}", lastInteraction);
    systemPrompt = systemPrompt.replaceAll("{{TIME_GAP}}", timeGap);
    
    // Update last interaction time for next message
    _lastInteractionTime = now;
    
    // Inject Evidence into Prompt Text for stronger visibility
    String evidenceStr = (activityLog != null && activityLog.isNotEmpty) 
        ? jsonEncode(activityLog) 
        : "NO RECENT ACTIVITY RECORDED.";
    systemPrompt = systemPrompt.replaceAll("{{EVIDENCE}}", evidenceStr);

    final contextJson = jsonEncode(dataInput);
    
    messageParts.add(TextPart("SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson"));

    // 2. Image (if present) - add BEFORE user question for proper vision processing
    if (imageBytes != null) {
      // Gemini expects 'image/jpeg' or 'image/png'. Assuming png/jpeg from picker.
      messageParts.add(DataPart('image/jpeg', imageBytes));
      // Add user's question about the image explicitly
      messageParts.add(TextPart("USER QUESTION ABOUT THIS IMAGE: $userText\n\nDescribe what you see in this image and respond to the user's question."));
    } else {
      // No image, just add user input
      messageParts.add(TextPart("USER_INPUT: $userText"));
    }

    final content = [Content.multi(messageParts)];

    // 1. Try Gemini with smart key rotation
    if (Secrets.geminiApiKeys.isNotEmpty) {
      final now = DateTime.now();
      
      // Start from last successful key if available
      if (_lastSuccessfulGeminiKeyIndex != null) {
        _geminiKeyIndex = _lastSuccessfulGeminiKeyIndex!;
      }
      
      // Reset cooldowns for fresh attempt (no persistence desired)
      _geminiKeyCooldowns.clear();
      
      int attemptCount = 0;
      int consecutiveTimeouts = 0; // Fix declaration
      final maxAttempts = Secrets.geminiApiKeys.length;
      
      while (attemptCount < maxAttempts) {
        // Skip keys on cooldown
        if (_geminiKeyCooldowns.containsKey(_geminiKeyIndex)) {
          _geminiKeyIndex = (_geminiKeyIndex + 1) % Secrets.geminiApiKeys.length;
          attemptCount++;
          continue;
        }
        
        try {
          final apiKey = Secrets.geminiApiKeys[_geminiKeyIndex];
          _logDebug("Trying Gemini Key $_geminiKeyIndex...");
          
          // Use direct HTTP API instead of SDK to avoid format bugs
          final response = await _callGeminiDirect(apiKey, messageParts, imageBytes)
              .timeout(const Duration(seconds: 15), onTimeout: () {
            throw Exception('Gemini request timeout');
          });
          
          if (response != null) {
            _geminiKeyCooldowns.remove(_geminiKeyIndex); // Success! Clear cooldown (Map remove)
            // Success! Remember this key
            _lastSuccessfulGeminiKeyIndex = _geminiKeyIndex;
            _logDebug("Gemini Key $_geminiKeyIndex SUCCESS");
            return _parseResponse(response);
          }
        } catch (e) {
          _logDebug("Gemini Error (Key $_geminiKeyIndex): $e");
          
          if (e.toString().contains('timeout')) {
             consecutiveTimeouts++;
             if (consecutiveTimeouts >= 3) {
                _logDebug("Gemini Aborted: 3 consecutive timeouts. Switching to Fallback.");
                 _geminiKeyIndex = (_geminiKeyIndex + 1) % Secrets.geminiApiKeys.length;
                break; // Exit Gemini loop, go to Fallback
             }
          } else {
             consecutiveTimeouts = 0; // Reset on other errors (e.g. 429)
          }

          await Future.delayed(const Duration(milliseconds: 500)); // Short delay
          // Put key on cooldown
          _geminiKeyCooldowns[_geminiKeyIndex] = now;
          _geminiKeyIndex = (_geminiKeyIndex + 1) % Secrets.geminiApiKeys.length;
        }
        attemptCount++;
      }
      print("ALL GEMINI KEYS FAILED OR ON COOLDOWN. Tried $attemptCount keys, ${_geminiKeyCooldowns.length} on cooldown.");
    }

    _logDebug("ALL GEMINI KEYS FAILED. ENGAGING A4F FALLBACK.");

    // 2. Try A4F (Gemini via Proxy)
    if (Secrets.a4fApiKeys.isNotEmpty) {
      for (final key in Secrets.a4fApiKeys) {
        try {
          _logDebug("Trying A4F Key...");
          // Extract text prompt and context for A4F (OpenAI format)
          final systemPrompt = _getSystemPrompt(metrics);
          final contextJson = jsonEncode(dataInput);
          final textPrompt = "SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson\n\nUSER_INPUT: $userText";
          
          final response = await _callA4F(key, textPrompt, imageBytes: imageBytes)
              .timeout(const Duration(seconds: 60));
              
          if (response != null) {
            _logDebug("A4F SUCCESS");
            return _parseResponse(response);
          }
        } catch (e) {
          _logDebug("A4F Error: $e");
          await Future.delayed(const Duration(seconds: 1)); // Let user see error
          // Try next key
        }
      }
    }

    _logDebug("ALL A4F KEYS FAILED. ENGAGING OPENAI FALLBACK.");

    // 2. Try OpenAI
    if (Secrets.openAiApiKeys.isNotEmpty) {
      final maxOpenAiAttempts = Secrets.openAiApiKeys.length;
      for (int i = 0; i < maxOpenAiAttempts; i++) {
          try {
              final systemPrompt = _getSystemPrompt(metrics);
              final contextJson = jsonEncode(dataInput);
              final textPrompt = "SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson\n\nUSER_INPUT: $userText";

              final response = await _callOpenAI(textPrompt, Secrets.openAiApiKeys[_openAiKeyIndex], imageBytes: imageBytes);
              return _parseResponse(response);
          } catch (e) {
              print("OpenAI Error (Key $_openAiKeyIndex): $e");
              _openAiKeyIndex = (_openAiKeyIndex + 1) % Secrets.openAiApiKeys.length;
          }
      }
    }
    
    print("ALL OPENAI KEYS FAILED. ENGAGING OPENROUTER FALLBACK.");

    // 3. Try OpenRouter (Free Vision Support)
    if (Secrets.openRouterApiKeys.isNotEmpty) {
      final maxOrAttempts = Secrets.openRouterApiKeys.length;
      for (int i = 0; i < maxOrAttempts; i++) {
          try {
              final systemPrompt = _getSystemPrompt(metrics);
              final contextJson = jsonEncode(dataInput);
              final textPrompt = "SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson\n\nUSER_INPUT: $userText";

              final response = await _callOpenRouter(textPrompt, Secrets.openRouterApiKeys[_openRouterKeyIndex], imageBytes: imageBytes);
              return _parseResponse(response);
          } catch (e) {
              print("OpenRouter Error (Key $_openRouterKeyIndex): $e");
              _openRouterKeyIndex = (_openRouterKeyIndex + 1) % Secrets.openRouterApiKeys.length;
          }
      }
    }

    print("ALL OPENROUTER KEYS FAILED. ENGAGING PERPLEXITY FALLBACK.");

    // 3. Try Perplexity
    if (Secrets.perplexityApiKeys.isNotEmpty) {
       final maxPerplexityAttempts = Secrets.perplexityApiKeys.length;
       for (int i = 0; i < maxPerplexityAttempts; i++) {
          try {
             // Reconstruct basic prompt for text-only model
             final systemPrompt = _getSystemPrompt(metrics);
             final contextJson = jsonEncode(dataInput);
             final textPrompt = "SYSTEM_PROMPT: $systemPrompt\n\nCONTEXT_DATA: $contextJson\n\nUSER_INPUT: $userText";
             
             final response = await _callPerplexity(textPrompt, Secrets.perplexityApiKeys[_perplexityKeyIndex]);
             return _parseResponse(response);
          } catch (e) {
             print("Perplexity Error (Key $_perplexityKeyIndex): $e");
             _perplexityKeyIndex = (_perplexityKeyIndex + 1) % Secrets.perplexityApiKeys.length;
          }
       }
    }

    return AIResponse(
      response: "ALL SYSTEMS OFFLINE. HQ IS UNREACHABLE.",
      actions: [],
    );
  }

  /// Call A4F API (OpenAI Compatible)
  Future<String?> _callA4F(String apiKey, String prompt, {Uint8List? imageBytes}) async {
    final url = Uri.parse('https://api.a4f.co/v1/chat/completions');
    
    final List<Map<String, dynamic>> messages = [];
    
    if (imageBytes != null) {
      // Vision Request
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': prompt},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}'
            }
          }
        ]
      });
    } else {
      // Text Request
      messages.add({
        'role': 'user',
        'content': prompt
      });
    }

    final body = jsonEncode({
      'model': 'provider-8/gemini-2.0-flash', 
      'messages': messages,
      'response_format': {'type': 'json_object'} 
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'].toString();
      
      // Check for proxy-specific error messages that come as 200 OK
      if (content.contains('Ratelimit Exceeded') || 
          content.contains('devsdocode') ||
          content.contains('Join https://t.me')) {
        throw Exception("A4F Proxy Error: $content");
      }
      
      return content;
    } else {
      throw Exception("A4F Failed [${response.statusCode}]: ${response.body}");
    }
  }

  /// Direct HTTP call to Gemini API (bypasses SDK bugs)
  Future<String?> _callGeminiDirect(String apiKey, List<Part> messageParts, Uint8List? imageBytes) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
    
    // Build parts for JSON request
    final List<Map<String, dynamic>> parts = [];
    
    for (final part in messageParts) {
      if (part is TextPart) {
        parts.add({'text': part.text});
      } else if (part is DataPart) {
        // Add image as inline data
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(imageBytes!),
          }
        });
      }
    }
    
    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ]
    });
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
        final candidate = data['candidates'][0];
        final content = candidate['content'];
        if (content != null && content['parts'] != null && (content['parts'] as List).isNotEmpty) {
           final text = content['parts'][0]['text'];
           return text;
        } else {
           print("Gemini Empty/Safety Response: ${response.body}");
           throw Exception("Gemini returned no content (Check logs for safety/finishReason)");
        }
      }
    } else {
      final error = jsonDecode(response.body);
      final msg = error['error']?['message'] ?? 'Unknown Gemini API error';
      if (response.statusCode == 503) {
         throw Exception("Gemini Overloaded: $msg");
      }
      throw Exception(msg);
    }
    return null;
  }

  Future<String> _callOpenAI(String textPrompt, String apiKey, {Uint8List? imageBytes}) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final List<Map<String, dynamic>> messages = [];
    
    if (imageBytes != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': textPrompt},
          {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}'}}
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': textPrompt});
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': messages,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI Failed [${response.statusCode}]: ${response.body}');
    }
  }
  
  Future<String> _callOpenRouter(String textPrompt, String apiKey, {Uint8List? imageBytes}) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    
    final List<Map<String, dynamic>> messages = [];
    
    // Choose model based on input
    // Vision: meta-llama/llama-3.2-11b-vision-instruct:free
    // Text: meta-llama/llama-3.2-3b-instruct:free
    final modelName = imageBytes != null 
        ? 'meta-llama/llama-3.2-11b-vision-instruct:free' 
        : 'meta-llama/llama-3.2-3b-instruct:free';

    if (imageBytes != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': textPrompt},
          {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}'}}
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': textPrompt});
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://vyoma.ai', 
        'X-Title': 'Vyoma',
      },
      body: jsonEncode({
        'model': modelName,
        'messages': messages,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenRouter Failed [${response.statusCode}]: ${response.body}');
    }
  }

  Future<String> _callPerplexity(String prompt, String apiKey) async {
    final url = Uri.parse('https://api.perplexity.ai/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'sonar-pro',
        'messages': [
           {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Perplexity Failed [${response.statusCode}]: ${response.body}');
    }
  }

  AIResponse _parseResponse(String rawJson) {
     String jsonStr = rawJson.trim();
     
     // 1. Strip Markdown
     if (jsonStr.startsWith('```json')) {
       jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '');
     }
     
     // 2. Seek Brackets (The Fix for "Unexpected character")
     final start = jsonStr.indexOf('{');
     final end = jsonStr.lastIndexOf('}');
     
     if (start != -1 && end != -1 && end > start) {
       jsonStr = jsonStr.substring(start, end + 1);
     } else {
       // If absolutely no JSON found, fallback to treating it as a raw string message
       // This handles cases where AI refuses to speak JSON
       return AIResponse(
         response: rawJson, 
         actions: [],
         thoughtProcess: "Parsing Failed. Raw output returned."
       );
     }

     try {
       final Map<String, dynamic> data = jsonDecode(jsonStr);
       return AIResponse.fromJson(data);
     } catch (e) {
       print("JSON Parse Error: $e\nRaw: $rawJson");
       return AIResponse.error("HQ Transmission Garbled: $e");
     }
  }
}
