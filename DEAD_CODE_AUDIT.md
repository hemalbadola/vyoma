# Dead Code Audit

Scope audited: service-layer files in `lib/core/*service.dart` (project currently has no legacy `lib/services/` service files besides newly added managers).

## Requested checks

- `TelemetryService.getCrossDeviceMatrix()`
  - Callers found: `lib/ui/war_room_viewmodel.dart`, `lib/core/background_agent.dart`, plus telemetry views in settings/preferences screens.
  - Status: active (not dead).

- `WeatherService.getWeather()`
  - Caller found: `lib/ui/war_room_viewmodel.dart`.
  - Status: active; currently used for AI context enrichment, not directly rendered in UI.

- `DeviceService`
  - `getDeviceStatus()` caller found: `lib/ui/war_room_viewmodel.dart`.
  - Status: active (single entry point in use).

- `AccountabilityService.buildFriendActivitySummary()`
  - Caller found: `lib/ui/war_room_viewmodel.dart`.
  - Status: active; no external callers beyond WarRoomViewModel.

- `ChronosService.analyzeTemporalState()`
  - Callers found: `lib/ui/war_room_viewmodel.dart`, `ChronosService.getTemporalContext()`.
  - Status: active; not sole entry point because `getTemporalContext()` also invokes it.

## Dead annotations added

- `lib/services/session_manager.dart`
  - `getStorageStats()` has no current callers.
  - Annotated in code with `// DEAD: no callers found` (kept for upcoming diagnostics UI).
