# Feature Specification — Consistency and Progress Analytics

Status: PARTIALLY IMPLEMENTED. The Home has a tested rolling seven-day activity chart and life-area summaries; a complete historical analytics experience was not established.

Priority: P1 — Very urgent.

## 1. Goal

Help users understand what they planned, what they actually did, where progress occurred, and what changed over time. Charts are decision-support, not decorative activity counters.

## 2. Required areas

### Consistency
- activity heatmap;
- eligible opportunities;
- completed eligible actions;
- current/best sequence when meaningful;
- scheduled/rest/excluded days;
- daily, weekly, monthly trend.

### Time
- planned versus actual minutes;
- time by category/activity;
- unplanned actual time;
- overlap and unused planned blocks.

### Goals and missions
- active goals/deadlines;
- manual versus record-derived progress;
- completed/expired/paused missions;
- comparable period trends.

### Behavioral comparison
- Beto/Alfredo scores over time;
- assessed traits and coverage;
- trait changes;
- period and rule version.

### Future modules
Workout and finance charts require approved source models and metrics. Do not create decorative empty charts for unimplemented modules.

## 3. Metric contract

Every metric declares:

~~~text
MetricDefinition
- metricId
- displayName
- sourceTypes
- numeratorDefinition
- denominatorDefinition
- period/window
- eligibleDayRules
- exclusions
- unit
- aggregation
- missingDataPolicy
- correctionPolicy
~~~

Do not implement a chart before its metric formula is documented and tested.

## 4. Consistency formula

Recommended initial definition for scheduled behavior:

consistency = completed eligible opportunities / total eligible opportunities

Rules:
- Count only opportunities the user elected to track.
- Exclude configured rest days and intentionally paused periods.
- Explicit scheduled skips/non-completion may count as incomplete according to that metric's policy.
- Unscheduled days and missing data are not automatic failures.
- Never count app opens.
- Show numerator and denominator, e.g. “4 of 5 planned sessions”, not only “80%”.
- If denominator is zero/data insufficient, show “not enough data”.
- Do not combine unrelated behaviors into one unexplained number.

Habits without scheduled opportunities require their own frequency/quantity target rules.

## 5. Time analytics

- Planned time comes from routine/obligation/meal-plan blocks.
- Actual time comes from execution or a domain session with real start/duration.
- Do not sum an execution and a domain session if they represent the same activity; define source precedence or linked-record deduplication.
- Split overnight intervals by local date without duplicating total duration.
- Overlapping planned blocks must not inflate occupied time.
- Label planned, recorded, and estimated values distinctly.

## 6. Period comparison

Support day, week, month, rolling 7 days, rolling 30 days, and custom range where useful. Compare equal-length or equivalent calendar periods. Label incomplete current periods. Do not compare a partial month to a full previous month without qualification.

## 7. Chart requirements

Every chart names metric and time range, provides units/readable axes, handles empty/partial/error states, offers detail on tap where useful, supports themes/text scaling, includes accessible textual summary/semantics, and avoids misleading scales/animation. Use the same calculation service as summaries/widgets.

## 8. Acceptance criteria

1. Each chart has documented metric formula.
2. Every point traces to supported source records.
3. Missing data is not silently rendered as zero.
4. Planned and actual time are distinct.
5. Rest days/paused periods follow policy.
6. Period boundaries are tested.
7. Source correction updates projections predictably.
8. Charts work on small screens and with assistive technology.

## 9. Implemented Home metrics

### Rolling seven-day activity

- Window: seven local calendar days including today (`today - 6` through `today`), not a Monday-first calendar week.
- Numerator: per day, `execution_minutes` from `executions.reference_date` excluding executions whose `reference_type` is `study` or `hobby`, plus `study_sessions.duration_minutes` by `session_date`, plus `hobby_sessions.duration_minutes` by `session_date`.
- Exclusions: planned routine blocks, obligations and meal plans are not executed activity. A study or hobby session represented by a linked execution is counted once through the domain-session source.
- Unit: minutes. Days with no record render as empty, not as a fabricated zero-value bar or failure.
- Total: sum across the seven days. Active days: days with total minutes greater than zero. Average: total divided by active days, not by seven.
- Interpretation text and the source definition are shown with the chart. The current day is labelled `hoje`; the partial current day is disclosed (`Hoje ainda está em andamento`); the range is labelled `ÚLTIMOS 7 DIAS`.
- Implementation: `lib/core/domain/home_dashboard.dart` (`buildWeeklyActivity`), `WeeklyActivityCard`, with source queries `executionMinutesByDay`, `studyMinutesByDay` and `hobbyMinutesByDay`.

### Weekly hobby summary

- Window: current local Monday through Sunday, matching the Hobbies module; the current week is labelled as in progress.
- Per hobby: session minutes and session count inside the window, optional weekly target, progress only when recorded minutes are greater than zero and a target exists.
- Empty state: a configured hobby with no session this week is shown neutrally as no recorded session; the card does not invent progress.
- Implementation: `getWeeklyHobbyMinutes` and `HobbiesCard`.

### Beto vs Alfredo summary

- Uses the selected comparison period and the same trait rules, per-trait windows, measurement sources and `summarizeComparison` projection as the Comparison page.
- Shows assessed/unknown coverage and the period, including `até hoje` or `em andamento` when the window has not closed. It shows a result only when assessed evidence exists; missing records remain unknown.
- Implementation: `getComparisonDigest` and `ComparisonSummaryCard`.
