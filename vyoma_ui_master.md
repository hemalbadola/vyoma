# Vyoma — UI Master Reference Document
### Branch: `feat/protocol-engine` | Last sync: 2026-05-08

> **Purpose:** This document is the single source of truth for UI state, tutorial flow, dead code audit, and feature completeness tracking. Update it every sprint. The LLM (antigravity) handles system logic — this document tracks everything a human eye must not miss.

***

## 1. Complete Screen & Widget Inventory

### 1.1 Screens

| File | Route / Purpose | Status | Notes |
|---|---|---|---|
| `lib/ui/onboarding_screen.dart` | First-launch onboarding (23.9 KB) | ✅ Active | Multi-step; connects to profile setup |
| `lib/ui/home_screen.dart` | Main shell / tab host (8.3 KB) | ✅ Active | Houses 3 tabs via bottom nav |
| `lib/ui/screens/wakeup_screen.dart` | "Good morning" daily entry screen | ✅ Active | Temporal-aware greeting; must trigger ChronosService |
| `lib/ui/screens/profile_setup_screen.dart` | Name/year/goal capture post-onboard | ✅ Active | Must seed MemoryService on complete |
| `lib/ui/screens/settings_hub_screen.dart` | Settings root (7.4 KB) | ✅ Active | Routes to preferences, API key mgr |
| `lib/ui/screens/preferences_screen.dart` | Notification prefs, theme toggles | ✅ Active | Verify all switches actually persist |
| `lib/ui/screens/notifications_screen.dart` | Notification history (3.0 KB) | ⚠️ Thin | Only 3KB — likely a stub/placeholder |
| `lib/ui/screens/friends_hub_screen.dart` | Friends list, requests, search (20.4 KB) | ⚠️ Partial | Large file, but feature audit flagged incomplete |
| `lib/ui/screens/add_friend_screen.dart` | Add friend by username/UID (9.2 KB) | ✅ Active | Verify request → accepted flow fires correctly |
| `lib/ui/screens/memory_vault_screen.dart` | View/manage AI memory entries (13.5 KB) | ✅ Active | Must show trust level (user vs ai_inferred) |

### 1.2 Tabs (inside HomeScreen)

| File | Tab Label | Status | Notes |
|---|---|---|---|
| `lib/ui/tabs/mission_tab.dart` | Mission / War Room (44 KB) | ✅ Active | The core tab; contains PendingActionCard integration |
| `lib/ui/tabs/intel_tab.dart` | Intel / Analytics (34.5 KB) | ✅ Active | Metrics, focus stats, friend activity summary |
| `lib/ui/tabs/timetable_tab.dart` | Timetable (2.3 KB) | ⚠️ STUB | Only 2.3 KB — wraps `AnimatedTimetable` widget with no real screen logic |

### 1.3 Widgets

| File | Purpose | Status | Notes |
|---|---|---|---|
| `chat_sheet.dart` | Full chat UI with streaming (47.5 KB) | ✅ Active | Largest widget; contains message bubbles, input bar, streaming animation |
| `war_room_viewmodel.dart` | ViewModel for all War Room state (74.6 KB) | ✅ Active | Largest file in project — refactor candidate |
| `weekly_calendar_grid.dart` | Week-view calendar display (25.4 KB) | ✅ Active | Used inside mission_tab; verify timetable vs calendar merge |
| `vault_journal_view.dart` | Journal entry creation/view (32.5 KB) | ✅ Active | Large; verify AI insight extraction is wired |
| `pending_action_card.dart` | Visual card for AI-proposed actions (8.0 KB) | ✅ Active | **NEW** — critical Protocol Engine UI; verify approve/reject wiring |
| `glass_card.dart` | Design-system card primitive (2.2 KB) | ✅ Active | GlassCard v2 with VyomaColors; shimmer/press/glow variants |
| `command_dock.dart` | Slash command suggestion bar (10 KB) | ✅ Active | Verify slash commands match current intent list |
| `animated_timetable.dart` | Animated weekly timetable display (5.0 KB) | ✅ Active | Used by timetable_tab (which is a stub) |
| `background_mesh.dart` | Animated background mesh (2.2 KB) | ✅ Active | Decorative; verify performance on low-end devices |
| `debrief_card.dart` | Post-focus session debrief summary (2.9 KB) | ⚠️ Unclear | Small file; verify it's actually shown after focus ends |
| `api_key_manager.dart` | Dev/admin API key UI (7.9 KB) | ⚠️ DEV ONLY | Must be gated behind a debug/admin flag — never ship to prod users |
| `debug_seeder.dart` | Seeds fake data for testing (5.1 KB) | 🔴 DEV ONLY | Must be completely excluded from release builds |

