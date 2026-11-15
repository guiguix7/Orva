---
name: orva-engineering
description: Use for any Orva engineering work including feature implementation, reviews, Flutter architecture, Drift migrations, Android widgets, calendar/time blocking, Beto vs Alfredo comparisons, missions, gamification, and analytics.
---

# Orva Engineering Skill — Claude Code Adapter

This is the Claude-native skill entry point. The canonical, complete workflow is shared across agents at:

~~~text
.agents/skills/orva-engineering/SKILL.md
~~~

When this skill is invoked:
1. Read repository-root AGENTS.md.
2. Read the complete canonical skill at .agents/skills/orva-engineering/SKILL.md.
3. Read PROMPT_MASTER.md and docs/agents/CURRENT_STATE.md.
4. Load the relevant product/feature specifications.
5. Follow the canonical skill exactly; do not maintain a separate Claude-only implementation policy.

Do not copy the full skill into this file. Keeping one canonical body prevents divergence between Claude Code, OpenCode, and AGENTS-compatible tools.
