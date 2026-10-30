# Security

## Summary

Orva is a local-first personal organization app. Security is focused on protecting access to the app on the device and on preserving data integrity during migrations and backups.

## Authentication and access control

- Optional PIN lock is supported.
- PINs are never stored in plain text. New PINs use PBKDF2-HMAC-SHA256 with a random salt and 100,000 iterations.
- Legacy salted SHA-256 PINs remain verifiable for safe migration and are upgraded after a correct verification.
- After 5 failed attempts a progressive cooldown is applied (30s up to 5 minutes).
- Lockout metadata is stored locally and is excluded from backups.
- Biometric authentication uses `local_auth` with a PIN fallback. Biometric availability, cancellation, failure and hardware absence are handled.

## What is NOT encrypted

- The SQLite database is not encrypted at rest.
- Blocking the UI with a PIN or biometrics does not encrypt the database.
- Full database encryption would require a dedicated migration and is not implemented in this version.

## Backups

- Backup format is versioned JSON (`orva_backup`, version 5).
- PIN hash, salt and lock flags are never exported.
- Import validates format and version and applies replacement inside a transaction with rollback on failure.
- Older backups (v3, v4) are upgraded in memory by adding empty collections for newly introduced tables.

## Logging and diagnostics

- The developer console is available only in debug builds.
- Diagnostics sanitize credential-like values and email addresses.
- PINs, tokens and personal data are never logged.

## Reporting vulnerabilities

Please report security issues privately to the project owner instead of opening a public issue. Include reproduction steps, affected version and device information. Do not include real personal data in reports.