### 1.4 Core / Services (lib/core — not audited in depth here)

| Known File | Purpose |
|---|---|
| `AIService` | Calls model, parses AIActionProposal JSON |
| `PolicyEngine` | Validates proposals before execution |
| `ExecutionEngine` | Executes approved actions |
| `AuditLogger` | Writes audit events per mutating action |
| `CalendarService` | Google Calendar OAuth + CRUD |
| `TimetableService` | Local timetable CRUD |
| `MemoryService` | Local memory read/write |
| `SupermemoryService` | Vector memory API calls |
| `ChronosService` | Temporal state analysis (session gap) |
| `FriendService` | Friend CRUD + request handling |
| `AccountabilityService` | Friend activity summary builder |
| `NotificationService` | Local push scheduling |
| `TelemetryService` | Cross-device activity matrix |
| `WeatherService` | Current weather context |
| `DeviceService` | Device info for context |
| `SessionManager` | Chat session persistence (added in hardening commit) |

***

## 2. Feature Completeness Tracker

Use this table every sprint. Mark status, owner, and what's missing.

### 2.1 Core Features

| Feature | UI Complete | Logic Complete | Wired Together | Tutorial Step | Gaps / TODO |
|---|---|---|---|---|---|
| War Room Chat | ✅ | ✅ | ✅ | Step 3 | Streaming works; verify pending action card dismisses cleanly after approval |
| Pending Action Card | ✅ | ✅ | ⚠️ Partial | Step 4 | Card exists; verify approve → ExecutionEngine → audit event → success toast flow end-to-end |
| Calendar Sync | ✅ | ✅ | ⚠️ Partial | Step 5 | OAuth refresh token expiry handled with graceful fallback but no re-auth prompt shown to user |
| Timetable Management | ⚠️ Stub screen | ✅ | ⚠️ Partial | Step 6 | `timetable_tab.dart` is 2.3KB — just wraps AnimatedTimetable. No CRUD UI. User cannot edit timetable from the tab; only via chat. Add inline edit capability. |
| Reminders / Notifications | ✅ | ✅ | ⚠️ Partial | Step 5 | `notifications_screen.dart` is 3KB stub — user has no way to view or manage existing reminders |
| Journal / Vault | ✅ | ✅ | ⚠️ Unclear | Step 7 | AI insight extraction from journal entries — verify this actually fires and is shown somewhere |
| Memory Vault View | ✅ | ✅ | ⚠️ Partial | Step 8 | Must display memory `source` tag (user-typed vs ai_inferred) and confidence score |
| Focus Timer / Debrief | ⚠️ Partial | ⚠️ Unclear | 🔴 Not confirmed | — | `debrief_card.dart` exists but no clear trigger; no visible focus timer UI found in tab/screen scan |
| Friends Hub | ✅ | ⚠️ Partial | ⚠️ Partial | Step 9 | Accept/decline flow exists; no real-time presence, no shared streaks, no activity feed shown per friend |
| Add Friend | ✅ | ✅ | ✅ | Step 9 | Verify deep link invite path |
| Intel / Analytics | ✅ | ✅ | ✅ | Step 10 | Metrics display working; friend activity summary injected into AI context |
| Wakeup Screen | ✅ | ✅ | ⚠️ Partial | Step 2 | Temporal-aware greeting — verify ChronosService gap detection feeds into this screen |
| Onboarding | ✅ | ✅ | ✅ | Steps 1–2 | 23.9KB; verify it seeds profile + memory before routing to home |
| Profile Setup | ✅ | ✅ | ✅ | Onboarding | Verify data lands in Firestore AND MemoryService |
| Command Dock | ✅ | ⚠️ Partial | ⚠️ Partial | Step 3 | Slash command list must be kept in sync with allowed `AIActionIntent` types in PolicyEngine |
| Glass Design System | ✅ | N/A | ✅ | — | GlassCard v2 with VyomaColors. Verify every screen uses tokens, no hardcoded hex values remain (audit referenced in commit `9273f3d`) |
| Story Mode Tutorial | ✅ | ✅ | ⚠️ Partial | All | Tutorial overlay exists (`feat(ui): add story-mode tutorial overlay`). See Section 4 for full tutorial spec and what's missing |

