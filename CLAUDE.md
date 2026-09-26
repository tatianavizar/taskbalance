# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

**50/50** — a Rails web prototype for a mobile app that makes invisible domestic mental load visible. Mission: give women factual data on task distribution in their household.

Full product documentation is at `~/Desktop/50-50-app/`. Before making product decisions, read it — especially `project/02_produit/` and `project/04_tech/`.

**Tone rule (non-negotiable):** the product is feminist in message, universal in execution. Factual and direct. Never soften stats or protect a failing partner from the discomfort of the numbers. Apply the filter: "would we write this for an engaged masculine brand?" — if not, rephrase.

## Repository location

The app lives at `~/code/taskbalance`. It previously sat directly in `/Users/tatiana`, which meant the git root was the home directory: `git add -A` would have staged `~/.ssh/id_ed25519`, shell history and personal files, and rubocop/brakeman/Tailwind all scanned the whole home tree (the Tailwind build alone took ~60s; it is now ~70ms). Moving it also un-merged `public/` from macOS's `~/Public` share folder, which the case-insensitive filesystem had been treating as the same directory. Do not move it back.

`.gitignore` blocks private keys, `.env*`, `.npmrc`, `.ssh/` and `*.key`/`*.pem`. Two files are tracked deliberately: `config/credentials.yml.enc` (encrypted, useless without the ignored `config/master.key`) and `.kamal/secrets` (stock template, shell references only).

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
| `Chore` | A chore belonging to a Household. `task_id` optional: set = catalogue chore, `nil` = **custom chore** (uses `custom_name` + `category`). Assignee is `assigned_to_id` (not `user_id`). `status` enum (`pending`/`in_progress`/`completed`). Carries its own `mental_load` / `execution_load` booleans, `time_required`, `due_date`. |
| `ChoreLog` | One completion of a Chore by a User. Holds the two load dimensions (`mental_load`, `execution_load`), `time_spent`, `completed_at`. This is the raw behavioural record. `chore_id` and `household_id` are **nullable** and nullified on delete; `user_id` is not. `chore_name` and `category` are snapshotted at creation so a detached log stays readable. |
| `RecurringChore` | Template that spawns Chores. `frequency` enum (`daily`/`weekly`/`monthly`/`annually`), `active` flag. |
| `Invitation` | Pending household invite by email. Unique per email+household, `token` generated on create. |
| `LikedTask` | User preference for a Task — `liked` boolean. Used for task assignment suggestions. |

Key relationship: `User → has_many :chores, through: :households` — a user sees all chores for every household they belong to, not just personally assigned ones.

**`task_id` is nullable — always account for custom chores.** Any code that does `chores.pluck(:task_id)` or `chores.map(&:task)` gets a `nil` for every custom chore. This has already caused a silent data-loss bug and a 500; scope with `where.not(task_id: nil)` when you mean catalogue chores only.

**Still missing from schema:** streak/level tracking; the 4-week imbalance block.

## Data ownership rule (architectural constraint)

Logs belong to the individual. The household is a calculated aggregate. When a user leaves a household, their logs follow them. This is a security/legal decision, not just a design choice — see `~/Desktop/50-50-app/project/04_tech/securite.md`.

**Enforced in the schema.** `chore_logs.chore_id` and `household_id` are nullable with `on_delete: :nullify`; `user_id` is `NOT NULL`. Destroying a chore or a whole household detaches its logs instead of deleting them, and `ChoreLog` snapshots `chore_name`/`category` on create so a detached log still says what was done. Covered by `test/models/chore_log_test.rb`. Do not reintroduce `dependent: :destroy` on either association.

## Commands

```bash
bin/dev                          # start server + Tailwind watcher (Procfile.dev)
bin/rails server                 # server only
bin/rails test                   # full test suite
bin/rails test test/models/user_test.rb      # single file
bin/rails test test/models/user_test.rb:15   # single test by line
bin/rubocop                      # lint (rubocop-rails-omakase)
bundle exec brakeman             # security static analysis
bin/rails db:migrate
bin/rails tailwindcss:build      # compile Tailwind once
```

## CSS — dual setup

Two stylesheet pipelines coexist:

- **Bootstrap** via `application.scss` → partials in `assets/stylesheets/components/` and `pages/`
- **Tailwind** via `application.tailwind.css` → utility classes

**Only Tailwind is actually loaded.** `layouts/application.html.erb` links `tailwind` and `inter-font` — `application.scss` is never referenced, so every Bootstrap class in the existing views (`btn`, `form-control`, `list-group`, `badge`…) is inert. Write new markup in Tailwind.

**No JavaScript is loaded either** — the layout has no `javascript_importmap_tags`, so Turbo is absent. Use real form submits (`button_to`, `form_with`) and plain links. `link_to ... data: { turbo_method: :delete }` silently issues a GET; several views still do this and their delete links do nothing.

## Known issues

- ~~Gem directory partly root-owned~~ — **fixed.** A past `sudo gem install` had left root-owned files under `/opt/homebrew/lib/ruby/gems/3.4.0`, making `bundle install` fail with `Bundler::PermissionError`. Resolved with `sudo chown -R "$(whoami)":admin /opt/homebrew/lib/ruby/gems/3.4.0`. Gems now install to the Homebrew prefix again; if the error ever returns, that chown is the fix.
- `HouseholdsController#destroy` lets any member delete a shared household outright, with no confirmation beyond the UI dialog and no transfer of ownership.
- `Households::LikingSessionsController#update` writes a `LikedTask` for any `task_id` posted, without checking the task belongs to the household.
- `TasksController#index` is a read-only catalogue. Chores are added to a household via `households/chores_setup`.
