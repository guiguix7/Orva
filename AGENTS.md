# Orva — Agent Operating Contract

This is the repository-wide source of truth for AI coding agents. Read it before inspecting or changing code. These rules apply to every model, IDE, sub-agent, and task.

## 1. Product identity

Orva is a private-by-default, local-first personal growth system built with Flutter and Dart. It connects planning, real activity records, goals, missions, behavioral self-comparison, progress analytics, and low-friction access through Android widgets.

It is not merely a todo list, social network, medical authority, or financial authority.

Principles:
1. Evidence before appearance: every metric must be traceable to real records or clearly identified manual input.
2. One source of truth: a single activity must never be stored or rewarded twice because several modules consume it.
3. Local-first: core features work offline and do not require an account.
4. Privacy by default: journal, notes, health, finance, and behavioral records must not leak into logs, widgets, notifications, analytics, or external services.
5. Honest measurement: missing data is unknown, not failure; planned time is not completed time; app opens are not progress.
6. User agency: users define goals, comparison criteria, and tracking boundaries. The product must not shame, diagnose, or manipulate.
7. Incremental engineering: prefer small, testable changes over speculative rewrites.
8. Accessibility and usability are requirements.

## 2. Mandatory context

Before work, read:
- PROMPT_MASTER.md.
- .agents/skills/orva-engineering/SKILL.md.
- docs/agents/CURRENT_STATE.md.
- docs/product/PRODUCT_VISION.md and docs/product/ROADMAP.md.
- The relevant feature specification under docs/specs/.
- Actual source files, repositories, schema, migrations, and tests.

Do not treat README prose, old planning documents, prior AI answers, or screenshots as proof that a feature is implemented. Source code, tests, migrations, CI evidence, and current platform behavior take precedence.

docs/MASTER_PROMPT_REQUIREMENTS.md is superseded and must not be used as an implementation status source.

## 3. Binding product decisions

- Comparison uses exactly two built-in characters: Beto and Alfredo. The pair is fixed; presentation and traits/rules can be personalized. Do not silently turn it into an arbitrary multi-character system.
- Android home-screen widgets first. Keep a portable data contract for future iOS support, but do not delay Android for iOS.
- Missions support both manual completion and progress derived from existing Orva records.
- Follow docs/product/ROADMAP.md for priorities.
- Ollama/AI, vice tracking, workout tracking, and finance tracking are future expansions. Do not build them during unrelated tasks.

## 4. Architecture and data integrity

Current foundations: Flutter/Dart, Riverpod, Drift over SQLite, repositories under lib/core/database/, and domain calculations under lib/core/domain/.

Rules:
- Inspect current architecture before choosing where code belongs.
- Separate UI, domain calculations, persistence, and platform integration.
- Use repositories as the persistence boundary. Do not put raw SQL in widgets.
- Keep deterministic calculations side-effect-free where practical.
- Do not introduce a second database, duplicate routine data, a shadow checklist system, a new state-management framework, generic event sourcing, a cloud backend, or an event bus without a written engineering justification.
- When multiple modules need the same fact, reuse the original record and expose a derived projection.
- Any persisted projection/cache requires provenance, invalidation, and reconciliation rules.
- Durable rewards require idempotency. Re-running calculations must not grant duplicate XP.
- Preserve historical snapshots where later catalogue edits would otherwise change historical meaning.
- Use explicit local-time/date semantics. Date-only values are not UTC timestamps.
- Handle intervals crossing midnight without truncation or double counting.
- Validate numeric inputs for finiteness, range, and units.
- Planned activity is never proof of completed activity.

## 5. Drift and migration rules

Any schema change is high-risk:
1. Inspect AppDatabase.schemaVersion and the full MigrationStrategy.
2. Increment the schema version exactly once for the migration batch.
3. Implement forward, non-destructive migration from every supported prior version.
4. Preserve records and relationships.
5. Add migration tests for old schemas, rows, constraints, indexes, and foreign-key behavior.
6. Update JSON backup export/import and compatibility tests when schema content changes.
7. Test transaction/rollback behavior.
8. Never solve a migration problem by deleting the database, resetting user data, or asking users to reinstall.

