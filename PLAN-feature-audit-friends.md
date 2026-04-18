# PLAN-feature-audit-friends.md

Date: 2026-04-08

## Goal
Audit current Vyoma features, rate product readiness, define concrete improvements, and decide whether a Friends feature can run without backend support.

## Current Feature Scorecard
Scale: 1 (weak) to 10 (strong)

| Feature | User Value | Reliability | UX Polish | Build Readiness | Notes |
|---|---:|---:|---:|---:|---|
| AI Companion Chat (multi-provider) | 9 | 7 | 8 | 8 | Strong core differentiator; parser and model fallback already in place. |
| Google Calendar Integration | 9 | 7 | 7 | 8 | High value; OAuth/config sensitivity remains the main operational risk. |
| Mission Dashboard + Focus Metrics | 8 | 8 | 8 | 8 | Good daily workflow anchor; solid foundation for engagement loops. |
| Memory System (short + vector) | 8 | 7 | 7 | 7 | Powerful but advanced behavior can be surfaced more clearly in UI. |
| Timetable Management | 7 | 7 | 7 | 7 | Useful for student workflow; could benefit from friend-shared timetable views later. |
| Notifications / Proactive Nudges | 7 | 7 | 6 | 7 | Works as support system; can be tuned for relevance and timing quality. |
| Multi-session Chat History | 7 | 8 | 7 | 8 | Good operational continuity; room to improve search and session labels. |
| Key/Diagnostics Surfaces | 6 | 8 | 6 | 8 | Useful for dev workflows, less relevant for end-user mode. |

## Improvement Implemented In This Pass
1. AI action parser now routes by payload type before attempting fallback.
2. XML `<actions>` payloads no longer trigger expected JSON parse error noise.
3. Result: cleaner debug output and more reliable signal when real parse failures happen.

## Improvement Backlog (Prioritized)
### Must
- Add command/search for past sessions and memories.
- Improve calendar error states with explicit user action guidance.
- Add richer parser test coverage for mixed/edge action payloads.

### Should
- Add mission quick actions for common intents (focus start, add task, schedule block).
- Add confidence/trace panel for AI actions before execution.
- Improve notification relevance scoring (time + context + current focus).

### Could
- Add streak and accountability overlays in Intel tab.
- Add weekly review summary card powered by existing memory/activity logs.

## Friends Feature: Backend Decision

### Can current build support it without backend?
Only in a very limited way.

What works without backend:
- Local-only friend placeholders on one device.
- Manual export/import of accountability snapshots.
- Sharing via external channels (copy text, image, links).

What does NOT work without backend:
- Real friend graph (invite/accept/block).
- Cross-device shared goals/tasks/comments.
- Live status/presence and push updates.
- Secure access control and revocation.

Conclusion:
- For a real Friends feature, backend is required.

## Recommended Friends MVP Architecture

### Fastest practical path
- Use managed backend first: Firebase Auth + Firestore + FCM.
- Keep current Flutter app as client.
- Add service abstraction so backend can later be swapped to custom API.

### Data model (MVP)
- users
- friendships (pending, accepted, blocked)
- shared_goals
- shared_checkins
- shared_tasks
- reactions_or_comments

### Core flows
1. Send friend invite
2. Accept/decline invite
3. Share goal/check-in
4. Friend reacts or comments
5. Optional daily accountability ping

### Security baseline
- Auth required for all reads/writes.
- Users can only mutate their own profile and their side of friendships.
- Shared documents readable only by accepted friend pair.

## Delivery Phases
1. Phase 1: Friend graph + invites + basic profile
2. Phase 2: Shared goals and check-ins
3. Phase 3: Shared task accountability + notifications
4. Phase 4: Advanced social features (leaderboards/co-op focus rooms)

## Agent/Skill Recommendation
- Best agent for implementation: backend-specialist (API/data), mobile-developer (Flutter integration), test-engineer (acceptance coverage).
- Best skills: api-patterns, mobile-design, testing-patterns, clean-code.
