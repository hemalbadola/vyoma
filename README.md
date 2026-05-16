<p align="center">
  <img src="assets/images/vyoma_small_icon.png" width="96" alt="Vyoma"/>
</p>

<h1 align="center">Vyoma</h1>

<p align="center">
  <strong>व्योम · the part of you that notices</strong>
</p>

<p align="center">
  A time-aware cognitive companion for students and anyone doing serious daily work.<br/>
  Flutter · macOS · iOS · Android
</p>

---

## What Vyoma is

Vyoma is not a chatbot with a calendar attached. It is a **quiet intelligence** that lives inside your real day: your classes, your deadlines, your journal, and the people you study with.

The name comes from Sanskrit **व्योम** (vyoma): sky, ether, open space. The product tries to feel like that: room to think, not more noise.

At its center are three commitments:

1. **One thing today.** The Today screen is built around a single daily intention. Until you name it, the screen is the question. Everything else (next class, suggestions, debriefs) supports that wedge, not the other way around.

2. **Who you are becoming.** A persistent identity anchor and optional long-arc tools (Dharma Map chapters, anti-goals, vows) keep Vyoma pointed at direction, not just tasks.

3. **Notice without performing.** The AI is instructed to be the part of you that **notices**: when you go quiet mid-task, when you dodge the real work, when your next event is thirty minutes away. It speaks in short, plain sentences. It does not cheerlead, guilt-trip, or pretend certainty.

Vyoma reads your Google Calendar and semester timetable, remembers what you choose to save, and **never changes your schedule until you approve** a pending action card. That trust model is part of the product, not a safety afterthought.

---

## What Vyoma is not

- Not a therapist, guru, or motivational speaker.
- Not a replacement for your calendar app. It works **with** Google Calendar; you stay in control.
- Not surveillance. Memory segments and the vault are visible and toggleable. Background ticks on mobile use **local templates only**, not live model calls.
- Not a finished “life operating system.” The deepest ideas (practice modules, squad accountability, bindu pauses) orbit a core loop: **Today → chat → vault → schedule → circle**.

---

## The core loop

```
Name one thing → live the day → reflect in the vault → plan in chat → repeat
```

**Today** opens on restraint: one thing, your becoming line, optional memory braid (a past journal line surfaced because it relates to today’s intent), next class, smart nudges, post-event debrief cards.

**Chat** (center of the dock) is the Mission Console: streaming dialogue, images (e.g. timetable photos), slash commands, and structured proposals you approve or deny before anything hits your calendar.

**Vault** is private writing: one-line or full entries, streak, tags, optional analyze-and-commit insight review.

**Schedule** holds your recurring timetable and weekly calendar view.

**Progress** shows focus minutes, journal streak, weekly charts, squad comparison, and pattern hints.

**Circle** is friends, accountability, and optional shared visibility (tasks, online pulse, intention), all gated by privacy toggles in settings.

Long-press the center control for a **Bindu Moment**: a short breath ritual that can save a tagged micro-entry to the vault.

---

## Story Mode

After onboarding, first-time users get **Story Mode**: a guided tour over the real app, not a separate slideshow.

- A dimmed overlay spotlights actual UI (chat input, nav tabs, key surfaces).
- Copy is spoken as orientation: where to talk, where your week lives, where to write, where your circle is.
- Skip anytime; completion is stored per account.
- Six steps today (chat → Today → Schedule → Circle → Vault → try a prompt). A longer scripted tour exists in internal docs; the shipped tour is intentionally shorter.

Replay from settings when you want a refresher.

---

## First launch

Eight onboarding steps seed Vyoma before the first real reply:

Arrival → name and role (student / professional / other) → academic or work context → subjects → wake/sleep window (“when I may ping you”) → today’s mission → calendar connect and notification permission (real system dialog on mobile) → social intent (solo or with others) → profile summary → home.

No live AI calls during onboarding. The first conversation in chat runs with identity, schedule context, and goals already in memory.

---

## AI behavior (Mission Console)

Every turn carries **temporal context**: current time, time since you last wrote, active focus intent, next calendar event, and a light behavior fingerprint from recent sessions.

The system persona (in `TemporalContextBuilder.buildVyomaPersonaBlock()`) reinforces:

- Short replies unless you ask for depth.
- One quiet acknowledgment if you return after a long gap mid-task, without interrogation.
- Softer tone late at night; minimal tone early morning.
- Reorientation toward your stated task when you drift, in one sentence, not a lecture.

