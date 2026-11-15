# Orva Product Roadmap

This roadmap preserves the product owner's stated urgency. Engineering dependencies can be built earlier when required, but must not silently change feature priority.

## Priority definitions

- P0 — Extremely urgent.
- P1 — Urgent / very urgent / partially urgent.
- P2 — Low urgency.
- P3 — Not urgent; future modules.
- P4 — Exploratory future capability.

## Ordered roadmap

| Priority | Capability | Owner urgency | Direction |
|---|---|---|---|
| P0 | Beto vs Alfredo comparisons | Extremely urgent | Fixed pair, customizable presentation and trait/rule system |
| P1 | Android home-screen widgets | Urgent | Android first, iOS later |
| P1 | Calendar and time blocking | Urgent | Day/week/month over existing schedule records |
| P1 | Consistency and progress analytics | Very urgent | Evidence-based metrics with explicit formulas |
| P1 | Recurring missions/checklists | Partially urgent | Manual and record-integrated mission types |
| P2 | XP and levels | Low urgency | Increasing progression curve; separate from comparison score |
| P2 | Achievements and prestige | Low urgency | Milestones, titles, long-term recognition |
| P3 | Vice / unwanted behavior tracking | Not urgent | Private, non-diagnostic, user-defined |
| P3 | Workout tracking | Not urgent | Exercise sessions, sets/reps/load, history |
| P3 | Finance tracking | Not urgent | Income, expenses, budgets, goals; highly sensitive |
| P4 | Ollama integration | Not urgent | Optional local AI with explicit data-access boundaries |

## Delivery phases

### Phase 0 — Agent and domain foundation
Adopt the agent contract/specifications. Audit schema, backup, migration, tests, and CI. Define the shared activity/progress contract. Do not turn this into a generic framework rewrite.

### Phase 1 — Beto vs Alfredo MVP (P0)
- Fixed built-in character pair.
- Editable presentation and configurable trait/rule definitions.
- Evidence from existing Orva records plus optional explicit check-ins.
- Evaluation period, thresholds, weights, coverage, and explainable result.
- Historical snapshots/reproducible history.
- Tests for missing data, corrections, duplicate evidence, and date boundaries.

### Phase 2 — Android widgets (P1)
- Small sanitized widget snapshot contract.
- Today widget first.
- App-side refresh triggers and native Android surface.
- Agenda and progress widgets after Today is stable.
- Test resize, lifecycle, stale data, privacy, and tap actions on Android.

### Phase 3 — Calendar and time blocking (P1)
- Unified projection over routine blocks, obligations, meal plans, and real executions.
- Day/week/month views.
- Planned / actual / skipped status.
- Conflict-aware interactions.
- Recurrence, exceptions, overnight intervals.
- Do not duplicate existing routine data.

### Phase 4 — Consistency and progress analytics (P1)
- Metric catalogue with numerator, denominator, window, exclusions.
- Daily/weekly/monthly trends.
- Planned versus realized time.
- Goal and mission progress.
- Heatmap based on eligible opportunities, not app opens.
- Partial-data and insufficient-data states.

### Phase 5 — Missions (P1)
- Manual and record-integrated missions.
- Daily, weekly, monthly, yearly recurrence.
- Occurrence generation/history.
- Idempotent completion.
- Widget and analytics integration.

### Phase 6 — XP, levels, achievements, prestige (P2)
- Reward ledger or equivalent idempotency.
- Central progression formula.
- Achievement criteria and milestone history.
- Farming resistance, correction/deletion policy, rest flexibility.

### Phase 7 — Future modules (P3/P4)
Vice, workouts, finance, optional Ollama.

## Dependencies

- Comparison, missions, XP, analytics, widgets consume common activity records. Shared logic is a technical dependency, not a new product priority.
- Widgets depend on stable read models and refresh triggers.
- Calendar depends on correct recurrence, exceptions, date/time calculations.
- Analytics depends on metric definitions and reliable history before chart design.
- XP depends on deduplicated qualifying actions and reward correction policy.
- Ollama depends on secure local data access, scopes, and explicit consent.

## Scope discipline

Do not implement every phase in one change. Keep each phase independently reviewable and shippable. Lower-priority features may receive only the minimum architecture accommodation required by higher-priority work.