Do not edit generated files unless the current generation strategy requires it. Inspect pubspec.yaml before adding build_runner or generated artifacts.

## 6. Privacy and security

- Never log journal text, note bodies, food details, weight, financial records, private habit details, authentication tokens, PINs, or backup contents.
- Logs must be sanitized, bounded, and useful without exposing user content.
- Never put sensitive content in widgets, lock-screen notifications, launcher previews, analytics, or error reports.
- Do not claim SQLite is encrypted at rest unless encryption is implemented and verified. A PIN lock is not database encryption.
- Do not add telemetry without explicit approval and privacy review.
- Keep Firebase optional; local core flows must work without it.
- Never hardcode secrets, signing keys, OAuth secrets, or API keys.
- External AI requires explicit opt-in, clear disclosure, and data minimization. Ollama is a future option, not an implicit default.

## 7. Flutter/Dart rules

- Follow the existing code style and naming conventions.
- Use null safety, typed models where they improve correctness, and explicit error handling.
- Avoid broad dynamic maps in new domain APIs when typed models are reasonable; do not perform a repository-wide conversion for a small feature.
- Keep widgets focused. Extract repeated UI only when this improves clarity or reuse.
- Dispose controllers, timers, streams, and animation controllers.
- Guard async UI updates against disposal.
- Avoid hidden network requests in build methods.
- Use stable entity IDs, never list indexes as identity.
- Implement loading, empty, error, partial, and populated states.
- Preserve light, dark, and system theme behavior.
- User-visible text is Brazilian Portuguese (pt-BR). Identifiers, technical docs, comments, and agent instructions are English by default.
- Verify dependency compatibility, platform support, maintenance, license, and transitive cost before adding packages.

## 8. Required workflow

For every non-trivial task:
1. State the user outcome and acceptance criteria.
2. Inspect git status, branch, source, tests, schema, migrations, and docs.
3. Identify the source of truth and downstream modules.
4. Write a short implementation/test plan.
5. Implement the smallest complete vertical slice.
6. Add tests for behavior, edge cases, persistence, and regressions.
7. Run applicable checks and report exact results.
8. Review diff for unrelated edits, secrets, accidental data changes, and stale docs.
9. Update current-state and feature documentation.
10. Report delivered work, evidence, limitations, and next task.

Before writing:
- Check git status and preserve user changes.
- Never reset, clean, force-push, or rewrite history.
- Use a focused branch for substantial work.
- Do not merge or push to main unless explicitly requested.
- Do not create a PR before reviewing the branch diff.

## 9. Validation

Run relevant commands from repository root:
~~~bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
~~~

Android widget work also requires native build and emulator/device lifecycle checks. Calendar work requires period/date/overnight tests. Schema changes require migration and backup tests.

Never claim a check passed unless executed and the exit status was observed. If a command cannot run, report NOT RUN and why. Green CI is not physical-device evidence or proof of untested behavior.

## 10. Scope control

Do not implement finance, workout, vice tracking, or Ollama during unrelated work. Do not bundle all urgent modules into one giant change. Deliver independently testable slices.

Gamification must not become noisy, shame-based, punitive, or designed to cause compulsive tracking.

## 11. Documentation authority

- Product direction: docs/product/PRODUCT_VISION.md.
- Priorities: docs/product/ROADMAP.md.
- Actual repository state: docs/agents/CURRENT_STATE.md.
- Behavior contracts: docs/specs/.
- Acceptance gates: docs/quality/DEFINITION_OF_DONE.md.

Status values:
- SPECIFIED / NOT IMPLEMENTED
- PARTIALLY IMPLEMENTED
- IMPLEMENTED / NOT VALIDATED
- IMPLEMENTED / VALIDATED
- BLOCKED

A screen or table existing is not proof of a complete feature. Mark VALIDATED only when acceptance checks have evidence.

## 12. Required handoff

Include summary, files changed, design decisions, exact test commands/results, limitations, schema/backup implications, and the next smallest task. Never claim production readiness based only on compilation.
