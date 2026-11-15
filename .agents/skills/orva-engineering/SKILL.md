---
name: orva-engineering
description: Repository-specific workflow for planning, implementing, reviewing, and validating Orva. Use for Flutter features, architecture, Drift, Android widgets, calendar/time blocking, comparisons, missions, gamification, analytics, and documentation.
---

# Orva Engineering Skill

This skill supplements AGENTS.md and never overrides it. Read AGENTS.md first.

## Mandatory preflight

1. Run git status and identify the branch. Preserve user changes.
2. Read PROMPT_MASTER.md and docs/agents/CURRENT_STATE.md.
3. Read the relevant product and feature specifications.
4. Inspect current pages, repositories, providers, schema, migration strategy, and tests.
5. Search for existing entities and calculations before creating new ones.
6. Identify persistence, backup, native platform, privacy, recurrence, and history impact.
7. Write acceptance criteria and a test plan before editing.

## Source-of-truth rules

- Existing Drift/SQLite records are authoritative for user activity.
- Comparison evidence, mission progress, XP eligibility, analytics, dashboards, and widget snapshots are projections—not duplicate activities.
- If a projection is persisted, define provenance, invalidation, and reconciliation.
- Never count one study session/checklist occurrence/execution/habit log more than once.
- Planned blocks and meal plans are not proof that activity occurred.
- Manual missions are distinct from record-derived missions.
- Missing evidence is unknown, not failure.
- Each derived value declares its period, denominator, source, and limitations.

## Implementation sequence

### A. Specify behavior
Record user intent, state transitions, source records, formulas, time semantics, empty/error/partial states, migration impact, privacy, and acceptance tests.

### B. Design the smallest data change
Reuse existing entities where possible. Add tables only for durable concepts that cannot be represented safely by existing records. Avoid premature generic frameworks.

For schema changes:
- Increment schema version.
- Add forward migration from every supported prior version.
- Test fresh database and upgrade paths.
- Update export/import and backup compatibility tests.
- Verify transactions, foreign keys, and historical preservation.

### C. Implement domain logic first
Put deterministic scoring, recurrence, XP, aggregation, and overlap calculations in domain code. Inject dates/clocks into tests. Keep database, wall-clock, and platform I/O outside pure functions.

### D. Connect persistence
Use existing repository/provider patterns. Add stable idempotency keys for actions that can be replayed by retries, widget callbacks, recalculation, or app resume.

### E. Build UI
Use existing design tokens/components. Implement accessible touch targets, scalable text, keyboard-safe forms, loading/error/empty states, and light/dark support. UI copy is pt-BR.

### F. Validate
Ordinary Dart/Flutter:
~~~bash
dart format .
flutter analyze
flutter test
~~~
Android/native/widget work:
~~~bash
flutter build apk --debug
~~~
Also test on an Android emulator/device. Compilation does not prove widget refresh, native lifecycle, or interaction.

For database work, run migrations and backup tests. Calendar work requires boundary and overnight tests. Gamification requires duplicate-event, deletion/correction, and reward-idempotency tests.

## Feature-specific rules

### Beto vs Alfredo
- Exactly two built-in character identities in v1.
- Users may personalize presentation and trait/rule definitions without adding characters.
- Each trait defines behavior, direction, evidence source, evaluation window, threshold, weight, and missing-data behavior.
- Use existing Orva records or explicit manual check-ins. Never ask users to re-enter the same activity.
- Do not infer addiction, medical conditions, mental health, or personality. Sensitive tracking is opt-in, private, and non-diagnostic.
- Show score coverage and evaluation period. Unknown traits are not assigned to either character.
- Keep deterministic score logic separate from XP.

### Android widgets
- Flutter/Drift is authoritative.
- Native widgets read a small sanitized snapshot through a platform adapter.
- Do not access Drift directly from native widget code.
- Actions route through app-side domain/repository commands.
- Exclude journal/note text, health/finance details, and private behavior.
- Respect lock state, resizing, stale data, process death, reboot, accessibility.
- Keep snapshot DTOs portable for later iOS.

### Calendar and time blocking
- Reuse routine blocks, obligations, meal plans, and execution records as separate facts in a unified projection.
- Calendar is a view, not a second schedule database.
- Distinguish planned, completed, skipped, and actual execution.
- Handle recurrence, exceptions, overlaps, local dates, time zones, and midnight-crossing intervals.
- Drag/resize has explicit conflict and persistence rules; never silently move another event.
- Changing recurring rules must preserve completed history.

### Missions and rewards
- Support manual and criteria-driven missions.
- Define daily/weekly/monthly/yearly boundaries.
- Generate stable occurrences idempotently.
- Derive integrated progress from source records.
- Define correction/deletion and reward reversal policy.
- Prevent farming, duplicate rewards, and retroactive re-awarding.
- Rest and pause must not cause punitive resets.

### Analytics
- Define numerator, denominator, time window, and exclusions.
- Use real completed records, not app opens or planned blocks.
- Respect rest days and scheduled days.
- Missing data is not 0%.
- Compare equivalent periods and label incomplete windows.
- Make history reproducible or explicitly snapshotted.

## Review checklist

Verify: no duplicate source of truth; no double counting; no time boundary bugs; no data loss; no private content leakage; no misleading metrics; all critical states tested; docs/current-state updated; test results reported exactly.

## Handoff

Report user-visible behavior, files changed, schema/backup impact, exact test results, unverified behavior, and the next smallest task.
