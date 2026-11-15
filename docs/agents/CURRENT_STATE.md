# Orva — Verified Repository Snapshot

Audit baseline: main at commit a93c629fc481734db580f3d9e0fbe575779051e5, dated 2026-10-30. This is a snapshot, not a guarantee that main has not changed. Re-check HEAD before implementation.

## 1. Confirmed repository facts

- Flutter / Dart application.
- Riverpod for state/dependency access.
- Drift over SQLite for local persistence.
- Drift schema version observed: 5.
- Main shell tabs: Hoje, Checklists, Metas, Mais.
- Database/repositories: lib/core/database/.
- Pure domain calculations: lib/core/domain/.
- Feature UI: lib/features/.
- CI: .github/workflows/flutter-validation.yml.
- CI executes dependency resolution, formatting, static analysis, Flutter tests, and Android debug APK build.
- Most recent Actions run observed for the audited HEAD: success, run 45, 2026-10-30. This is not physical-device evidence.
- README describes local-first/offline behavior, local SQLite, explicit JSON backup export/import, no required account, and no telemetry in the audited configuration.
- Privacy documentation says SQLite is not encrypted at rest. Do not claim otherwise.

## 2. Existing feature surfaces observed

| Area | Evidence | Interpretation |
|---|---|---|
| Home | lib/features/home/home_page.dart | Daily summary/focus and linked data exist; inspect exact current behavior. |
| Checklists | lib/features/checklists/ and repository | Existing checklist/occurrence system; investigate reuse before creating missions. |
| Goals | lib/features/goals/goals_page.dart | CRUD/status/history; inspected editor uses manual progress. |
| Routine | lib/features/routine/routine_page.dart | Date-focused blocks, templates, overlap checks, obligation/meal projections, execution totals. |
| Obligations | lib/core/database/obligations_repository.dart | Recurrence, date exceptions, occurrences, overnight-aware blocks. |
| Studies | lib/features/studies/study_page.dart and study_repository.dart | Subject/topic/session/review/summary methods exist; completeness requires re-audit. |
| Nutrition | lib/features/nutrition/nutrition_page.dart and nutrition_repository.dart | Food catalogue, meal plans, actual consumption, nutrition summaries, planned meal blocks. |
| Habits | lib/features/habits/habits_page.dart and habits_repository.dart | Quantitative habits and date logs. |
| Executions | lib/features/executions/executions_page.dart | Timer, pause/resume, discard/finish, manual execution. |
| Hobbies | lib/features/hobbies/ | Hobby records and sessions. |
| Notes / journal | lib/features/notes/ and lib/features/journal/ | Local notes and date-based journal. |
| Countdown | lib/features/countdowns/ | Countdown surface. |
| Profile | lib/features/profile/ | Local profile/body records; sensitive. |
| Security | lib/features/security/ and lib/core/security/ | PIN/biometric code exists; this is not database encryption. |
| Developer console | lib/features/settings/developer_console_page.dart | Debug diagnostics; review sanitization before adding logs. |

## 3. Gaps observed in the audited tree

- Routine view is day/date-focused. Full day/week/month calendar experience was not established.
- Goal progress in inspected editor is manual; complete aggregation from linked records was not established.
- No production Android launcher widget implementation was found.
- No Beto/Alfredo comparison feature was found.
- A complete manual + record-derived recurring mission domain was not established. Existing checklists may be reusable but semantics must be reviewed.
- No complete XP/level/achievement/prestige system was found.
- Historical analytics beyond existing summaries/charts are incomplete and need metric definitions.
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
