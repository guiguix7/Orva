# Orva Agent Documentation

This directory defines how coding agents understand, plan, implement, test, and hand off Orva work.

## Start here

1. Repository policy: AGENTS.md
2. Master task prompt: PROMPT_MASTER.md
3. Reusable workflow: .agents/skills/orva-engineering/SKILL.md
4. Verified source snapshot: CURRENT_STATE.md
5. Product intent: docs/product/PRODUCT_VISION.md
6. Priority order: docs/product/ROADMAP.md
7. Task brief: TASK_TEMPLATE.md
8. Completion gates: docs/quality/DEFINITION_OF_DONE.md

## Agent entry points

| Agent/tool | Entry file |
|---|---|
| Codex and AGENTS-compatible agents | AGENTS.md |
| Claude Code | CLAUDE.md and .claude/skills/orva-engineering/SKILL.md |
| GitHub Copilot | .github/copilot-instructions.md |
| Cursor | .cursor/rules/orva.mdc |
| Gemini CLI | GEMINI.md |
| OpenCode | .agents/skills/orva-engineering/SKILL.md |
| Other coding agents | AGENTS.md and PROMPT_MASTER.md |

Adapters point to shared canonical rules. Do not let tool-specific files drift into conflicting product decisions.

## Feature specifications

- docs/specs/COMPARISON_SYSTEM.md
- docs/specs/ANDROID_WIDGETS.md
- docs/specs/CALENDAR_TIME_BLOCKING.md
- docs/specs/MISSIONS_AND_GAMIFICATION.md
- docs/specs/PROGRESS_ANALYTICS.md
- docs/architecture/ACTIVITY_AND_PROGRESS_ARCHITECTURE.md

## Document authority

When documents disagree:
1. Current source code, schema, migrations, and tests establish what exists.
2. AGENTS.md establishes non-negotiable engineering policy.
3. Product vision and roadmap establish approved direction and priority.
4. Feature specifications establish intended behavior.
5. README and historical planning documents are secondary summaries.

Do not change product decisions or weaken privacy rules for implementation convenience. Record unresolved decisions instead of inventing requirements.

## Maintenance

Update CURRENT_STATE.md when code status changes. Update feature specifications when behavior changes. Update ROADMAP.md only when product priority/scope changes. All status claims require inspected code or executed validation evidence.
