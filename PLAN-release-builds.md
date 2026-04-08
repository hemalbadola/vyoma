# PLAN-release-builds.md

## Overview
This plan tracks cross-platform release artifacts for Vyoma and the exact process to generate Android and Windows outputs.

## Why This File
This is the best-suited Markdown location for release engineering work because the repository already uses top-level PLAN-*.md files for operational tasks.

## Current State (8 Apr 2026)
- Android release APK created successfully.
- Local Windows build is not possible on macOS hosts.
- Windows build is configured through GitHub Actions in .github/workflows/release.yml.

## Android Build
- Command: flutter build apk --release
- Output: build/app/outputs/flutter-apk/app-release.apk
- Versioned copy: build/app/outputs/flutter-apk/vyoma-alpha-v1.6.apk

## Windows Build Strategy
### Local Constraint
Flutter supports flutter build windows only on Windows hosts.

### CI Build (Recommended)
Use GitHub Actions workflow: Build and Release

Workflow dispatch target options:
- all
- windows
- macos

Recommended command from a machine with GitHub CLI auth:

```bash
gh workflow run release.yml --ref main -f target=windows
```

Check latest run:

```bash
gh run list --workflow release.yml --limit 5
```

Download Windows artifact after a successful run:

```bash
gh run download <run_id> -n vira-build-windows -D build/windows-ci
```

Expected artifact contents path:
- build/windows/x64/runner/Release

## Notes
- Workflow fail-fast is disabled so one platform failure does not cancel the other.
- If Windows build fails, inspect the Windows job logs first before rerunning.
