# Contributing to Orva

Thanks for taking the time to improve Orva. This project is a private-by-default,
local-first personal growth system. Contributions are welcome when they respect
user data, privacy and the product's honest-measurement principles.

## Before you start

1. Read [`AGENTS.md`](AGENTS.md) — it is the repository-wide engineering contract.
2. Read [`docs/agents/CURRENT_STATE.md`](docs/agents/CURRENT_STATE.md) and the
   relevant specification under [`docs/specs/`](docs/specs/).
3. Check the issue tracker before starting a large change. For anything beyond a
   small fix, open an issue describing the problem, the intended behavior and the
   acceptance criteria.
4. Inspect the actual source, schema, migrations and tests. Documentation and
   screenshots are not proof that a feature is implemented.

## Development setup

Requirements are listed in the [README](README.md#requirements). In short:

- Flutter SDK with Dart 3.13.5+
- Android SDK (minSdk 24, targetSdk 36, Java 17)
- An emulator or physical device for UI and widget work

```bash
flutter doctor
flutter pub get
flutter run
```

## Required checks

Run these from the repository root before opening a pull request:

```bash
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

- `flutter analyze` must report **no errors and no warnings**. Existing infos are
  non-blocking, but do not add new ones.
- Add or update tests for behavior changes, edge cases, persistence and
  regressions.
- Widget work also needs a native build plus an emulator/device lifecycle check.
- Calendar work needs period, date and overnight tests.
- Schema work needs migration and backup tests.

If a check cannot run in your environment, say so explicitly in the pull request
instead of claiming it passed.

## Branches and commits

- Use a focused branch, for example `feat/hobby-weekly-target` or
  `fix/checklist-refresh`.
- Keep pull requests small and independently reviewable.
- Write commit messages in the imperative mood, preferably following
  [Conventional Commits](https://www.conventionalcommits.org/):
  `feat: add weekly hobby chart`, `fix: refresh checklist on tab activation`.
- Do not rewrite shared history, force-push or merge without review.
- Do not commit generated build output, local databases, secrets or signing keys.

## Code conventions

- Follow the existing Flutter/Dart style and null safety.
- Separate UI, domain calculations, persistence and platform integration.
- Repositories are the persistence boundary. Do not put raw SQL in widgets.
- Keep deterministic calculations side-effect-free where practical.
- Dispose controllers, timers, streams and animation controllers. Guard async UI
  updates against disposal.
- Use stable entity IDs, never list indexes as identity.
- Implement loading, empty, error, partial and populated states.
- Preserve light, dark and system theme behavior.
- User-visible text is Brazilian Portuguese (pt-BR). Identifiers, comments and
  technical documentation are English by default.

## Data, schema and backups

Schema changes are high-risk. If your change touches persistence:

1. Inspect `AppDatabase.schemaVersion` and the full `MigrationStrategy`.
2. Increment the schema version exactly once for the migration batch.
3. Implement a forward, non-destructive migration from every supported version.
4. Preserve rows, relationships, constraints and indexes.
5. Add migration tests for old schemas and data.
6. Update JSON backup export/import and compatibility tests.
7. Test transaction and rollback behavior.

Never solve a migration problem by deleting the database, resetting user data or
asking users to reinstall.

## Privacy and security

- Never log journal text, note bodies, food details, weight, financial records,
  private habit details, PINs, tokens or backup contents.
- Never put sensitive content in widgets, notifications, analytics or error
  reports.
- Do not claim SQLite is encrypted at rest unless encryption is implemented and
  verified. A PIN lock is not encryption.
- Do not add telemetry, external AI calls or cloud storage without explicit
  approval and a privacy review.
- Never hardcode secrets, signing keys or API keys.
- Report vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md).

## Tests

- Pure calculations belong in `test/` with focused unit tests.
- Widget tests should cover light/dark themes and narrow/wide layouts when the
  change affects layout.
- Integration flows live in `integration_test/` and run on a device or emulator.
- Prefer deterministic tests: fixed clocks and explicit fixture data.

## Documentation

- Update `docs/agents/CURRENT_STATE.md` when the verified repository state changes.
- Update the relevant feature spec when behavior or acceptance criteria change.
- Keep the README and setup instructions accurate.

## Pull request checklist

- [ ] The change has a single, clear purpose.
- [ ] Tests were added or updated and pass.
- [ ] `dart format .`, `flutter analyze` and `flutter test` pass.
- [ ] No secrets, local databases, build output or personal data are included.
- [ ] Privacy, schema and backup implications were considered and documented.
- [ ] User-facing copy is in pt-BR and follows the product tone.
- [ ] Documentation was updated when behavior changed.
- [ ] Limitations and unverified paths are stated in the description.

## Reporting bugs

Include the app version (`pubspec.yaml`), device/Android version, steps to
reproduce, expected behavior, actual behavior and sanitized logs or screenshots.
Never attach private journal, note, health or backup content.
