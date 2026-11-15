# Activity and Progress Architecture

## Objective

Define how one real action can support several Orva features without duplicating activity records or producing inconsistent metrics. This is an integration contract, not a mandate to introduce event sourcing.

## 1. Source facts and projections

Authoritative source facts include existing or approved domain records such as:
- checklist occurrence-item completion;
- study session;
- real execution/timer record;
- habit log;
- hobby session;
- meal consumption;
- obligation occurrence completion/skipping;
- goal progress history;
- future workout/finance records only after those modules are approved.

Each fact belongs to its domain repository and has a stable ID, date/timestamp, and domain meaning.

Derived projections include:
- Beto/Alfredo trait evidence and score;
- mission completion progress;
- XP eligibility and reward;
- consistency percentage;
- dashboard summary;
- widget snapshot;
- weekly/monthly charts.

A projection is not a second activity. It may be recomputed or persisted as an explicitly maintained cache/ledger with provenance and reconciliation.

## 2. Conceptual read model

A normalized read model may support aggregation, but must preserve provenance:

~~~text
ActivityEvidence
- sourceType
- sourceId
- occurredAt
- localDate
- durationMinutes?
- quantity?
- unit?
- category?
- completionState
- sourceVersion?
~~~

This is a conceptual contract, not an instruction to create the table immediately. Keep source-specific semantics in their owning domains. Never infer behavior only from a display label.

## 3. No generic event store by default

Before adding an append-only event table, assess whether existing tables/repositories support the query, whether a projection is enough, whether performance requires a cache, and whether auditability requires a reward ledger.

A generic event bus/event-sourcing implementation requires a proposal covering transactions, replay, idempotency, retention, privacy, and migrations.

## 4. Derived calculation contract

Every calculation declares:
- source record types;
- evaluation period;
- local-time/date boundary;
- eligibility;
- numerator and denominator;
- missing-data behavior;
- correction/deletion behavior;
- live, cached, or snapshotted status.

Pure calculations accept explicit records and dates. Do not read DateTime.now(), database state, or platform APIs inside pure domain logic.

## 5. Idempotency

Repeated triggers can occur due to retries, repeated taps, app resume, widget refresh, or recalculation.

For durable effects such as XP:
- define a stable reward source key;
- enforce uniqueness at persistence boundary;
- repeated processing returns the existing result;
- define correction/deletion behavior;
- never grant rewards on normal refresh.

For mission occurrences:
- unique identity is mission ID + local period key;
- generate idempotently;
- never create two occurrences for the same mission and period.

For widget actions:
- pass action intent to app;
- validate source state in repository;
- execute through domain command;
- refresh the snapshot after success.

## 6. Time semantics

- Store timestamps consistently and convert to user-local zone for calendar grouping.
- Store date-only concepts as date-only keys, not UTC timestamps.
- Default week start to Monday for pt-BR unless settings say otherwise.
- Handle DST even if Brazil is the first target market; do not assume all local days are 24 hours.
- Split overnight visual/aggregation segments at local midnight while retaining one source occurrence identity.
- Never double count the post-midnight portion.

## 7. Deletion, correction, and history

Each projection declares whether it is recomputed, an immutable historical snapshot, or a ledger of earned/reversed effects.

Editing a source fact must not silently rewrite unrelated records. Deletion must not leave unexplained reward/chart values. Preserve enough provenance to explain projection changes.

## 8. Performance

Start with repository queries and indexed aggregation. Measure before caching. If caching is required, define invalidation and full reconciliation. Keep widget snapshots small. Do not load journal/note bodies for dashboard calculations.

## 9. Required tests

- Same source event processed twice.
- Multiple modules reading one source event.
- Source edit and deletion.
- Missing data and partial period.
- Local midnight and overnight interval.
- Week/month/year boundary.
- Leap day and DST boundary where supported.
- Widget refresh after source write.
- Backup import/export and migration when schema changes.
