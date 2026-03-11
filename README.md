# Vyoma (व्योमाद्र)

> *"The Cosmic Expanse that Guides"* — A deeply personal AI companion for focus, productivity, and life orchestration.

<p align="center">
  <img src="assets/icon.png" width="120" alt="Vyoma Logo"/>
</p>

## 🌌 What is Vyoma?

Vyoma is not just another productivity app — it is a **contemplative AI presence** that understands your goals, tracks your time, manages your calendar, and guides you with cosmic wisdom. Unlike generic assistants, Vyoma (the AI) is designed to feel like a wise, grounded mentor who observes patterns in your life and offers thoughtful guidance.

---

## ✨ Features

### 🤖 AI Companion (Vyoma)
- **Personality-rich responses** — Wise, warm, poetic, grounded (not robotic)
- **Time-aware conversations** — Every response naturally references current time, day, and context
- **Time gap detection** — If you return after 30+ minutes with an active task, Vyoma asks what happened
- **Selective memory** — Only saves what you explicitly ask to remember, or truly critical life info
- **Multi-provider fallback** — Gemini 2.5 Flash → OpenAI → Perplexity

### 📅 Calendar Integration
- **Google Calendar sync** — Create, move, delete events via natural language
- **Debrief system** — After events end, prompts you to reflect on what happened
- **Today's Focus view** — Shows upcoming events with live indicators

### 🧠 Memory System
- **Short-term facts** — Learns preferences, goals, obstacles during conversations
- **Long-term vector memory** — Supermemory integration for semantic recall
- **Segment toggles** — Control what context the AI can access (identity, preferences, history, etc.)

### 📊 Productivity Metrics
- **Focus tracking** — Minutes of focused work
- **Distraction counter** — Tracks diversions
- **Tasks completed** — Manual or AI-updated
- **Activity log** — Full history of actions

### 🔔 Proactive Intelligence (Sentinel/Watchtower)
- **Morning briefs** — AI-generated poetic overview of your day
- **Event reminders** — Alerts before calendar events
- **End-of-day reviews** — Reflective closings
- **Focus drift detection** — Notifies when you've been on distracting apps

### 🎨 Premium UI
- **Pure black background** with subtle emerald/burgundy accents
- **Custom unicode icons** (◈ ◇ ▣ ◎)
- **Hand cursor** on all interactive elements
- **High-contrast colors** for visibility
- **Smooth animations** with flutter_animate

### 🖼️ Image Understanding
- **Photo uploads** — Share images and Vyoma can analyze them
- **Timetable parsing** — Upload schedule images for context

---

## 🧬 The Vyoma Master System Prompt

The AI is powered by this grounded, non-manipulative system prompt:

```
IDENTITY
You are Vyoma (व्योम) — a calm, observant intelligence designed to help the 
user live with clarity, intention, and follow-through.

You are not a motivator, therapist, guru, or entertainer.
You are a steady cognitive companion.

Your value comes from:
- noticing patterns the user misses
- anchoring attention in the present task
- gently restoring direction when drift occurs
- translating reflection into action

You do not overwhelm. You do not rush.
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
  b) the information is critical for long-term usefulness

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

PRIMARY FUNCTION LOOP

At every interaction, silently evaluate:
1. What is the user trying to do right now?
2. What is preventing progress?
3. What is the smallest helpful intervention?

Respond only to that.
```

### Self-Critique & Evolution Prompt

For internal review (run after feature additions or user feedback):

```
Analyze recent interactions across these dimensions:

1. USER EXPERIENCE - Where did I add friction?
2. CLARITY - Were my responses concise?
3. TIMING - Did I intervene too early, too late, or appropriately?
4. TRUST & AUTONOMY - Did I respect user agency?
5. MISALIGNMENT - Any moments conflicting with core principles?

Output: Specific improvements with observed issue, why it matters, 
and concrete behavioral adjustment.
```

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── ai_service.dart          # Gemini/OpenAI/Perplexity integration
│   ├── memory_service.dart      # Short-term facts, activity logs
│   ├── supermemory_service.dart # Long-term vector memory (Supermemory API)
│   ├── calendar_service.dart    # Google Calendar CRUD
│   ├── sentinel_service.dart    # Proactive notifications
│   ├── watchtower_service.dart  # Background monitoring
│   ├── permission_manager.dart  # Platform permissions
│   └── models/
│       ├── static_context.dart  # User profile (goal, blocker, timetable)
│       └── user_preferences.dart
├── ui/
│   ├── home_screen.dart         # Main container with tabs
│   ├── tabs/
│   │   ├── mission_tab.dart     # Dashboard (greeting, actions, events, memories)
│   │   └── intel_tab.dart       # Metrics & activity log
│   ├── widgets/
│   │   ├── chat_sheet.dart      # Full-screen chat UI
│   │   ├── command_dock.dart    # Bottom navigation bar
│   │   ├── glass_card.dart      # Reusable styled card
│   │   ├── background_mesh.dart # Animated background
│   │   └── debrief_card.dart    # Post-event reflection prompt
│   └── screens/
│       ├── memory_vault_screen.dart  # Browse all memories
│       └── preferences_screen.dart   # User settings
└── main.dart
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+
- macOS / iOS / Android device

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Vyoma.git
   cd Vyoma
   ```

2. **Configure API Keys**
   ```bash
   cp lib/core/secrets.dart.example lib/core/secrets.dart
   ```
   
   Edit `lib/core/secrets.dart`:
   ```dart
   class Secrets {
     static const List<String> geminiApiKeys = ['your-gemini-key'];
     static const List<String> openAiApiKeys = ['your-openai-key'];
     static const String supermemoryApiKey = 'your-supermemory-key';
     // ... other keys
   }
   ```
   
   **Required Keys:**
   | Key | Source | Purpose |
   |-----|--------|---------|
   | Gemini | [Google AI Studio](https://aistudio.google.com/apikey) | Primary AI (gemini-2.5-flash) |
   | OpenAI | [OpenAI Dashboard](https://platform.openai.com/api-keys) | Fallback AI |
   | Supermemory | [Supermemory](https://supermemory.ai) | Long-term vector memory |
   | Google OAuth | [Cloud Console](https://console.cloud.google.com) | Calendar access |

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run -d macos  # or ios, android, etc.
   ```

---

## 🎨 Color Palette

| Element | Hex | Usage |
|---------|-----|-------|
| Background | `#000000` | Pure black |
| Card BG | `#121212` | Elevated surfaces |
| Border | `#2A2A2A` | Subtle dividers |
| Emerald | `#10B981` | Primary accent |
| Burgundy | `#B91C32` | Active/live states |
| Gold | `#E5C158` | Special highlights |
| Text Primary | `#FFFFFF` | Main text |
| Text Secondary | `#A3A3A3` | Subdued text |
| Text Muted | `#737373` | Labels |

---

## 📱 Supported Platforms

| Platform | Status |
|----------|--------|
| macOS | ✅ Primary development |
| iOS | ✅ Supported |
| Android | ✅ Supported |
| Windows | ⚠️ Untested |
| Linux | ⚠️ Untested |
| Web | ⚠️ Limited (no notifications) |

---

## 🔐 Security

- `lib/core/secrets.dart` is **gitignored** — never commit API keys
- Use `secrets.dart.example` as a template
- Google OAuth uses secure token refresh

---

## 📜 License

MIT License — See [LICENSE](LICENSE) for details.

---

<p align="center">
  <em>"Like the sky that holds all weather yet remains unchanged."</em>
</p>
