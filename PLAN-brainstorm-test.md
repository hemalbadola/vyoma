# 🧠 Brainstorm: Deepening AI Knowledge of the User

## Context
Vyoma needs to know the user better to act as a deeply personal AI companion. Currently, it uses a mix of static context (goals, blockers), active session logs, and Supermemory (vector search). We need a structured way to gather more personal context without being intrusive or creating friction, allowing the AI to offer more tailored, profound guidance.

---

### Option A: The "Introspective Onboarding" (Socratic Interview)
Instead of forms, Vyoma conducts a conversational interview specifically designed to map the user's psychology, core values, fears, and long-term vision.

✅ **Pros:**
- Feels natural and aligned with a "cosmic guide" persona.
- Highly engaging; people enjoy talking about themselves.
- Can be paused and resumed seamlessly.

❌ **Cons:**
- Takes time; user must be willing to engage in deep conversation.
- Requires complex prompt engineering to ensure Vyoma asks the *right* sequential questions.

📊 **Effort:** Medium

---

### Option B: "Passive Context Parsing" (Journaling/Brain-dump Integration)
Introduce a "Journal" or "Brain Dump" feature where the user can freely vent, write thoughts, or log daily reflections. Vyoma silently parses these entries in the background, extracting core beliefs, recurring themes, and stressors via an LLM, storing them in a structured knowledge graph/vector DB.

✅ **Pros:**
- Zero friction for the user; they just use the app to vent.
- Yields the most authentic, unstructured insights into the user's mind.
- Leverages the existing Supermemory integration efficiently.

❌ **Cons:**
- Requires the user to actually use the journaling feature.
- Parsing unstructured data into actionable insights can be technically complex.

📊 **Effort:** High

---

### Option C: Periodic "Pulse Checks" & Micro-Reflections
Instead of a long interview, Vyoma asks one deep, reflective question at strategic times (e.g., during the "End of Day Review" or right after a long focus session). Examples: *"What drained your energy most today?"* or *"Was this task aligned with your main goal?"*

✅ **Pros:**
- Low commitment; easy for the user to answer in 1-2 sentences.
- Builds the user profile iteratively over time.
- Highly contextual; asks about things that *just* happened.

❌ **Cons:**
- Takes weeks or months to build a comprehensive profile.
- Could become annoying if prompted too frequently.

📊 **Effort:** Low

---

## 💡 Recommendation

**Option B (Passive Context Parsing) combined with Option C (Pulse Checks)** is the most profound approach. 

By allowing the user to brain-dump naturally (Option B), Vyoma learns their purest thoughts. Supplementing this by adding single, contextual questions to the existing debriefs (Option C) ensures the profile grows without feeling like an interrogation.

What direction would you like to explore?

---

# 🧪 Testing Strategy: Finding Deep Bugs

Currently, there are no automated tests (`test` directory is empty/missing `_test.dart` files). To make the app release-ready, we must implement a rigorous testing protocol.

### Test Plan
| Test Category | Focus Area | Method |
|-----------|------|----------|
| **Unit Tests** | `ai_service.dart`, `memory_service.dart` | Validate JSON parsing, key rotation, and context injection. Ensure fallback logic works when a provider fails (e.g., simulating 429 errors). |
| **Integration Tests** | Calendar sync, Task tracking | Verify the state updates correctly when a task is completed or an event is pulled. |
| **Edge Cases** | Empty context, Network loss | How does Vyoma respond if Supermemory fails, or if offline? |
| **E2E / UI Tests** | `chat_sheet.dart`, `home_screen.dart` | Verify layout doesn't break on small screens, and animations (150-300ms) execute without jank. |

### Immediate Next Steps for Testing:
1. Create `test/ai_service_test.dart` to mock and test the fallback mechanism (Gemini -> OpenAI -> Nvidia -> Grok).
2. Create `test/memory_service_test.dart` to ensure segment toggles and contextual string replacements work flawlessly.
3. Run `flutter test` to validate the core business logic.

*Note: Automated tests will verify the logic, but manual "dogfooding" (using the app intensely for a day) is the only way to find UX flow bugs.*
