# Feature Specification — Calendar and Time Blocking

Status: PARTIALLY IMPLEMENTED foundation; full day/week/month calendar experience was not established in the audited tree.

Priority: P1 — Urgent.

## 1. Goal

Evolve existing routine/time records into a genuine calendar without creating a duplicate scheduling database.

## 2. Existing foundations observed

- Routine blocks and weekly templates.
- Recurring obligations and date-specific exceptions.
- Meal-plan blocks when start and duration are explicit.
- Real execution records.
- Date-focused RoutinePage and daily projection.
- Existing overlap and occupied-time calculations.

Re-audit current code before implementation.

## 3. Calendar views

### Day
Vertical timeline/hour grid, current-time indicator for today, distinct planned/obligation/meal/actual records, tap-to-inspect/edit, conflict and empty states.

### Week
Seven-day grid, Monday-first by default for pt-BR, current day highlight, week navigation and quick Today action, responsive layout for small screens.

### Month
Month grid with concise activity/mission markers, date selection to open day detail, deadlines/milestones only when source data supports them. Avoid unreadable event cards.

## 4. Source facts and states

Keep these domains distinct:
- routine block = planned personal time;
- obligation occurrence = recurring commitment, possibly completed/skipped;
- meal plan = planned meal, not proof of consumption;
- execution = recorded real activity;
- checklist/mission = task state, not necessarily a time block.

Calendar uses a unified read projection retaining source ID/type. Do not copy every record into another canonical event table.

States: planned, in progress (only with real timer/state), completed, skipped/cancelled, actual execution, conflict/overlap. A block is not completed merely because its end time passed.

## 5. Interactions

MVP: create/edit/delete a block, navigate dates, open linked source module, create execution from a block where supported, display overlap/conflict.

Later: drag, resize, duplicate, batch scheduling.

Drag/resize must define snap interval, start/end validity, overnight policy, conflict behavior, and owning repository write. Show conflict feedback. Never silently move/truncate another event. Preserve source identity and history.

## 6. Recurrence and exceptions

Reuse existing recurrence semantics first. Preserve date-specific exceptions. Changing a recurring rule must not rewrite completed history. Skipping one occurrence must not disable the rule. Overrides must be reversible. Mission recurrence is separate even if central date utilities are shared.

## 7. Midnight and time zones

Support allowed overnight blocks. Split visual/aggregate segments at local midnight but retain one source occurrence identity. Do not create duplicate completion records. Calculate real local interval duration, not lexical time strings. Test same-day, overnight, invalid/zero-length, DST, leap day, month end, and timezone transitions where relevant.

## 8. Planned versus actual analytics

Separate planned duration, actual execution duration, completed records, and skipped/cancelled commitments. Do not infer execution from scheduled duration. Unlinked actual execution remains unplanned actual time.

## 9. Acceptance criteria

1. Day/week/month navigation works.
2. Supported source types render with distinct states.
3. A source record appears once per applicable view.
4. Existing templates and obligation exceptions continue to work.
5. Overlaps are visible with defined save behavior.
6. Overnight intervals render/aggregate without double count.
7. Planned and actual time remain separate.
8. Recurring-rule edits preserve completed history.
9. Small screens, text scaling, themes, keyboard, and semantics work.
10. Unit/widget/integration tests cover period and date boundaries.
