# GitHub Copilot Instructions — Orva

Read repository-root AGENTS.md before editing. It is the canonical source of engineering constraints.

For non-trivial work consult PROMPT_MASTER.md, .agents/skills/orva-engineering/SKILL.md, docs/agents/CURRENT_STATE.md, docs/product/PRODUCT_VISION.md, docs/product/ROADMAP.md, and the relevant docs/specs/ contract.

- Existing stack: Flutter/Dart, Riverpod, Drift/SQLite. Inspect before changing architecture.
- Preserve local-first and offline-capable core behavior.
- Reuse existing records as the source of truth; never duplicate an activity across modules.
- Planned time is not completed time. Missing records are unknown unless an explicit rule establishes otherwise.
- Protect journal, notes, health, finance, and behavioral data. Never expose private content in logs or widgets.
- Every Drift schema change requires version increment, forward migration, migration tests, and backup compatibility review.
- UI copy is pt-BR; code and agent documentation are English by default.
- Add regression tests and run relevant Flutter checks. Report only checks actually executed.
- Do not implement lower-priority future modules in an unrelated task.
- Never reset databases, overwrite user changes, force-push, or silently rewrite history.

Binding decisions:
- Fixed Beto + Alfredo pair with customizable presentation and traits.
- Android widgets first; iOS later.
- Missions are both manual and integrated with source records.
- Follow docs/product/ROADMAP.md.
