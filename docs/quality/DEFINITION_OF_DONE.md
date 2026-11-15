# Orva Definition of Done

A task is not complete merely because code compiles or a screen renders.

## 1. Product behavior
- User outcome and acceptance criteria are satisfied.
- Scope matches roadmap priority.
- Loading, empty, partial, error, and success states are deliberate.
- Behavior persists correctly across navigation/restart.
- User copy is pt-BR.
- No unrequested feature expansion.

## 2. Architecture
- Existing authoritative records are reused.
- No duplicate activity/schedule store without justification.
- UI contains no raw SQL or core business rules.
- Domain calculations are deterministic/testable.
- Platform code is isolated.
- No unnecessary dependency/framework.

## 3. Data integrity
- Numeric/time values are validated.
- Schema version and migration paths are correct.
- Existing records/history are preserved.
- Backup import/export is compatible or explicitly versioned.
- Retryable operations are idempotent.
- Source edit/delete has defined projection/reward behavior.

## 4. Privacy/security
- No secrets or personal data in logs.
- Widgets/notifications contain only approved safe fields.
- External processing requires explicit consent.
- Local storage claims are accurate.
- PIN lock is not described as database encryption.

## 5. Accessibility/UI
- Light, dark, and system modes work.
- Text scaling does not break layout.
- Touch targets and contrast are adequate.
- Status is not communicated by color alone.
- Keyboard/focus/screen-reader semantics are considered.
- Small screen and long user-generated text are tested.

## 6. Technical checks

Baseline, when applicable:
~~~bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
~~~

Feature-specific:
- Database: fresh install, upgrade migration, transaction/rollback, backup export/import.
- Android widgets: add/remove/resize, restart, process death, reboot, refresh, stale state, lock state, multiple launchers/API levels.
- Calendar: day/week/month boundaries, recurrence, exceptions, overlap, midnight, timezone, DST where relevant.
- Comparisons: source, threshold, weight, missing data, coverage, history, correction, sensitive-data privacy.
- Missions/XP: duplicate completion/reward, recurrence, archive/edit, source deletion/correction, pause/rest.
- Analytics: denominator, incomplete periods, unknown data, source deduplication, actual-versus-planned.

## 7. Evidence

Report every check as:
- PASS — executed and passed.
- FAIL — executed and failed, with relevant error.
- NOT RUN — not executed, with reason.
- BLOCKED — unavailable due to device/tool/configuration.

Never replace evidence with “should work”, “looks correct”, or “production-ready”.

## 8. Handoff
- [ ] User-visible behavior summarized.
- [ ] Files changed.
- [ ] Schema/migration/backup impact.
- [ ] Tests and exact results.
- [ ] Platform/device validation status.
- [ ] Privacy/accessibility review.
- [ ] Known limitations and next task.
