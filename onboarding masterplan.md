# Vyoma — Engineered Onboarding Flow
## Master Design Document v1.0

***

## What Is Wrong With the Current Flow

The current `onboarding_screen.dart` has five steps:

1. **Logo + one goal text field** — the only identity signal is a free-text "what do you want to do today" entry, which gets written to `MemoryService.updateProtocol()` as a goal. No name, no academic context, no year, no subjects.
2. **Wake/sleep time picker** — good signal, but stored without any explanation of why Vyoma needs it.
3. **"Show you around?"** — yes/no, routes to guided demo or skip.
4. **Guided demo** — tries to call `submitCommand()` and `previewJournalInsights()` live during onboarding. This is dangerous: it fires real AI calls with zero user context seeded yet.
5. **Handoff** — single button "Start Day." No confirmation of what was captured. No profile summary. No expectation-setting.

**Critical gaps:**
- No name captured → AI calls user "User" forever until they say their name in chat.
- No academic/professional context → AI has no idea what subjects, year, or role the user has.
- No explicit permission flow for Calendar, Notifications → users hit these later with zero context.
- No timetable mention → the most operationally important feature is never introduced.
- No friend/accountability mention → social layer is invisible.
- No persona seeding → `MemoryService.updateIdentity()` gets called with `('User', '')`.
- The guided demo fires live AI calls before profile is complete — the AI is answering with no memory context.
- Zero visual storytelling — it is a form with a dark background.

***

## Design Principles for the New Flow

1. **Conversational, not form-like.** Every question is asked by Vyoma as a message, not a form label.
2. **Atomic data collection.** One question per screen. No screen has more than one decision.
3. **AI context-first.** By the time the user reaches the main app, Vyoma's memory is fully seeded with identity, schedule type, subject area, wake/sleep, and first goal.
4. **Permission narrative.** Calendar and notification permissions are requested with an explanation that makes users *want* to grant them.
5. **Story mode tutorial.** After onboarding, the first session is a guided tour using spotlight overlays, screen dimming, animated arrows, and coach marks — not a separate screen, but overlaid on the real app.
6. **Skip-safe.** Every step has a "Skip for now" that stores a null/default and continues. Skipping is not penalised; Vyoma picks it up in conversation later.
7. **Zero live AI calls during onboarding.** All data is collected and stored; Vyoma's first real response is the first War Room greeting, which now has full context.

***

## The New Onboarding Flow

### Overview — 8 Steps + Post-Onboarding Story Tutorial

```
Step 0: ARRIVAL         — Full-screen logo + tagline. 2-second hold. No interaction.
Step 1: IDENTITY        — Name + what they are (student / professional / other)
Step 2: CONTEXT         — If student: year + field. If professional: role + domain.
Step 3: SUBJECTS        — Top 3 subjects / areas they want Vyoma to track.
Step 4: OPERATING WINDOW — Wake + sleep time. Explained as "when I'm allowed to ping you."
Step 5: TODAY'S MISSION — One concrete goal for today. (Moved here, after context is known.)
Step 6: PERMISSIONS     — Calendar + Notifications, with full narrative explanation.
Step 7: SOCIAL INTENT   — "Are you studying with anyone? Invite a friend or go solo."
Step 8: HANDOFF         — Profile summary card. "This is what I know. Let's begin."

POST-ONBOARDING: STORY MODE TUTORIAL
  — Overlay system on the real HomeScreen
  — 6 spotlight steps covering: War Room, Timetable, Intel, Vault, Friends, Focus
  — Skip available at any point
```

***

## Step-by-Step Specification

***

### STEP 0 — Arrival

**Purpose:** Brand moment. Set tone. No friction.

**Screen:**
- Pure black background.
- Vyoma logo (horizontal lockup SVG) fades in over 1.3s — keep existing `_LogoPulse`.
- Below the logo, after 1.8s delay, a single line types in character by character:
  > *"Your cognitive operator is ready."*
- After 3.5s total, auto-advances to Step 1. No button needed.

**What gets stored:** Nothing.

**Skip:** Not applicable (auto-advance).

***

### STEP 1 — Identity