Models: Gemini primary; optional NIM / Grok fallbacks when keys are configured. Optional **Supermemory** for semantic recall when the supermemory segment is enabled.

---

## Memory and journal

- **On-device memory** (`memory.json`): facts, protocol (goals/blockers), preferences, journal entries, segment toggles.
- **Memory braid**: when today’s one thing is set, Vyoma can surface an older journal line that resonates with that intent. The journal talks back; it is not a dead log.
- **Vault tab**: write, streak, auto-tags, optional extraction review before insights are committed.
- **Memory vault screen** (settings): inspect and toggle which segments the AI may use (identity, facts, preferences, history, protocol, supermemory).

Pending post-event debriefs expire after 24 hours so memory does not fill with stale rows.

---

## Calendar, tasks, and background (mobile)

**Signed in:** tasks sync to Firestore; a per-user prefs mirror lets background work read the correct task list even when Firebase Auth is unavailable in an isolate.

**Calendar:** Google OAuth; create, move, and delete events through chat only after you approve.

**Background (Android / iOS only):**

| Component | Role |
|-----------|------|
| Workmanager (~15 min) | Periodic tick in a separate isolate |
| Sentinel | Deadline nudges from local task data |
| Watchtower | Post-class / post-event debrief prompts (templates) |
| Ambient notification | Ongoing line rebuilt from prefs (focus, active task, next event) |

Desktop does not register periodic background work. Notifications depend on OS settings on macOS.

---

## Practice (settings)

Optional layers for long-arc work. Maturity varies; all support the same ethos (clarity, agency, honesty):

| Module | Intent |
|--------|--------|
| Dharma Map | Three-month chapters of direction |
| Anti-goals | What you refuse to become |
| Witness | Vows witnessed by someone in your circle |
| Mirror | Structured reflection sessions |
| Shadow | Pattern hints on Progress |
| Bindu Moment | Breath + micro-journal |

---

## Interface

Warm void black (`#0D0D0B`), gold accent (`#D4AF72`), **Cormorant Garamond** for display text. Components include `VyCard`, `VyMark`, `GlassCard`, `CommandDock`, and the tutorial overlay.

App display name: **Vyoma** on all platforms.

---

## Architecture

```
lib/
├── core/           # AI, memory, calendar, tasks, notifications, background
├── ui/             # home, war_room_viewmodel, tabs, chat_sheet, onboarding
├── features/       # identity, dharma, witness, bindu, progress, …
└── tutorial/       # Story Mode
```

**State:** Provider and `ChangeNotifier` services.  
**Auth:** Firebase Auth + Google Sign-In.  
**Data:** Firestore for profile and tasks; local prefs and `memory.json` for fast start and background reads.

---

## Getting started

**Prerequisites:** Flutter 3.10+ (SDK `^3.10.3`), Xcode and/or Android SDK, Google Cloud OAuth for Calendar and Sign-In.

```bash
git clone https://github.com/hemalbadola/vyoma.git
cd vyoma
flutter pub get
flutter run -d macos    # or ios, android
```

**Local API keys** (never commit): `.env.local` or `--dart-define` for `VYOMA_GEMINI_API_KEYS`, optional NIM/Grok/Supermemory, and OAuth client IDs. Release builds should use a **backend proxy** for LLM calls; client keys are not shipped in production.

```bash
dart run flutter_launcher_icons
```

Icons are generated from `assets/images/vyoma_small_icon.png`.

---

## Platforms

| Platform | Status |
|----------|--------|
| macOS | Primary development target |
| iOS | Supported |
| Android | Supported (background worker, notification permission flow) |
| Web | Limited (no background worker / notifications) |
| Windows / Linux | Untested |

**Version:** 1.11.2+8 (`pubspec.yaml`)

---

## Security

- `lib/core/secrets.dart` is gitignored; use `secrets.dart.example`.
- Sign-out clears Google session via `AuthManager`.
- Background task reads use `vyoma_last_known_uid` in prefs, not `FirebaseAuth` in isolates.

---

## License

MIT. See [LICENSE](LICENSE).

---

<p align="center">
  <em>Like the sky that holds all weather yet remains unchanged.</em><br/>
  <sub>व्योम · ether · the space in which everything else happens</sub>
</p>
