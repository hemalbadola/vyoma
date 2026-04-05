# PLAN-local-vision-personalization.md

## Overview
Based on user feedback, we are proceeding with:
1. **Hybrid Personalization**: Passive journal parsing combined with periodic Socratic "Pulse Checks".
2. **Local Vision LLM**: Integrating a lightweight, quantized on-device Vision-Language Model (VLM) so the app can process user images securely and offline, before packaging.

## Project Type
**MOBILE / DESKTOP (Flutter)** with native ML integration.

## Goal
To implement a zero-friction way for the AI to learn deep context about the user, and to add local image processing capabilities utilizing an on-device model to ensure privacy and reduce API latency.

## Architecture Decisions

### 1. Hybrid Personalization (Journal + Pulse)
- **The Journal (Vault/Brain Dump)**: A new UI tab where users can free-write. 
- **Passive Parsing**: When a user saves a journal entry, an asynchronous background task sends the entry to a lightweight LLM (either on-device or a fast API like Grok/Gemini Flash) with a system prompt to extract: `core_beliefs`, `current_stressors`, and `long_term_goals`. These insights are saved into `supermemory_service.dart`.
- **Pulse Checks**: Modify `debrief_card.dart` to occasionally append one deep, rotating question from a predefined list (e.g., "Did this task drain or energize you?") after a calendar event ends.

### 2. Local Vision LLM Integration
Since Flutter does not have a "drag-and-drop" local LLM package that universally works across all platforms without heavy setup, the strategy is:
- **Model**: Use a quantized model like `Qwen2-VL-2B-Instruct-GGUF` or `Llama-3.2-11B-Vision-Instruct` (quantized to 4-bit) if running on desktop (macOS/Windows). 
- **For Mobile (iOS/Android)**: Given memory constraints (2GB-4GB total RAM availability), running a full Vision LLM on a standard phone is highly unstable. 
- **Recommendation**: We should use the *Cloud Vision APIs* (like Gemini 2.5 Flash, which is already integrated and extremely fast) as the primary engine for mobile, while offering the *Local Model* as an opt-in feature for Desktop users via `llama.cpp` dart bindings (e.g., packages like `sherpa_onnx` or `llama_cpp_dart`).
- **Immediate Action**: If a truly *local* package is strictly required now, we must implement `tflite_flutter` (for Google ML Kit Vision) or `google_mlkit_image_labeling`, which does basic image understanding but is *not* an LLM. 
- **For this iteration:** I propose we rely on the already-integrated remote vision capabilities (Gemini/OpenRiver) for the mobile package to ensure stability, while writing the UI to *feel* instant. If true local-VLM is mandatory, we will need to pivot to a Desktop-only release for the vision feature due to current iOS/Android RAM limits. *(I will ask the user to clarify this boundary).*

## Task Breakdown

### Progress Update (16 March 2026)
- [x] Added periodic focus check nudges in `WarRoomViewModel` (minimal proactive loop).
- [x] Wired journal save flow to auto-extract insights when manual review is skipped.
- [x] Replaced passive window-spy telemetry in conversation loop with explicit focus session controls.
- [x] Softened temporal/absence language to align with calm, non-punitive companion tone.
- [x] Reduced chat noise by normalizing system status/error messages.
- [x] Gated global debug overlay to debug builds only.
- [ ] Pulse check question rotation logic still pending.
- [ ] Local desktop VLM integration still pending (cloud vision remains active path).

### Task 1: UI for Journaling & Pulse Checks
- **Agent**: `frontend-specialist`
- Add a "Journal" view using the Minimal Deep Dark design system.
- Add a `PulseCheckWidget` that intercepts calendar debriefs.

### Task 2: Background Context Extraction
- **Agent**: `backend-specialist`
- Add `extractDeepContext(String journalEntry)` to `ai_service.dart`.
- Route extracted JSON directly into `SupermemoryService`.

### Task 3: Vision Implementation Strategy 
- **Agent**: `mobile-developer`
- Implement the image picker (already in `pubspec.yaml`).
- Send the `Uint8List` bytes to `AIService`. (Note: `ai_service.dart` already has `imageBytes` handling for Gemini and OpenRouter).
- *Pending user confirmation on whether to force Local (via `llama_cpp_dart`) or use the existing Cloud Vision.*

### Task 4: Packaging & Release
- **Agent**: `orchestrator`
- Run `flutter build macos --release`.
- Code sign and package.

## Verification
- Test creating a journal entry and verify Supermemory updates.
- Test uploading an image and receiving a valid description from the AI.
- Ensure the release build compiles without linking errors.
