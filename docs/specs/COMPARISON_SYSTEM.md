# Feature Specification — Beto vs Alfredo Comparison

Status: PARTIALLY IMPLEMENTED — v1 MVP (schema v6). See implementation notes at the end.

Priority: P0 — Extremely urgent.

## 1. Intent

Compare selected user-defined behaviors against two built-in fictional archetypes:
- Alfredo: default representation of behaviors the user wants to strengthen.
- Beto: default representation of behaviors the user wants to reduce or avoid.

The result supports reflection about selected behavior during a defined period. It is not a personality test, diagnosis, moral score, or judgement of human worth.

## 2. Fixed pair and customization

V1 must contain exactly two built-in identities: Beto and Alfredo. Users may customize:
- avatar/illustration;
- short description and visible presentation;
- trait labels and explanations;
- trait direction, evidence rule, evaluation window, threshold, and weight;
- optional manual check-in settings.

Do not create arbitrary extra characters in v1. Keep stable internal identity and role semantics separate from display labels. Customization must not silently reverse the meaning of a side.

Seed example traits only as editable templates. Never seed fake activity or fake history.

## 3. Trait model

Each trait defines:
- stable ID;
- label and explanation;
- target character (Beto or Alfredo);
- measurement type;
- evidence source;
- evaluation window;
- threshold/target;
- weight;
- active/archive state;
- optional category;
- missing-data policy;
- timestamps.

Examples:
- Reads books: existing recorded study/reading session or explicit check-in.
- Studies programming: study session with relevant subject/topic.
- Maintains a routine: eligible scheduled blocks actually completed.
- Procrastinates: explicit user-marked skipped commitment, not an AI assumption.
- Uses a behavior the user wants to reduce: explicit user tracking only.

Avoid unmeasurable traits such as “is disciplined” without a rule.

## 4. Evidence sources

1. Existing Orva domain records queried through repositories.
2. Explicit user check-ins for behaviors with no reliable existing record.
3. Hybrid only when precedence and deduplication are explicit.

A study session must be read from Studies, not entered again in Comparisons. Manual input is visibly manual, editable, and timestamped. Never infer intent, emotion, personality, or off-app behavior.

## 5. Scoring model

For each trait, evaluate its rule over its configured window and return:
- favors Alfredo;
- favors Beto;
- neutral/partial;
- unknown.

Keep evidence and explanation for the outcome. Unknown is not a point for either side.

For binary equal-weight traits:
- Alfredo score = weight of assessed traits favoring Alfredo.
- Beto score = weight of assessed traits favoring Beto.
- assessed weight = Alfredo score + Beto score.
- Alfredo share = Alfredo score / assessed weight.
- Beto share = Beto score / assessed weight.

For weighted traits, use the same formula with configured weights. If assessed weight is zero, show “insufficient data”; never fabricate 50/50.

Always show:
- evaluation period;
- assessed trait count / active trait count;
- coverage;
- percentages;
- traits contributing to each side;
- unknown/unassessed traits;
- last-updated time.

A 50/50 result is valid only when assessed weighted evidence is split equally. It must not be hard-coded.

## 6. Evaluation windows and thresholds

The owner has not chosen one universal period. Support a selectable window. Recommended initial choices:
- current week;
- trailing 7 days;
- trailing 30 days;
- current month;
- custom date range.

A default may be selected in UI, but it must be labelled and configurable. Never compare lifetime with weekly results without clear labelling.

Trait rules may include:
- binary check-in: at least one affirmative occurrence;
- count target: quantity >= threshold;
- frequency: qualifying days >= target days;
- duration: sum of qualifying minutes >= target;
- avoidance: no user-recorded occurrence during the period, only when user opted into explicit tracking.

Absence of a log does not prove a behavior did not occur. A scheduled opportunity can establish non-completion only if it exists and the user explicitly tracks its completion/skip state.

## 7. Default editable trait templates

An initial template may include ten traits:
- reading;
- studying;
- exercise;
- sleep routine;
- keeping commitments;
- learning a skill;
- delaying important work;
- excessive social media use;
- abandoning planned tasks;
- one user-selected behavior to reduce.