**Purpose:** Capture name and broad category. Seeds `MemoryService.updateIdentity()`.

**Screen:**
- Vyoma prompt (existing `_VyomaPrompt` style):
  > *"Let's start with the basics. What should I call you?"*
- Single text field. Placeholder: `Your first name`
- On submit, immediately a second question appears (animated slide-in):
  > *"And what are you?"*
- Three tappable chips (not a dropdown):
  - 🎓 **Student**
  - 💼 **Professional**
  - 🔀 **Something else**

**What gets stored:**
```dart
await memory.updateIdentity(name, category); 
// category: "student" | "professional" | "other"
```

**Skip:** Name defaults to `"You"`. Category defaults to `"other"`.

***

### STEP 2 — Context (Conditional)

**Purpose:** If student: capture year and field. If professional: capture role and domain.

**Screen (Student path):**
- Vyoma prompt:
  > *"Which year are you in, {name}?"*
- Horizontal scroll chips: `1st Year`, `2nd Year`, `3rd Year`, `4th Year`, `Postgrad`, `PhD`
- After year selected, second question slides in:
  > *"What are you studying?"*
- Text field: `e.g. Computer Science, Commerce, Design`

**Screen (Professional path):**
- Vyoma prompt:
  > *"What's your role, {name}?"*
- Text field: `e.g. Founder, Engineer, Designer`
- Second question:
  > *"What industry or domain?"*
- Text field: `e.g. SaaS, Healthcare, Finance`

**Screen (Other path):**
- Vyoma prompt:
  > *"What does your day mostly revolve around?"*
- Text field with examples: `e.g. Research, Content, Training, Freelance`

**What gets stored:**
```dart
await memory.updateIdentity(name, '$category — $year $field');
```

**Skip:** Stores `"$category — not specified"`.

***

### STEP 3 — Subjects / Focus Areas

**Purpose:** Give Vyoma the 2–3 domains it will actively track, reference in scheduling, and prompt about.

**Screen:**
- Vyoma prompt:
  > *"What are the 2–3 things you most want to stay on top of?"*
- Dynamic chip builder: user types a subject, hits Enter or taps +, chip appears. Up to 3 chips.
- Pre-populated suggestions appear below as tappable chips based on Step 2 context:
  - Student (CS): `Algorithms`, `DBMS`, `OS`, `Math`, `Projects`
  - Professional (Engineer): `System Design`, `Code Review`, `Docs`, `Meetings`
- Small helper text under the chips:
  > *"Vyoma will reference these when scheduling and checking in."*

**What gets stored:**
```dart
await memory.updateSubjects(subjects); // List<String>, max 3
// New method needed in MemoryService
```

**Skip:** Stores `[]`. Vyoma will ask in first chat session.

***

### STEP 4 — Operating Window

**Purpose:** Wake/sleep times. Reframe it from "routine question" to "permission to exist in your schedule."

**Screen:**
- Vyoma prompt:
  > *"When are you active? I'll only plan and ping you inside this window."*
- Two `_TimeTile` pickers (keep existing component — it is good).
- Below the tiles, a small note in muted color:
  > *"No notifications before {wake} or after {sleep}. Ever."*

**What gets stored:**
```dart
await memory.updateRoutine(wake, sleep);
```

**Skip:** Defaults to `07:00 – 23:00`.

***

### STEP 5 — Today's Mission

**Purpose:** Seed the first goal. Now meaningful because Vyoma knows who you are.

**Screen:**
- Vyoma prompt (now personalised):
  > *"What's one thing you actually want to finish today, {name}?"*
- Text field. Placeholder: `One concrete outcome — not a wish, a result`
- Helper text:
  > *"This becomes your anchor. Vyoma will check back on it."*

**What gets stored:**
```dart
await memory.updateProtocol(goal, 'Not started');
```

**Skip:** Stores `"No mission set"`. Vyoma will ask at first session.

***

### STEP 6 — Permissions

**Purpose:** Request Calendar + Notification permissions with narrative framing so the user understands the *why* before the OS dialog appears.

**Screen:**
- Two permission cards, stacked vertically. Each card has:
  - Icon (calendar / bell)
  - Title
  - Two-line explanation
  - A `Grant Access` button
  - Status indicator (grey → green tick on grant)

