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
- Household progression goes through levels 1–4 then an ultimate level, earned by cumulative **balanced weeks** (1, 3, 6, 10, 15). A week is balanced when every member carries their fair share (100 / members, rounded) ± 10 points of **both** mental load and execution. An unbalanced week only stops progression.
- The household **regresses one level and is blocked** when a member logs nothing for 2 consecutive weeks, unless the other members answer that they were away (a pause is then declared for them). A member can declare as many pauses as they want, and paused weeks don't count. Full rules: `docs/backend-backlog.md`.
- Each task log tracks two independent dimensions: **mental load** (plan/organize/decide) and **execution load** (physically doing it).

## Domain model

| Model | Role |
|---|---|
| `User` | Devise-authenticated. `role` integer enum. Currently `has_many :households`, but the V1 rule is **one household per account** (decision 2026-11-08); the schema change is planned in `docs/plan-de-travail.md`, lot 1. |
| `Household` | A home/group. `name` required (max 60), `time_zone` (default `Europe/Paris`, the creator's zone at creation). Create with `Household.create_for(user, attrs)` (makes the creator `manager`). Aggregates calculated from individual logs — never stores raw behavioral data directly. |
| `HouseholdMember` | Join table — **unique per user** (one household per account, unique index). `role` enum `member`/`manager` (the creator is manager; `leave!` hands the role to the oldest remaining member). `color` (mint, blue, stone, sky, sage, sand — unique in the household, auto-assigned in that order, editable), `monogram` (initial of the first name; two letters, initial + last letter, only when two initials coincide; recomputed on each arrival unless `monogram_customized`). Max 6 members. |
| `Task` | A task from the pre-defined catalogue. `name`, `time_required` (default duration in minutes), `priority` (1–5). |
| `Chore` | A chore belonging to a Household. `task_id` optional: set = catalogue chore, `nil` = **custom chore** (uses `custom_name` + `category`). Assignee is `assigned_to_id` (not `user_id`). `status` enum (`pending`/`in_progress`/`completed`). Carries its own `mental_load` / `execution_load` booleans, `time_required`, `due_date`. |
| `ChoreLog` | One completion of a Chore by a User. Holds the two load dimensions (`mental_load`, `execution_load`), `time_spent`, `completed_at`. This is the raw behavioural record. `chore_id` and `household_id` are **nullable** and nullified on delete; `user_id` is not. `chore_name` and `category` are snapshotted at creation so a detached log stays readable. |
| `RecurringChore` | Template that spawns Chores. `frequency` enum (`daily`/`weekly`/`monthly`/`annually`), `active` flag. |
| `Invitation` | Pending household invite by email. Unique per email+household, `token` generated on create. |
| `LikedTask` | User preference for a Task — `liked` boolean. Used for task assignment suggestions. |

Key relationship: `User → has_many :chores, through: :household` — a user sees all chores of their household, not just personally assigned ones.

**`Week`** (`app/models/week.rb`, not persisted): `Week.containing(time_or_date, time_zone)` gives Monday 00:00 → Sunday 23:59:59 in that zone (`start_at`, `end_at`, `range`, `date_range`), the ISO number (`number`, `label` = "Semaine 41"), `previous`/`next`. `household.current_week` / `week_containing`. Every weekly computation must go through it, never through UTC.

**Mail config:** `config/initializers/00_mail.rb` reads SMTP settings (`SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USER_NAME`, `SMTP_PASSWORD`, `SMTP_DOMAIN`, ...) from the ENV or `credentials.smtp`; sender from `MAIL_FROM` (default `50/50 <bonjour@cinquante.app>`); links use `APP_HOST`.

**`task_id` is nullable — always account for custom chores.** Any code that does `chores.pluck(:task_id)` or `chores.map(&:task)` gets a `nil` for every custom chore. This has already caused a silent data-loss bug and a 500; scope with `where.not(task_id: nil)` when you mean catalogue chores only.

**Weekly engine (lot 5a).** Interfaces and rules are documented at the top of each file:
- `WeeklyStats.new(household, week)` (`app/models/weekly_stats.rb`, not persisted): per-member counts and integer % shares of mental and execution logs, `fair_share`, `zone`, `outcome` (`:balanced`/`:unbalanced`/`:neutral`) and `neutral_reason`. The zone judges the exact share (`*_share_exact`, Rational); `*_share` is the rounded display value. The single source of every figure: home screens read it live for the current week, past weeks come from `HouseholdWeek`.
- `HouseholdWeek` (`household_weeks`): snapshot of `WeeklyStats` per household and week (first names and pauses included), `provisional` from Sunday 20:00, `final` from Monday 03:00 local. A final row is `readonly?`: never rewrite it.
- `WeeklyEngine` (`app/services/`), run every 15 min by `WeeklyEngineJob` (`config/recurring.yml`): finals with catch-up, provisional, empty-week streaks (`household_members.empty_weeks_streak`), `AbsenceInquiry` and its Wednesday 20:00 deadline, regression and block, levels (`households.level` 0–5, `balanced_weeks_count`, `state`, `LevelChange` history, `ultimate_reached_on`). Level logic in `Progression`, numbers in `HouseholdRules`.
- `MemberPause` (`member_pauses`, `declared_by_id`): retroactive limits; creating one resolves a pending absence inquiry.
- Open seams: `TODO(D3)` in `WeeklyEngine#retroactive_pause_on_final_weeks` (does nothing), (D5 decided 2026-11-12: the ultimate ratio runs from `households.ultimate_reached_on`, capped at 52 weeks, see `Progression`). Every rule number lives in `HouseholdRules`. Not built yet: absence answers and the question itself (lot 5b), notifications (lot 8).

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

## Front — assets, composants, mobile

- **Un seul pipeline : Propshaft.** Bootstrap, Sass, font-awesome, simple_form et Sprockets sont retirés. Le CSS est du Tailwind v4 (`app/assets/tailwind/application.css`) : tokens du design system dans `@theme`, classes de composants (`.btn`, `.field-*`, `.card`, `.callout`, `.alert-box`, `.tab-bar`…).
- **JavaScript par importmap** (Turbo + Stimulus). `app/javascript/confirm_dialog.js` remplace la boîte `confirm()` de Turbo par une feuille `<dialog>`.
- **Formulaires :** `FiftyFormBuilder` (`app/form_builders/`) est le builder par défaut (`field`, `select_field`, `checkbox_field`, `switch_field`, `segmented`, `error_summary`, `submit`).
- **Composants :** helpers dans `app/helpers/components_helper.rb`, partials dans `app/views/components/`. Ils prennent des valeurs simples, sans logique métier. Catalogue visuel sur `/styleguide` (développement et test seulement).
- **Layout mobile :** en-tête et barre d'onglets masqués pour les coquilles Hotwire Native (`hotwire_native_app?`) et quand la vue fait `provide :chrome, "none"`. Le foyer courant passe par `current_household` (`ApplicationHelper`).
- **Hotwire Native côté serveur :** `/configurations/ios_v1.json` et `android_v1.json` (`ConfigurationsController`). `allow_browser` n'est pas appliqué aux requêtes natives.
- **Erreurs :** `config.exceptions_app = routes`, `ErrorsController` (404, 403, 422, 500) en français.

## Known issues

**Backend work to match the mockups is tracked in `docs/backend-backlog.md`** (prioritised, with the product rules it implements). Mockups, user journey, UX rules and service blueprint live on the Design canvas https://claude.ai/artifact/KmQFCsbQNFrSTRtzDnc1FN.

- ~~Gem directory partly root-owned~~ — **fixed.** A past `sudo gem install` had left root-owned files under `/opt/homebrew/lib/ruby/gems/3.4.0`, making `bundle install` fail with `Bundler::PermissionError`. Resolved with `sudo chown -R "$(whoami)":admin /opt/homebrew/lib/ruby/gems/3.4.0`. Gems now install to the Homebrew prefix again; if the error ever returns, that chown is the fix.
- `HouseholdsController#destroy` lets any member delete a shared household outright, with no confirmation beyond the UI dialog and no transfer of ownership.
- `Households::LikingSessionsController#update` writes a `LikedTask` for any `task_id` posted, without checking the task belongs to the household.
- `TasksController#index` is a read-only catalogue. Chores are added to a household via `households/chores_setup`.