Sensitive or stigmatizing traits must never be enabled as facts about the user. Require opt-in.

## 8. History and recalculation

History should retain:
- period boundaries;
- trait rule/version;
- score and coverage;
- source references or reproducible evidence summary;
- timestamp.

Decide whether views are live or immutable snapshots. Recommended: current period is live; closed-period views are immutable or versioned. Later edits must not silently rewrite a previously reviewed result. If source facts are corrected, expose that policy and correction.

## 9. Privacy and safety

Local by default. Do not log trait values, check-ins, or evidence. Do not show comparison traits in widgets by default. Sensitive tracking is opt-in. No diagnosis, addiction label, mental-health inference, or moral ranking. Provide edit/archive/delete/export/reset controls. Avoid shame language, punitive alerts, and public leaderboards.

## 10. Acceptance criteria

1. Exactly two built-in identities.
2. Presentation can be personalized within fixed-pair constraint.
3. At least one trait reads existing Orva records without duplicate input.
4. At least one trait uses explicit manual check-in.
5. Rules are deterministic and unit-tested.
6. Missing evidence is unknown and excluded from denominator.
7. Score and coverage formulas are explainable.
8. Evaluation period is visible.
9. Editing/deleting evidence has predictable history behavior.
10. Refresh/recalculation does not duplicate evidence or rewards.
11. Themes, accessibility, and empty/error states work.
12. Sensitive traits require explicit opt-in.

## 11. Open decisions before final UI lock

- Default evaluation period.
- Whether manual evidence is daily, occurrence-based, or review-based per trait.
- Whether closed periods are immutable snapshots or live recomputations.
- Whether character names can change or only imagery/descriptions/traits.
- Exact default templates and weights.

Do not silently hard-code these choices into persisted data.

## 12. Implementation notes — v1 MVP (schema v6)

Delivered:

- Fixed pair: `comparison_profiles` rows `alfredo` and `beto`; display name and description are editable, roles are not.
- `comparison_traits` stores label, explanation, target character, measurement type, optional source, threshold, unit, weight, optional per-trait window, sensitive flag, active flag, timestamps.
- Measurements implemented: manual check-in, habit quantity, study minutes. Record-based traits read `habit_logs` / `study_sessions`; nothing is re-entered or duplicated.
- `comparison_checkins` is unique per trait and local date, so repeating a check-in overwrites instead of duplicating evidence.
- Scoring lives in `lib/core/domain/comparison_scoring.dart` (pure). Outcome per trait: target side when the threshold is reached, `neutral` when evidence exists but is below it, `unknown` when the source has no eligible evidence. Unknown and neutral are excluded from the denominator, so no result is hard-coded to 50/50.
- Four editable templates are seeded once (never activity evidence). Sensitive traits are stored inactive and require explicit activation.
- Backup format v6 includes the three comparison tables; v3, v4 and v5 backups upgrade in memory by adding empty collections.

Decisions taken for this slice:

- One period selector on the screen (last 7 days, last 30 days, current week, current month) persisted as `comparison_period`. A trait-level `window_days` overrides it; `0` follows the selector.
- Results are live projections. Closed-period snapshots are not implemented yet.
- Manual evidence is one occurrence per local day per trait (not a daily 1-5 review scale).
- Character names are editable; internal roles stay `beto`/`alfredo`.

Known gaps:

- No immutable history/versioning of reviewed periods.
- No evidence-history screen (per-day list) and no export-only trait report.
- No coupling to XP, missions, analytics or widgets yet; those must read this projection rather than store a second score.
- No opportunity-based inference: absence of a log is always `unknown`, never a point for either side.

Validation: `test/comparison_test.dart` covers threshold/neutral/unknown outcomes, weighting, coverage, week/month/leap-day windows, check-in idempotency, habit and study reuse, sensitive opt-in, cascade delete, backup v6 round-trip, v5 upgrade, and the v5→v6 schema migration.