### 2.2 Dead Code / Remove Candidates

| File / Symbol | Reason | Action |
|---|---|---|
| `lib/ui/widgets/debug_seeder.dart` | Seeds fake data; no production use | **DELETE from release builds.** Gate behind `kDebugMode` or remove entirely before App Store submission |
| `lib/ui/widgets/api_key_manager.dart` | Admin UI for API keys | **Gate behind `kDebugMode` flag.** Should never be visible to end users |
| Any `DEBUG_TRACE:` debugPrint calls in WarRoomViewModel | Dev logging, adds noise, minor performance cost | Replace with structured `AuditLogger` calls or remove before release |
| `_isTimetableDeleteFollowUp` and similar regex chains | Brittle; superseded by PolicyEngine intent classification | Audit after protocol engine is fully wired; remove redundant guard logic |
| Old color constants / local hex values | Superseded by `VyomaColors` tokens (commit `9273f3d`) | Run a grep for raw hex values (`#[0-9a-fA-F]{6}`) in lib/ and replace all with token references |
| `.agent/` directory (deleted in stash pop) | Agent workflow files; not Flutter app code | Confirm deletion is intentional; add to `.gitignore` if needed |

***

## 3. UI Consistency Checklist

Run this against every screen before merging to main.

### 3.1 Token Compliance

- [ ] **No hardcoded hex colors.** Every color reference uses `VyomaColors.*`
- [ ] **No hardcoded font sizes.** Every text style uses `VyomaTextStyles.*`
- [ ] **No hardcoded spacing values.** Every padding/margin uses `VyomaSpacing.*`
- [ ] **GlassCard used for all card surfaces.** No raw `Container` with manual decoration acting as a card.

### 3.2 Interaction States

- [ ] Every button has a loading state (show spinner, disable tap while processing)
- [ ] Every button has an error state (inline error, not just a toast)
- [ ] Every list has an empty state (not just blank — a message + action)
- [ ] Every data-loading view shows a skeleton shimmer (not a spinner)
- [ ] Every destructive action (delete, clear) has a confirmation dialog with a clearly labeled "Destructive" button in red/error color

### 3.3 Screens with known UI gaps

| Screen | Gap | Fix |
|---|---|---|
| `timetable_tab.dart` | No CRUD UI — user cannot add/edit classes from the tab | Add inline "Add Class" FAB and swipe-to-edit on timetable rows |
| `notifications_screen.dart` | 3KB stub — no list, no dismiss, no history | Build notification list with dismiss and mark-all-read |
| `friends_hub_screen.dart` | No per-friend activity card, no real-time presence dot | Add presence indicator (green dot = active today) and last-active timestamp |
| All screens | No "History" button showing AuditLogger entries | Add an "Action History" accessible from Settings showing all AI-executed changes |
| `memory_vault_screen.dart` | Trust level and confidence not shown per memory | Add source badge: `YOU SAID` (user) vs `VYOMA INFERRED` (ai) with confidence bar |

***

## 4. Story Mode Tutorial — Full Specification

### 4.1 What exists

