# Feature Specification — Calendar and Time Blocking

Status: PARTIALLY IMPLEMENTED — day/week/month calendar UI, timeline, overlap lanes, conflicts and free-time metrics are implemented (see Implementation notes). Drag/resize and immutable history are not implemented.

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

## 10. Implementation notes — calendar slice

Delivered:

- `lib/features/calendar/` replaces the old routine page as the single scheduling surface. `Mais → Calendário e tempo` and the Home shortcuts open it.
- Day view: 24h timeline with hour gutter, positioned blocks, overlap lanes (side by side, never hiding each other), a live "now" line for today, tap on empty space to create a block at that time, and tap on a block for a details sheet (edit / duplicate / delete / open source).
- Week view: wide screens get a seven-column time grid with a shared axis; phones get seven readable day rows with a proportional activity strip, totals and conflict count instead of compressed columns.
- Month view: Monday-first six-week grid, discreet activity dots, today/selected states, and a selected-day preview that opens the day view.
- Sources stay separate and are labelled: routine blocks (editable, planned), obligations and meal plans (read-only, planned commitments), executions (read-only, real spent time). Planned time never counts as executed and executions never consume free-time slots.
- Summary strip: planned (union, no double counting), free time, executed time when evidence exists, and conflict count.
- `routine_editor.dart` holds the shared block editor and templates dialog; the editor now accepts an initial start time and block kind so the timeline can create blocks at the tapped hour.

Projection rules:

- The calendar reads through `CalendarRepository`; it never writes schedule data and owns no tables. No migration was required.
- Overlaps are reported, not silently rejected, matching the existing routine behavior.

Known gaps:

- Drag-and-drop move/resize is not implemented; edits go through the block editor dialog.
- No recurring-event editing from the timeline beyond the existing weekday/date block kinds.
- Week/month activity counts include routine blocks and executions only (obligations are generated per day and are excluded from the month projection for cost).
- Calendar visuals were verified in Chromium at phone width; wide-window capture in this environment is affected by a Flutter Web DPR sizing artifact (see handoff).

Validation: `test/calendar_layout_test.dart` (lanes, gaps, totals, conflicts, week/month grids), `test/calendar_repository_test.dart` (merged read model, single source per record, day/week/month loading) and `test/calendar_widget_test.dart` (no overflow at 390 and 1440).