**Card 1 — Calendar:**
> **Calendar Access**
> *Vyoma reads your events to plan around them and writes new ones when you ask. Nothing is touched without your confirmation.*
> `Connect Google Calendar`

**Card 2 — Notifications:**
> **Focus Reminders**
> *Vyoma checks in every 2 hours when you're working. You can silence it anytime — but it's how the accountability loop works.*
> `Allow Notifications`

- Continue button is active even if both are denied (graceful degradation).
- Status: if both denied, show a small muted note:
  > *"You can connect these later in Settings. Some features will be limited."*

**What gets stored:**
```dart
await prefs.setBool('calendar_permission_granted', granted);
await prefs.setBool('notification_permission_granted', granted);
```

***

### STEP 7 — Social Intent

**Purpose:** Introduce the friend/accountability layer without forcing it. Plant the seed.

**Screen:**
- Vyoma prompt:
  > *"Are you doing this with anyone — a study group, a friend, a team?"*
- Three options as tappable cards:
  - 👥 **Invite a friend** → opens share sheet with a referral-style invite link
  - 🔍 **Find by username** → short text field to search by Vyoma handle
  - ⚡ **Just me for now** → continues immediately

- Small note at bottom:
  > *"Friends see your focus activity — not your schedule or notes. You control what's visible."*

**What gets stored:**
```dart
await prefs.setBool('social_intent_complete', true);
await prefs.setString('social_mode', 'solo' | 'inviting' | 'searching');
```

**Skip:** Equivalent to "Just me for now."

***

### STEP 8 — Handoff

**Purpose:** Show the user what Vyoma now knows. Build trust. Make it feel like a real briefing.

**Screen:**
- Header: `"Here's your profile, {name}."`
- A dark card — `color: Color(0xFF111317)` — with a summary:

```
IDENTITY     {name} · {year} {field}
SUBJECTS     {subject1}, {subject2}, {subject3}
ACTIVE       {wake} → {sleep}
MISSION      {today's goal}
CALENDAR     Connected ✓ / Not connected
FRIENDS      1 invited / Solo
```

- Below the card:
  > *"I'll update this as I learn more. Nothing here is permanent."*

- Two buttons:
  - `Begin` (primary, green) → triggers story tutorial
  - `Skip tutorial` (ghost) → goes directly to HomeScreen, marks `tutorial_complete = true`

**What gets stored:**
```dart
await prefs.setBool('onboarding_complete', true);
```

***

## Post-Onboarding: Story Mode Tutorial

This is not a separate screen. It is an overlay system that runs on top of the real `HomeScreen` and its tabs.

### Architecture

```dart
class TutorialOverlay extends StatefulWidget {
  // Sits above HomeScreen in the widget tree
  // Controlled by TutorialController
}

class TutorialController extends ChangeNotifier {
  int currentStep = 0;
  bool isActive = true;
  
  final List<TutorialStep> steps = [...]; // 6 steps
  
  void advance() { ... }
  void skip() { isActive = false; notifyListeners(); }
}

class TutorialStep {
  final GlobalKey targetKey;      // Key on the widget to spotlight
  final String title;
  final String body;
  final TutorialArrowDirection arrowDirection;
  final Offset tooltipOffset;
}
```

### The 6 Tutorial Steps

Every step:
- **Darkens the entire screen** to `Colors.black.withOpacity(0.72)`
- **Cuts a hole** (using CustomPainter with `BlendMode.clear`) around the target widget, revealing it in full brightness
- **Shows a tooltip card** positioned near the target with an animated arrow pointing to it
- **Arrow** is an animated SVG that bounces once every 2 seconds
- **Dismiss**: tap anywhere outside tooltip → advances to next step
- **Skip all**: always available top-right

***

**STEP T1 — War Room**
- Target: The chat input bar at the bottom of the War Room tab
- Arrow direction: `DOWN` (pointing at the input)
- Title: `"This is Mission Control"`
- Body: `"Type anything here — schedule a class, set a reminder, ask what's next. Vyoma understands plain language."`
- Action hint: `"Try typing something — or tap anywhere to continue"`

