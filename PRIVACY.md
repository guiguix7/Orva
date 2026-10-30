# Privacy

## Summary

Orva is designed to be private by default. Personal data stays on the device unless the user explicitly exports or shares a backup.

## Data collection

- No account is required.
- No telemetry or analytics is collected.
- No notes, journal entries, goals, habits or personal records are sent to external services.
- Firebase initialization is optional and local-first; the app works without network access.

## Data storage

- All application data is stored in a local SQLite database on the device.
- Backups are created only when the user chooses to export them.
- Backup files may contain personal data; store and share them carefully.

## Sensitive data

- Journal and note content should be treated as private data on the device.
- Weight and health-related records are stored locally.
- The database is not encrypted at rest; device-level protection (PIN, biometrics, device encryption) is recommended.

## Widgets and notifications

- Android widgets display only non-sensitive summaries (counts, progress, countdowns).
- No journal text, private notes, health data or weight is shown in widgets.
- With the lock enabled, widgets show generic counters and require unlock for actions that change data.

## User control

- Users can export and import backups at any time.
- Users can enable or disable the PIN lock and biometrics.
- Deleting records requires confirmation for destructive actions.

## Contact

For privacy questions, contact the project owner.