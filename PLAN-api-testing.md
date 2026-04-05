# PLAN-api-testing.md

## Overview
The goal is to test both the existing API keys (Gemini, OpenAI, Cerebras, A4F, Perplexity, OpenRouter) and integrate/test the newly provided Nvidia and Grok API keys to ensure they are fully functional. This involves verifying the keys via external scripts and preparing them for usage within the Flutter application.

## Project Type
**MOBILE / WEB (Flutter)** with local test scripts.

## Success Criteria
- Existing Python test scripts are updated to test all APIs.
- New Python script(s) or integrations are created for Nvidia and Grok APIs.
- A final report is produced detailing working vs. non-working keys for all providers.
- `lib/core/secrets.dart` is correctly updated securely with the new Nvidia and Grok keys (pending user confirmation).

## Tech Stack
- **Flutter/Dart**: Client-side codebase.
- **Python**: For lightweight HTTP testing of API keys.

## File Structure
- `lib/core/secrets.dart`
- `./test_keys.py` (and similar scripts in root)

## Task Breakdown

### Task 1: Setup Grok and Nvidia Testing Scripts
- **Agent**: `backend-specialist`
- **Skills**: `python-patterns`, `testing-patterns`
- **INPUT**: Nvidia and Grok API keys.
- **OUTPUT**: Python test scripts for Grok and Nvidia.
- **VERIFY**: Run scripts and verify they return HTTP 200.

### Task 2: Validate Existing APIs
- **Agent**: `backend-specialist`
- **INPUT**: `lib/core/secrets.dart` existing keys.
- **OUTPUT**: Terminal execution of existing tests filtering out any rate-limited or disabled keys.
- **VERIFY**: All 200 OK responses or a clear report indicating failures.

### Task 3: Update secrets.dart
- **Agent**: `mobile-developer`
- **Skills**: `mobile-design`
- **INPUT**: Verified Grok and Nvidia API Keys.
- **OUTPUT**: Updated `lib/core/secrets.dart`.
- **VERIFY**: Run `dart analyze` to ensure no syntax errors.

## Phase X: Verification
- [ ] Run newly created Python scripts successfully.
- [ ] Run existing Python scripts successfully for status report.
- [ ] Lint & Type Check: `flutter analyze`