***

**STEP T2 — Timetable**
- Target: Timetable tab icon in bottom nav bar
- Arrow direction: `DOWN`
- Title: `"Your Weekly Grid"`
- Body: `"Add your fixed classes here. Vyoma will plan around them automatically and never schedule over them."`
- Action hint: `"Tap anywhere to continue"`

***

**STEP T3 — Intel Tab**
- Target: Intel/Stats tab icon
- Arrow direction: `DOWN`
- Title: `"Your Pattern Map"`
- Body: `"Focus minutes, task completion, drift patterns. This starts empty — it gets honest over time."`

***

**STEP T4 — Vault**
- Target: Vault/Journal tab icon
- Arrow direction: `DOWN`
- Title: `"The Vault"`
- Body: `"Write anything here — thoughts, reflections, stress. Vyoma extracts insights from your entries and never shows them to anyone."`

***

**STEP T5 — Friends**
- Target: Friends tab icon
- Arrow direction: `DOWN`
- Title: `"Your Crew"`
- Body: `"When friends are active, Vyoma tells you. It won't show their notes or schedule — just whether they're moving or not."`

***

**STEP T6 — Focus Button / Check-in**
- Target: Focus start button or prominent CTA in War Room
- Arrow direction: `UP` (pointing upward at the button from the tooltip below)
- Title: `"The most important button"`
- Body: `"Start a focus session here. Vyoma checks in every 2 hours to see if you're still on mission."`
- Final action: `"You're ready. Tap to close."` — tapping this dismisses tutorial completely and stores `tutorial_complete = true`.

***

## Data Model — What Gets Stored by End of Onboarding

| Key | Type | Source Step | Storage |
|-----|------|-------------|---------|
| `user_name` | String | Step 1 | MemoryService.updateIdentity |
| `user_category` | String | Step 1 | MemoryService.updateIdentity |
| `user_year` | String | Step 2 | MemoryService.updateIdentity |
| `user_field` | String | Step 2 | MemoryService.updateIdentity |
| `user_subjects` | List<String> | Step 3 | MemoryService.updateSubjects (new) |
| `wake_time` | String (HH:mm) | Step 4 | MemoryService.updateRoutine |
| `sleep_time` | String (HH:mm) | Step 4 | MemoryService.updateRoutine |
| `today_goal` | String | Step 5 | MemoryService.updateProtocol |
| `calendar_permission_granted` | bool | Step 6 | SharedPreferences |
| `notification_permission_granted` | bool | Step 6 | SharedPreferences |
| `social_mode` | String | Step 7 | SharedPreferences |
| `onboarding_complete` | bool | Step 8 | SharedPreferences |
| `tutorial_complete` | bool | Post-T6 | SharedPreferences |

***

## Changes Required in `MemoryService`

The current `MemoryService` has:
- `updateProtocol(goal, nextAction)`
- `updateRoutine(wake, sleep)`
- `updateIdentity(name, description)`

**New method needed:**
```dart
Future<void> updateSubjects(List<String> subjects) async {
  // Store to local memory + sync to Supermemory
  // Key: 'user_subjects'
}
```

**Update signature needed:**
```dart
// Current:
Future<void> updateIdentity(String name, String description)

// Needs to also accept:
Future<void> updateIdentity(String name, String description, {
  String? category,   // "student" | "professional" | "other"
  String? year,       // "3rd Year"
  String? field,      // "Computer Science"
})
```

***

## `_OnboardingSeed` — Expanded Data Model

Replace the current 4-field struct with:

```dart
class OnboardingSeed {
  final String name;
  final String category;       // student | professional | other
  final String year;           // 3rd Year, Postgrad, etc.
  final String field;          // Computer Science, etc.
  final List<String> subjects; // max 3
  final String wake;
  final String sleep;
  final String goal;
  final bool calendarGranted;
  final bool notificationGranted;
  final String socialMode;     // solo | inviting | searching

  // ...copyWith, constructor
}
```

***

## UI Components Needed (New)

