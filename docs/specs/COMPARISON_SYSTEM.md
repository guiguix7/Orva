# Feature Specification — Beto vs Alfredo Comparison

Status: SPECIFIED / NOT IMPLEMENTED in the 2026-10-30 audited tree. Re-audit before coding.

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