Commit `2b50c85` added the tutorial overlay (`feat(ui): add story-mode tutorial overlay with spotlight, arrows, darkening, skip`). The file is under `lib/tutorial/` (untracked in stash — confirm it's been committed to the branch).

### 4.2 Tutorial Philosophy

- The tutorial is a **story**, not a checklist. Vyoma speaks to the user in first-person: "This is your War Room."
- Every step **spotlights one real UI element** — darkens everything else, draws an animated arrow, shows a speech-bubble tooltip.
- The user can **Skip at any time** (persistent top-right button, never hidden).
- Users who skip can **replay the tutorial** from Settings → "How Vyoma Works".
- Tutorial state is stored as a simple boolean in Firestore + local preferences: `tutorialCompleted: true/false`. If false, tutorial starts on first home screen load.

### 4.3 Complete Tutorial Step Script

Each step has: `stepId`, target widget key, arrow direction, speech text, and action required to advance.

***

**STEP 0 — WELCOME (Full Screen, No Spotlight)**

> *Screen:* Full-screen modal before home loads.
> *Visual:* Vyoma logo pulses gently. Dark overlay. No arrow.
> *Speech:*
> "Welcome to your War Room, [Name].
> I'm Vyoma — your AI operator.
> Let me show you how we work together. Takes 90 seconds."
>
> *Buttons:* **"Let's go"** (advances) | **"Skip tutorial"** (exits, sets tutorialCompleted = true)

***

**STEP 1 — THE WAR ROOM TAB**

> *Target:* Mission tab icon in bottom nav bar
> *Arrow direction:* Down, pointing at tab icon
> *Speech:*
> "This is your Mission tab. Every day starts here. It's your command center."
>
> *Advance:* Tap anywhere on speech bubble OR tap the tab

***

**STEP 2 — THE WAKEUP GREETING**

> *Target:* Wakeup / greeting card at top of Mission tab
> *Arrow direction:* Down, pointing at card
> *Speech:*
> "Every morning I'll greet you here. If you've been away a while, I'll notice. I always know how long it's been."
>
> *Advance:* Tap to continue

***

**STEP 3 — THE CHAT BUTTON / COMMAND ENTRY**

> *Target:* Chat FAB or input bar at bottom of Mission tab
> *Arrow direction:* Up, pointing at input
> *Speech:*
> "Talk to me here. Tell me what you need — in plain English.
> 'Schedule my DSA lecture tomorrow at 2pm.'
> Try it."
>
> *Action required:* User types anything and sends. Tutorial advances on message sent.
> *Fallback after 10 seconds:* Show "or tap to skip this step" link.

***

**STEP 4 — THE PENDING ACTION CARD**

> *Target:* `PendingActionCard` widget (appears after AI proposes an action)
> *Arrow direction:* Down, pointing at card
> *Speech:*
> "Before I change anything in your calendar or timetable, I'll show you a card like this.
> I always ask first. You approve — then I act."
>
> *Advance:* Tap "Approve" on the card (if a real action was proposed in Step 3) OR tap tutorial bubble to continue with a demo card.

***

**STEP 5 — THE CALENDAR GRID**

> *Target:* `WeeklyCalendarGrid` in Mission tab
> *Arrow direction:* Down, pointing at grid
> *Speech:*
> "This is your live calendar — your actual Google Calendar, synced in real time.
> Tap any event to see details."
>
> *Advance:* Tap anywhere to continue

***

**STEP 6 — THE TIMETABLE TAB**

> *Target:* Timetable tab icon in bottom nav
> *Arrow direction:* Down, pointing at tab
> *Speech:*
> "Your recurring class schedule lives here — separate from one-time calendar events.
> Tell me your classes once, and I'll handle the rest."
>
> *Advance:* Tap to continue

***

**STEP 7 — THE VAULT (JOURNAL)**

> *Target:* Vault / Journal entry point (FAB or nav item)
> *Arrow direction:* Depends on layout
> *Speech:*
> "This is your Vault. Write here privately. I read it — not to judge, but to understand you better over time."
>
> *Advance:* Tap to continue

***

**STEP 8 — MEMORY VAULT**

> *Target:* Memory Vault accessible from settings or profile
> *Arrow direction:* Points at settings icon or memory item
> *Speech:*
> "I build a memory of you — your goals, your habits, what matters.
> You can see everything I've learned, edit it, or delete anything you don't want me to remember."
>
> *Advance:* Tap to continue

***

**STEP 9 — FRIENDS HUB**

> *Target:* Friends icon / route in Intel tab or side nav
> *Arrow direction:* Points at friends entry
> *Speech:*
> "Add your squad here. When your friends are active, I'll factor that into your sessions.
> Accountability works better when it's real."
>
> *Advance:* Tap to continue

***

**STEP 10 — INTEL TAB**

> *Target:* Intel tab icon in bottom nav
> *Arrow direction:* Down, pointing at tab
> *Speech:*
> "This is your Intel — focus minutes, sessions, streaks, and what your friends are doing.
> I use all of this to calibrate how I help you."
>
> *Advance:* Tap to continue

***

**STEP 11 — SLASH COMMANDS (COMMAND DOCK)**

> *Target:* Command dock (appears when user types `/`)
> *Arrow direction:* Up, pointing at dock
> *Speech:*
> "Type `/` anywhere to see power commands. `/focus start`, `/debrief`, `/pact` — shortcuts for your most important actions."
>
> *Advance:* Tap to continue. If user types `/focus start`, let them proceed — tutorial advances automatically.

***

**STEP 12 — TUTORIAL COMPLETE**

> *Screen:* Full-screen celebration (no spotlight). Single emerald pulse animation.
> *Speech:*
> "You're ready, [Name].
> Your War Room is set up. I'm on duty.
> One last thing: you can replay this anytime from Settings → 'How Vyoma Works'."
>
> *Button:* **"Enter the War Room"** → sets `tutorialCompleted = true`, routes to home.

***

### 4.4 Tutorial Implementation Checklist

| Task | Status | Notes |
|---|---|---|
| Tutorial overlay widget exists | ✅ Committed | `feat(ui): add story-mode tutorial overlay` (commit 2b50c85) |
| Spotlight + backdrop darkening | ✅ In commit | Verify dark overlay opacity is ~0.75, spotlight uses `ClipPath` or `CustomPainter` |
| Animated arrow | ✅ In commit | Arrow should gently bob (0.4s loop, 8px travel) |
| Skip button always visible | ⚠️ Verify | Must persist on ALL steps including welcome and celebration |
| Tutorial state persists across app restart | ⚠️ Verify | SharedPreferences `tutorialCompleted` key; Firestore sync for cross-device |
| "Replay tutorial" in Settings | 🔴 Not built | Add toggle in `preferences_screen.dart` that resets `tutorialCompleted = false` |
| Step 3 demo pending action card | 🔴 Not built | If user types a schedulable message, the real pending card appears. Otherwise, show a static demo card with dismiss button |
| Tutorial advances on widget interaction (Step 3, 4, 11) | ⚠️ Verify | Event-based advance, not just tap-anywhere |
| All step widget keys registered | 🔴 In progress | Every target widget must have a `GlobalKey` registered with the tutorial controller |
| Celebration animation on Step 12 | ⚠️ Partial | Emerald pulse exists via GlassCard glow; add a particle/confetti burst here |

***

### 4.5 Widget Key Registration (TODO list)

Every widget targeted by the tutorial needs a `GlobalKey`. Add these to the respective files:

```dart
// In home_screen.dart
static final GlobalKey missionTabKey = GlobalKey(debugLabel: 'tutorial_mission_tab');
static final GlobalKey intelTabKey   = GlobalKey(debugLabel: 'tutorial_intel_tab');
static final GlobalKey timetableTabKey = GlobalKey(debugLabel: 'tutorial_timetable_tab');

// In mission_tab.dart
static final GlobalKey wakeupCardKey   = GlobalKey(debugLabel: 'tutorial_wakeup_card');
static final GlobalKey chatInputKey    = GlobalKey(debugLabel: 'tutorial_chat_input');
static final GlobalKey calendarGridKey = GlobalKey(debugLabel: 'tutorial_calendar_grid');

// In chat_sheet.dart or war_room_viewmodel context
static final GlobalKey pendingActionCardKey = GlobalKey(debugLabel: 'tutorial_pending_action');

// In command_dock.dart
static final GlobalKey commandDockKey = GlobalKey(debugLabel: 'tutorial_command_dock');
```

***

## 5. Dead Code Audit — Full Results

### 5.1 Files to delete before release

| File | Reason |
|---|---|
| `lib/ui/widgets/debug_seeder.dart` | Seeds fake data; production crash risk if triggered accidentally |
| Any test/seed scripts in `lib/` root | Only test files belong in `test/` |

### 5.2 Files to gate behind `kDebugMode`

```dart
// In settings_hub_screen.dart — wrap API key manager route:
if (kDebugMode) ...[
  ListTile(
    title: const Text('API Key Manager'),
    onTap: () => Navigator.push(...),
  ),
],
```

Same pattern for any route to `debug_seeder.dart`.

### 5.3 Code patterns to clean up

| Pattern | Location | Fix |
|---|---|---|
| `debugPrint('DEBUG_TRACE: ...')` | `war_room_viewmodel.dart` (many instances) | Replace with `AuditLogger.trace()` or remove |
| Raw hex color values e.g. `Color(0xFF...)` | Any file not migrated to VyomaColors | Grep: `grep -rn "Color(0x" lib/` and replace |
| Regex-based intent heuristics (`_isTimetable*`, `_isCalendar*`) | `war_room_viewmodel.dart` | Audit which are now redundant post-PolicyEngine; mark with `// TODO(protocol): remove after v1 stabilizes` |
| `_pendingActionPlan` state that survives app kill | `war_room_viewmodel.dart` | Add clear-on-resume in `initState` / lifecycle listener |

***

## 6. Git Branch Status

| Branch | Last Commit | What's on it |
|---|---|---|
| `main` | `cc6c62c` (merge) | Protocol engine merged in; tutorial overlay merged in; GlassCard v2 merged in |
| `feat/protocol-engine` | `1757611` (resolve glass_card conflict) | All of main PLUS: VyomaColors token system, hardening deps, session manager, audit logger, dead code audit commit, theme unification |

**Next merge plan:**
1. Complete the tutorial `GlobalKey` registration across all target widgets
2. Build `notifications_screen.dart` properly (currently a stub)
3. Build `timetable_tab.dart` CRUD UI
4. Add "Replay Tutorial" toggle in `preferences_screen.dart`
5. Remove / gate all debug widgets behind `kDebugMode`
6. PR from `feat/protocol-engine` → `main` with full checklist sign-off

***

## 7. Per-Feature Tutorial Step Cross-Reference

Quick lookup: which tutorial step covers which feature, so you never ship a feature without a corresponding tutorial moment.

| Feature | Tutorial Step | Tutorial Status |
|---|---|---|
| War Room / Chat | Step 3 | ✅ Scripted |
| Pending Action Card | Step 4 | ✅ Scripted |
| Calendar Grid | Step 5 | ✅ Scripted |
| Timetable Tab | Step 6 | ✅ Scripted |
| Journal / Vault | Step 7 | ✅ Scripted |
| Memory Vault | Step 8 | ✅ Scripted |
| Friends Hub | Step 9 | ✅ Scripted |
| Intel / Analytics | Step 10 | ✅ Scripted |
| Command Dock (slash commands) | Step 11 | ✅ Scripted |
| Focus Timer | ❌ NO STEP | 🔴 Missing — add Step 11b when focus timer UI is built |
| Debrief Card | ❌ NO STEP | 🔴 Missing — add Step 11c when debrief trigger is confirmed |
| Action History (Audit Log) | ❌ NO STEP | 🔴 Missing — add Step 12b when history screen is built |
| Notifications Screen | ❌ NO STEP | 🔴 Missing — add after notifications screen is properly built |

***

## 8. Changelog (Sprint Log)

| Date | Commit(s) | What changed | Document section affected |
|---|---|---|---|
| 2026-05-08 | `2b50c85` | Story-mode tutorial overlay added | Section 4 |
| 2026-05-08 | `f31b567` | GlassCard v2 — shimmer, press, glow | Section 3.1, 2.1 |
| 2026-05-08 | `522abd6` | VyomaColors/VyomaTextStyles/VyomaSpacing token system | Section 3.1 |
| 2026-05-08 | `f33b102` | Theme unified to Glass/Spatial + Emerald | Section 3.1 |
| 2026-05-08 | `9273f3d` | All local color constants migrated to VyomaColors | Section 5.3 |
| 2026-05-08 | `5a1d380` | Deps pinned, .env removed, SessionManager, AuditLogger, dead code audit | Sections 2.2, 5 |
| 2026-05-08 | `c354da7` | PolicyEngine + ExecutionEngine wired into WarRoomViewModel | Section 2.1 |
| 2026-05-08 | `0d2b4ec` | Protocol engine wired into AIService — JSON-first, v1 system prompt | Section 2.1 |
| 2026-05-08 | `1757611` | Merge conflict resolved — GlassCard v2 wins | Section 1.3 |

***

*Document version: 1.0 | Next review: after timetable_tab CRUD and notifications_screen are built*