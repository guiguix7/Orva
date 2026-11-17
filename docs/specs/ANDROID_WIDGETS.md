# Feature Specification — Android Home-Screen Widgets

Status: IMPLEMENTED / PARTIALLY VALIDATED. Eight providers and the Flutter snapshot pipeline exist; emulator smoke passed and the Today widget was validated with real populated data (task completed in-app, widget refreshed to "1 de 1 tarefas") on 2026-11-17, shipped in v2.1.0. Resize, reboot, lock-mode and populated states for the other seven widgets still need acceptance evidence.

Priority: P1 — Urgent.

## 1. Goal

Show useful Orva information on the Android launcher without opening the app. Android first. Keep Flutter-side snapshot contracts portable for future iOS support.

## 2. First-release scope

Build one reliable widget before variants.

### Orva Today (MVP)
Display:
- date/day and last refresh indication;
- completed / eligible mission count;
- daily focus or most important task, if configured;
- next scheduled activity and start time, if available;
- concise daily progress summary.

Never show journal/note text, sensitive habit values, health/weight, finance, or private comparison traits.

### Later variants
- Orva Agenda: next two or three time blocks.
- Orva Progress: safe consistency/current-level/progress summary.
- Compact and expanded sizes.

## 3. Architecture

- Drift/SQLite in Flutter remains authoritative.
- Flutter computes a small sanitized snapshot through repositories/domain calculations.
- Flutter writes it through a platform integration layer. Candidate bridge: home_widget, after checking its current package/API/platform support.
- Native Android widget code renders the snapshot; it does not open Drift or duplicate business logic.
- Platform adapter owns native update requests, intents, and lifecycle.
- Snapshot DTOs must not depend on Android UI classes.

Conceptual snapshot:

~~~json
{
  "schemaVersion": 1,
  "generatedAt": "ISO-8601 timestamp",
  "localDate": "YYYY-MM-DD",
  "completedMissionCount": 0,
  "eligibleMissionCount": 0,
  "nextActivityTitle": "Safe short label",
  "nextActivityStart": "HH:mm",
  "dailyFocusLabel": "Safe short label",
  "isStale": false
}
~~~

This is conceptual, not production data. Version and validate the snapshot.

## 4. Update triggers

Refresh after app launch/database readiness, mission/checklist completion/correction, daily-focus changes, routine/obligation changes, execution completion, date rollover when active, and explicit/native refresh callbacks.

Respect Android background scheduling limits. A periodic worker may refresh cached data but cannot assume the Flutter UI process is alive.

## 5. Interactions

MVP tap opens the relevant screen using a validated deep link/route.

Later actions (for example, complete a mission) must:
1. carry a stable record ID;
2. route through an explicit app-side action;
3. validate current state in the repository;
4. execute through the same domain command as app UI;
5. refresh snapshot after success;
6. be idempotent under repeated taps.

Native widget code must never bypass domain validation or write SQLite.

## 6. Privacy and lock behavior

Widgets may be visible on a locked device. Show only safe, non-sensitive content. Exclude journal/note text, health/weight, finance, private behavior/vice details, and comparison traits. If app lock is enabled, show generic safe state until the authentication policy explicitly permits more. Do not store secrets/tokens in widget snapshots. Let users disable widgets or hide content.

## 7. Failure/stale states

Handle database not ready, missing/corrupt/outdated snapshot, app force-stop, reboot, resize/reconfigure, lock state, update while process unavailable, and source deletion before action. Show a safe fallback and last-updated indicator. Do not present stale values as current.

## 8. Accessibility and UI

Support compact/medium/expanded sizes, readable text under launcher scaling, contrast, adequate touch targets, semantics, light/dark where supported, and concise pt-BR copy. Do not rely on color alone.

## 9. Package/platform verification

Before choosing a bridge, verify current pub.dev version, Flutter/Dart constraints, Android setup, iOS implications, license, maintenance, and native API. Candidate: home_widget. Native rendering may use Android App Widgets, Jetpack Glance, or supported RemoteViews integrations. Keep package-specific code out of domain logic.

## 10. Acceptance criteria

1. Widget can be added on supported Android launcher.
2. Today widget renders valid empty and populated states.
3. Relevant app writes request refresh.
4. Snapshot is validated/versioned.
5. Tap opens correct destination.
6. App restart/reboot preserve safe state and honest staleness.
7. Resize does not overflow.
8. No prohibited private data appears, including while locked.
9. Widget action cannot double-complete or double-reward.
10. Android build and emulator/device tests pass.
11. Flutter-side data contract remains reusable for iOS.

## 11. Implementation notes (2026-11-16)

- Eight widgets ship: Orva Hoje, Orva Tarefas, Orva Progresso, Orva Beto vs Alfredo, Orva Metas, Orva Hábitos, Orva Estudos and Orva Agenda (4×2 or 4×4).
- Transport is a project-owned `MethodChannel` (`com.appguilherme.orva/widgets`) plus app-private `SharedPreferences`; no third-party widget package and no direct SQLite access from native code.
- `lib/core/domain/widget_snapshot.dart` builds a versioned, bounded snapshot from Home/comparison/habit/study/goal projections. Notes, journal, finance, health and habit quantities are never included.
- When the app lock is on, Flutter publishes a content-free protected snapshot; every layout shows a generic locked state.
- Refresh runs on database readiness, app resume/pause and a 10-minute foreground timer. Providers show an honest "Atualizado …" label and mark snapshots older than 12 hours as outdated.
- Native tap intents carry a validated route (`today`, `tasks`, `progress`, `comparison`, `goals`, `habits`, `study`, `agenda`); Flutter opens the matching destination after unlock. Task completion and other writes remain app-only.
- Validation evidence: `flutter build apk --debug` passes; emulator API 37 registered all eight providers, wrote the snapshot, listed all widgets in the picker and rendered Orva Hoje on the launcher. See `screenshots/widgets-qa/`.

## 12. MVP exclusions

No arbitrary routine editing from launcher, no direct SQLite access from widget, no cloud push, no iOS widgets, and no sensitive comparison/health/vice/finance summaries.
