# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

**50/50** — a Rails web prototype for a mobile app that makes invisible domestic mental load visible. Mission: give women factual data on task distribution in their household.

Full product documentation is at `~/Desktop/50-50-app/`. Before making product decisions, read it — especially `project/02_produit/` and `project/04_tech/`.

**Tone rule (non-negotiable):** the product is feminist in message, universal in execution. Factual and direct. Never soften stats or protect a failing partner from the discomfort of the numbers. Apply the filter: "would we write this for an engaged masculine brand?" — if not, rephrase.

## Core mechanic

- The **household** is the entity that progresses, not individuals.
- Individual contribution is always visible.
- Household progression **blocks** after 4 weeks of persistent imbalance.
- Each task log tracks two independent dimensions: **mental load** (plan/organize/decide) and **execution load** (physically doing it).

## Domain model

| Model | Role |
|---|---|
| `User` | Devise-authenticated. `role` integer enum. A user belongs to one or more households. |
| `Household` | A home/group. Aggregates calculated from individual logs — never stores raw behavioral data directly. |
| `HouseholdMember` | Join table — unique per user+household pair. |
| `Task` | A task from the pre-defined catalogue. `name`, `time_required` (default duration in minutes), `priority` (1–5). |
| `Chore` | An instance of a Task assigned to a Household. Optional `user_id` = who is assigned. `status` integer (0 = pending). |
| `LikedTask` | User preference for a Task — `liked` boolean. Used for task assignment suggestions. |

Key relationship: `User → has_many :chores, through: :households` — a user sees all chores for every household they belong to, not just personally assigned ones.

**Missing from schema (to implement):** mental load vs execution load distinction per log; streak/level tracking; recurring task support.

## Data ownership rule (architectural constraint)

Logs belong to the individual. The household is a calculated aggregate. When a user leaves a household, their logs follow them. This is a security/legal decision, not just a design choice — see `~/Desktop/50-50-app/project/04_tech/securite.md`.

## Commands

```bash
bin/dev                          # start server + Tailwind watcher (Procfile.dev)
bin/rails server                 # server only
bin/rails test                   # full test suite
bin/rails test test/models/user_test.rb      # single file
bin/rails test test/models/user_test.rb:15   # single test by line
bin/rubocop                      # lint (rubocop-rails-omakase)
brakeman                         # security static analysis
bin/rails db:migrate
bin/rails tailwindcss:build      # compile Tailwind once
```

## CSS — dual setup

Two stylesheet pipelines coexist:

- **Bootstrap** via `application.scss` → partials in `assets/stylesheets/components/` and `pages/`
- **Tailwind** via `application.tailwind.css` → utility classes
- Both loaded in `layouts/application.html.erb` alongside `inter-font.css`

Prefer Tailwind utilities for new layout work; Bootstrap components (modals, alerts) are already imported.

## Known bugs to fix

- `Chore` status is stored as an integer but validated against string values — validation is broken.
- `LikedTasksController#create` references non-existent class `Like` instead of `LikedTask`.
- `PagesController#dashboard` has dead code (`current_user = @user`, misuse of `tasks.empty?`) — needs auth guard and correct chore scoping.
- `ChoresController` has a dead `initializer` stub and duplicated logic between `create` and `add`.
- `household_members_params` method name typo in `HouseholdMembersController` (missing the `_params` suffix convention — the permit call is unreachable).