| Component | Purpose | Reuses Existing? |
|-----------|---------|-----------------|
| `_ChipSelector` | Horizontal scroll of tappable label chips | No — new |
| `_DynamicChipBuilder` | User types + adds up to 3 chips | No — new |
| `_PermissionCard` | Icon + title + description + grant button + status | No — new |
| `_SocialIntentCard` | Three-option card row (invite/search/solo) | No — new |
| `_ProfileSummaryCard` | Dark card showing all collected data | No — new |
| `TutorialOverlay` | Full-screen dimmer + spotlight hole + tooltip | No — new |
| `TutorialTooltip` | Card with title, body, arrow, skip | No — new |
| `SpotlightPainter` | CustomPainter with BlendMode.clear hole | No — new |
| `AnimatedArrow` | Bouncing SVG arrow pointing at target | No — new |

Existing components kept as-is:
- `_LogoPulse` ✓
- `_VyomaPrompt` ✓
- `_PrimaryButton` ✓
- `_SecondaryButton` ✓
- `_TimeTile` ✓
- `_VyomaLogo` ✓
- `_OnboardingStepHead` ✓

***

## Navigation Architecture

Current: `MaterialPageRoute` push per step — creates a back-stack that lets users hit Android back button mid-onboarding and go back to blank states.

**Fix:** Use a single `OnboardingController` with a `PageView` or indexed state machine. The back button during onboarding goes to the previous onboarding step, not to the auth screen.

```dart
class OnboardingController extends ChangeNotifier {
  int _step = 0;
  OnboardingSeed _seed = OnboardingSeed.empty();

  int get step => _step;
  OnboardingSeed get seed => _seed;

  void next(OnboardingSeed updated) {
    _seed = updated;
    _step++;
    notifyListeners();
  }

  void back() {
    if (_step > 0) {
      _step--;
      notifyListeners();
    }
  }
}
```

This makes the full flow a single `Scaffold` with an `IndexedStack` or animated `PageView`. No back-stack pollution.

***

## Skip Behaviour Summary

| Step | Skip Label | Default Value Stored |
|------|-----------|----------------------|
| 1 | "Skip" | name = "You", category = "other" |
| 2 | "Skip" | year = "", field = "" |
| 3 | "Skip" | subjects = [] |
| 4 | "Skip" | wake = 07:00, sleep = 23:00 |
| 5 | "Skip" | goal = "No mission set" |
| 6 | "Skip for now" | both permissions = false |
| 7 | "Just me for now" | socialMode = "solo" |
| 8 | "Skip tutorial" | tutorial_complete = true |

***

## Vyoma's First Message (Post-Onboarding)

When the user lands in the War Room for the first time, Vyoma's opening message is now generated with full context:

```
Good {morning/afternoon/evening}, {name}.

You're a {year} {field} student. Your active window is {wake}–{sleep}.
Your subjects: {subjects}.

Today's mission: {goal}.

I'm ready. What do you want to do?
```

This is the payoff of the entire onboarding flow — Vyoma greets you by name, knows your context, references your mission. This is the "I didn't know this could be a thing" moment.

***

## Story Tutorial — `SpotlightPainter` Implementation Reference

```dart
class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;
  final Color overlayColor;

  SpotlightPainter({
    required this.targetRect,
    this.borderRadius = 12,
    this.overlayColor = const Color(0xB8000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, Radius.circular(borderRadius)),
      clearPaint,
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter old) =>
      old.targetRect != targetRect;
}
```

The overlay widget wraps `HomeScreen` and uses `GlobalKey.currentContext?.findRenderObject()` to locate each target widget's bounding box dynamically, so the spotlight follows the real layout regardless of screen size.

***

## What This Onboarding Achieves

By the time a user hits "Begin":

1. Vyoma knows their **name, year, field, and subjects** — enough to make every AI response feel personalised.
2. Vyoma knows their **active window** — no pings at 2am.
3. Vyoma has their **mission for today** — the AI's first check-in has an anchor.
4. **Calendar and notifications** are granted with understanding, not ambush.
5. The **social layer** is introduced with zero pressure.
6. The **story tutorial** teaches the app by showing the real app — not a fake demo screen.
7. The AI's **first message is already personalised** — the "wow" moment happens in the first 5 seconds of the main app.