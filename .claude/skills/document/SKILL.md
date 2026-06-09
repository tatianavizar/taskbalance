---
description: Update CLAUDE.md with current technical and product context. Use when creating or refreshing documentation for the project, or after adding new features, models, or product decisions.
argument-hint: "[section to update]"
allowed-tools: Read Bash(find *) Bash(ls *) Bash(cat *) Write Edit
---

## Current CLAUDE.md
!`cat CLAUDE.md 2>/dev/null || echo "(no CLAUDE.md yet)"`

## Existing product docs on desktop
!`ls ~/Desktop/50-50-app/project/ 2>/dev/null || echo "(not found)"`

---

Discover, then document. Never write before reading.

1. **Discover** — read `~/Desktop/50-50-app/` (product mission, mechanics, tech constraints) and any `README.md` or `docs/` in the repo. Summarize what you find before touching CLAUDE.md.

2. **Update CLAUDE.md** to include:
   - Product mission and non-negotiable tone rules
   - Domain model with relationships and architectural constraints from product/legal decisions
   - Dev commands (build, single test, lint)
   - Non-obvious CSS/asset setup
   - Known bugs already identified in the code

3. **Do not include:** generic Rails advice, obvious conventions, or anything `ls` makes self-evident.
