# PLAN-vyoma-ui-ux.md

## Overview
The goal is to maximize the UI elements of the Vyoma app, decide on optimal placement for maximum engagement, align with the AI companion ethos, and finally package the application for different target platforms (macOS, iOS, Android).

## UI/UX Deep Thought Strategy & Placement
Based on the `ui-ux-pro-max` design system analysis combined with Vyoma's core philosophy ("a deeply personal AI companion for focus"), here is the layout strategy:

### 1. The Core Canvas (Dark & Minimal)
- **Background**: Stick strictly to Pure Black (`#000000`) to let the interface disappear and the content breathe. 
- **Typography**: Google's `Inter` font for functional readability, combined with large, elegant styling for the AI conversational outputs.

### 2. Layout Mapping
- **The "Command Dock" (Bottom)**: 
  - Elevate from standard sticky nav to a **floating Action Island** (glassmorphism effect) slightly raised from the bottom edge (`bottom-6`).
  - Contains strictly necessary paths: `Mission (Dashboard)`, `Vault (Memory)`, `Intel (Metrics)`.
  
- **Home/Mission Screen (Center Stage)**:
  - **Top Area**: A poetic context header (e.g., "Good Evening. Focus drift is quiet.")
  - **Middle Canvas**: Currently active tasks and live calendar, cleanly separated using minimal borders (`#2A2A2A`) and subtle `Emerald (#10B981)` task markers.
  - **Micro-interactions**: Subtle hover states and smooth scale-ins (using `flutter_animate`) for completed tasks to reinforce a sense of grounded progress without flashy, cheap dopamine.

- **The AI Chat Interface (Slide-Up Sheet or Dedicated View)**:
  - Avoid making it look like a generic ChatGPT clone. The AI inputs shouldn't look isolated; they should hover above the content context.
  - User messages align right as soft gray text. Vyoma's replies are prominent and edge-to-edge with the custom unicode markers (◈ ◇).

### 3. Enhancing the Visual Quality (Pro-Max Guidelines)
- Use Lucide or Heroicons strictly. No emojis.
- Enforce `cursor-pointer` (Hand Cursor) on all interactive elements across Desktop/Web platforms.
- Contrast thresholds: `Text Primary (#FFFFFF)` for AI thoughts, `Text Secondary (#A3A3A3)` for user inputs, `Text Muted (#737373)` for timestamps.
- **Feedback**: A 150ms-300ms fade transition for all actionable buttons (Gold `#E5C158` for critical CTA, otherwise subtle border highlights).

## Implementation Breakdown

### Phase 1: UI Refinement (Flutter)
- [ ] Refactor `home_screen.dart` and `command_dock.dart` to use floating glassmorphism techniques.
- [ ] Polish animations in `chat_sheet.dart` ensuring smooth entry/exit.
- [ ] Audit all icon usages across the app and replace any clunky ones with crisp vectorized alternatives.

### Phase 2: Platform Packaging & Release Prep
- [ ] **macOS Package**:
  - Tweak `macos/Runner/Info.plist` for permissions (network, microphone if needed).
  - Run `flutter build macos --release`.
- [ ] **Android APK/AAB**:
  - Set app icon and version code in `android/app/build.gradle`.
  - Run `flutter build apk --release`.
- [ ] **iOS Archive** (requires Xcode & Mac):
  - Ensure provisioning profiles are set.
  - Run `flutter build ios --release`.

## Verification
- All buttons must have hover states (Desktop) and touch feedback (Mobile).
- Ensure no layout shift occurs during data loading.
- Verify release artifacts exist in `build/` directories.
