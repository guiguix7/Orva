# Orva — Verified Repository Snapshot

Audit baseline: main at commit 3b131ac, dated 2026-11-17, plus the uncommitted Home Dashboard V2 work described below. This is a snapshot, not a guarantee that main has not changed. Re-check HEAD before implementation.

## 1. Confirmed repository facts

- Flutter / Dart application.
- Riverpod for state/dependency access.
- Drift over SQLite for local persistence.
- Drift schema version observed: 6 (v6 added `comparison_profiles`, `comparison_traits`, `comparison_checkins`).
- Main shell tabs: Hoje, Checklists, Metas, Mais.
- Database/repositories: lib/core/database/.
- Pure domain calculations: lib/core/domain/.
- Feature UI: lib/features/.
- CI: .github/workflows/flutter-validation.yml.
- CI executes dependency resolution, formatting, static analysis, Flutter tests, and Android debug APK build.
- Actions workflow pins Flutter 3.50.0 and the Android project uses AGP 9.1.1. The last observed CI run for the pre-fix HEAD failed the Android debug APK step; after the AGP/workflow fixes, local `flutter build apk --debug` succeeded on 2026-11-17. A new CI run has not been observed, so CI is not yet proven green. This is not physical-device evidence.
- README describes local-first/offline behavior, local SQLite, explicit JSON backup export/import, no required account, and no telemetry in the audited configuration.
- Privacy documentation says SQLite is not encrypted at rest. Do not claim otherwise.

## 2. Existing feature surfaces observed

| Area | Evidence | Interpretation |
|---|---|---|
| Home | lib/features/home/home_page.dart, home_widgets.dart, lib/core/domain/home_overview.dart, lib/core/domain/home_dashboard.dart | Command center: planned vs executed time with a 24h ribbon, day-allocation donut chart, live/next activity, compact timeline with now marker, checklist and obligation priorities, weekly hobbies with session counts and targets, rolling 7-day habit consistency, goals, study evidence, Beto-vs-Alfredo coverage and a rolling seven-day activity chart. Executions, study sessions and hobby sessions are separate sources; executions linked to study/hobby reference types are excluded from the chart total. Summary sections can be hidden through the local `home_hidden_sections` setting. Pure dashboard and overview calculations have unit tests; widget tests cover 390/430/768/1440, dark, empty, large-text and preference states; browser QA evidence in screenshots/home-qa/. |
| Checklists | lib/features/checklists/ and repository | Existing checklist/occurrence system; investigate reuse before creating missions. |
| Goals | lib/features/goals/goals_page.dart | CRUD/status/history; inspected editor uses manual progress. |
| Calendar | lib/features/calendar/, calendar_repository.dart, lib/core/domain/calendar_layout.dart | Day timeline, week and month views over routine blocks, obligations, meal plans and executions. Block editor and weekly templates live in lib/features/routine/routine_editor.dart. |
| Obligations | lib/core/database/obligations_repository.dart | Recurrence, date exceptions, occurrences, overnight-aware blocks. |
| Studies | lib/features/studies/study_page.dart and study_repository.dart | Subject/topic/session/review/summary methods exist; completeness requires re-audit. |
| Nutrition | lib/features/nutrition/nutrition_page.dart and nutrition_repository.dart | Food catalogue, meal plans, actual consumption, nutrition summaries, planned meal blocks. |
| Habits | lib/features/habits/habits_page.dart and habits_repository.dart | Quantitative habits and date logs. |
| Executions | lib/features/executions/executions_page.dart | Timer, pause/resume, discard/finish, manual execution. |
| Hobbies | lib/features/hobbies/ | Hobby records and sessions. |
| Notes / journal | lib/features/notes/ and lib/features/journal/ | Local notes and date-based journal. |
| Countdown | lib/features/countdowns/ | Countdown surface. |
| Alter egos | lib/features/comparison/, comparison_repository.dart, lib/core/domain/comparison_scoring.dart | Beto vs Alfredo MVP: editable traits, manual check-ins, habit/study-derived evidence, weighted score with coverage. Live projection, no snapshots yet. |
| Android widgets | android/app/src/main/kotlin/com/appguilherme/orva/widgets/, android/app/src/main/res/layout/orva_widget_*.xml, lib/core/domain/widget_snapshot.dart, lib/core/platform/widget_bridge.dart, lib/core/platform/widget_sync.dart | Eight launcher widgets: Hoje, Tarefas, Progresso, Beto vs Alfredo, Metas, Hábitos, Estudos and Agenda. Flutter publishes a versioned, sanitized snapshot through a MethodChannel; native RemoteViews only render it and deep-link into the app. Protected snapshot when app lock is on. Emulator smoke passed; Today populated/refresh validated 2026-11-17 (v2.1.0); resize/reboot/lock and populated states for the other widgets pending. |
| Profile | lib/features/profile/ | Local profile/body records; sensitive. |
| Security | lib/features/security/ and lib/core/security/ | PIN/biometric code exists; this is not database encryption. |
| Developer console | lib/features/settings/developer_console_page.dart | Debug diagnostics; review sanitization before adding logs. |

## 3. Gaps observed in the audited tree

- The day/week/month calendar now exists. Drag-and-drop move/resize and immutable history are still missing.
- Goal progress in inspected editor is manual; complete aggregation from linked records was not established.
- Android widgets are smoke-validated on an emulator and the Today widget was validated with populated data on 2026-11-17: completing a task in-app refreshed the widget to "1 de 1 tarefas" in v2.1.0. Resize, reboot, lock-mode rendering and populated states/tap destinations for the other seven widgets still need acceptance evidence.
- Beto/Alfredo comparison exists as a v1 MVP (queries + UI + tests). Missing: immutable closed-period history, per-trait evidence history view, and any XP/analytics coupling.
- A complete manual + record-derived recurring mission domain was not established. Existing checklists may be reusable but semantics must be reviewed.
- No complete XP/level/achievement/prestige system was found.
- The Home now has a tested rolling seven-day activity chart and life-area summaries. Historical analytics beyond that, category-distribution charts and period comparison remain incomplete and need metric definitions.
- Home dashboard section visibility is persisted locally; ordering is fixed and there is no generic dashboard builder.
- Ollama, vice tracking, workout tracking, and finance tracking were not found implemented.
- No physical Android-device test evidence was established by this audit.

## 4. Documentation discrepancy

The older docs/MASTER_PROMPT_REQUIREMENTS.md described schema version 3 and marked study/nutrition as not started, while inspected code reports schema version 5 and contains the corresponding feature pages/repositories. The old matrix is superseded.

## 5. Required re-audit before work

1. Read current HEAD and branch.
2. Re-read pubspec.yaml and pubspec.lock.
3. Inspect AppDatabase.schemaVersion and full migration strategy.
4. Inspect relevant repositories, providers, pages, and tests.
5. Inspect recent changes and latest CI.
6. Update this document only after verifying facts against code.

## 6. Status vocabulary

- SPECIFIED / NOT IMPLEMENTED: intended behavior exists only in docs.
- PARTIALLY IMPLEMENTED: some behavior exists, but requirements are incomplete.
- IMPLEMENTED / NOT VALIDATED: code exists, required validation is pending.
- IMPLEMENTED / VALIDATED: acceptance checks have evidence.
- BLOCKED: external configuration, platform access, or product decisions prevent completion.

A file existing is not proof of a working feature. CI is not proof of every native lifecycle or device behavior.
