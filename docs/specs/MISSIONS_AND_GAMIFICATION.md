# Feature Specification — Missions, XP, Levels, Achievements, Prestige

Status: SPECIFIED; existing checklists are a reusable foundation, but a complete mission/gamification domain was not established in the 2026-10-30 audit.

Priority: missions P1; XP/levels and achievements/prestige P2.

## 1. Product model

A mission is a bounded objective with a period, rules, and completion state.

### Manual mission
The user explicitly marks the mission or its steps complete. Record the user action and timestamp.

### Integrated mission
Progress is calculated from existing Orva records. Examples: configured study minutes, completed checklist occurrences, hobby sessions, eligible completed routine blocks, or habit quantity. Integrated missions must not ask users to enter the same activity twice.

## 2. Cadence and occurrence identity

Required recurrence:
- daily;
- weekly;
- monthly;
- yearly.

Each period creates a stable occurrence. Recommended period keys:
- daily: mission ID + local date;
- weekly: mission ID + week-start date;
- monthly: mission ID + year-month;
- yearly: mission ID + year.

Default week start is Monday for pt-BR unless settings override. Centralize calendar policy; do not duplicate recurrence logic across screens.

## 3. Mission definition

A mission may include:
- ID, title, description;
- cadence/recurrence configuration;
- active start/end;
- manual or integrated mode;
- typed criteria for integrated mode;
- optional steps;
- category and linked goal;
- reward configuration;
- active/archived status;
- timestamps.

An occurrence includes stable ID, mission ID, local period start/end, status, manual completion timestamp or derived progress, source evidence summary, reward state, and audit timestamps.

Do not generate an occurrence per app open or calculation refresh.

## 4. Integrated criteria

Criteria must be typed and explicit:
- count of sessions >= N;
- sum of duration minutes >= N;
- count of completed checklist items >= N;
- habit quantity >= target;
- count of distinct eligible days >= N.

Each criterion defines source entity type, optional subject/category, period scope, aggregation operator, threshold/unit, duplicate handling, and deletion/correction behavior.

Avoid arbitrary SQL rule builders. Start with a small typed criteria set.

## 5. Completion and recurrence semantics

- Manual completion is a user action and remains distinguishable from auto completion.
- Integrated progress is recomputable from authoritative source records.
- An occurrence completes at most once.
- If later correction drops progress below threshold, define a policy. Recommended: current occurrence may return to in-progress and any reward adjustment is recorded, not silently erased.
- A missed daily occurrence does not block the next day.
- Archive stops future occurrences but preserves history.
- Criteria/recurrence edits affect future occurrences by default; historical ones retain the old rule version/snapshot.
- Define local timezone and period boundaries centrally.

## 6. XP and levels

XP is a progression currency, separate from Beto/Alfredo score.

Potential sources: mission completion, meaningful goal milestone, configured eligible activity session, achievement unlock.

Rules:
- never reward app opens, page views, duplicate taps, unverified plans, or repeated recalculations;
- every reward has an idempotent source key;
- define source deletion/correction behavior;
- preserve reward history;
- cap repeatable rewards when farming is possible;
- centralize reward values rather than scattering constants in widgets.

Level progression becomes progressively harder. Exact curve, starting XP, max/soft cap are product decisions. Put them in a central tested policy, not UI code. Display level, total XP, XP to next level, and explainable history.

## 7. Achievements and prestige

Achievements are one-time or tiered milestones with explicit criteria. Examples: first mission, first weekly mission, 10 study sessions, 100 hours of eligible activity, first major goal.

Prestige is a title/status layer earned through meaningful milestones. It must not reset or erase source records. Do not create public competition by default.

## 8. Healthy gamification constraints

No punishment for rest, illness, schedule changes, or missed sessions. Allow pause/archive/adjustment. Do not equate XP with human value. Do not reward excessive exercise, restrictive eating, sleep deprivation, or compulsive tracking. Avoid shame language and streak-loss pressure.

## 9. Acceptance criteria

1. Manual and integrated missions work.
2. Daily/weekly/monthly/yearly boundaries create unique occurrences.
3. Integrated progress uses source records without duplicate input.
4. Recompute/retry/widget interaction does not duplicate completion or XP.
5. Archive/edit preserves history.
6. Correction/deletion policy is implemented/tested.
7. XP and comparison score are separate.
8. Level formula is centralized and tested.
9. Achievement criteria are deterministic/auditable.
10. Pause/rest behavior is non-punitive.
