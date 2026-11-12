# Backend backlog

What the Rails app must do to match the mockups and the service blueprint. Ordered by priority. Each item has its value, its effort for one developer (S = under half a day, M = 1–3 days, L = more than 3 days) and what "done" means.

**Sources:**
- Mockups, user journey, UX rules and service blueprint are on the Design canvas: https://claude.ai/artifact/KmQFCsbQNFrSTRtzDnc1FN. Screen IDs below (A1, D6…) refer to its "Écrans" page.
- The product rules marked *(hypothesis)* were inferred from the code, because the product docs folder named in `CLAUDE.md` does not exist. Have them validated before building on them.

## Product rules the backend implements

Validated by the product owner on 2026-11-08 unless marked *(default)*.

- **The week:** Monday 00:00 to Sunday 23:59 in the household's time zone.
- **Fair share:** 100 / number of **active** (non-paused) members, rounded. Shares are compared with the zone **unrounded**; rounding is for display only, so 39.5 % is out of 40–60 % (decision 2026-11-12). A member is in the zone when their share of the week's **mental-load** logs **and** their share of **execution** logs are each the fair share ± 10 points:
  - 2 members: 40–60 %.
  - 3 members: 23–43 %.
  - 4 members: 15–35 %.
- **Balanced week:** every active member is in the zone on both dimensions. Time is shown but does not count.
- **Neutral week:** no mental-load log or no execution log that week, or fewer than 2 active (non-paused) members. It is neither balanced nor unbalanced; nothing moves.
- **Unbalanced week:** the household does not progress. It is **never** a cause of regression or blocking, except at the ultimate level, which drops back to level 4 below 85 % (see below).
- **Levels:** reached by cumulative balanced weeks.

  | Level | Total balanced weeks | Added |
  |---|---|---|
  | 1 | 1 | +1 |
  | 2 | 3 | +2 |
  | 3 | 6 | +3 |
  | 4 | 10 | +4 |
  | Ultimate | 15 | +5 |

- **Keeping the ultimate level:** it holds while more than 85 % of the final weeks are balanced, counted from the week the household **first reached** the ultimate level, over 52 weeks at most (decision 2026-11-12). Neutral weeks are excluded. Below 85 %, the household goes back to level 4, and it gets the ultimate level back automatically as soon as the ratio is above 85 % again.
- **Non-logging:**
  - A member with **zero logs for 2 consecutive weeks** makes the household regress one level, and its progression is blocked.
  - Each member is warned after the first week at zero (E3).
  - At the second week at zero, before any regression, **every member, the absent one included, is asked whether that member was away** (E11, P5). One "Yes" from anyone is enough to declare the pause (product decision 2026-11-08). Answers are accepted until Wednesday 20:00 (see 2.1).
    - "Yes": a pause is declared on their behalf for those weeks, so no regression.
    - "No", or no answer: the regression and the block apply.
    - The member concerned is notified of the answer and can correct it.
  - After a regression, any member can still declare a pause for the absent member over the empty weeks, until the next final report. This cancels the regression and the block *(default)*.
- **Assignees:** every task has at least one assignee; several members can share a task (see 2.2). "Pour le foyer" was dropped (2026-11-08). Any member can still log any task.
  - After a regression, the cumulative counter is set to the threshold of the new level *(default)*.
- **Unblocking:** a week in which every active member logs at least one task *(default)*.
- **Pauses:** any member can declare a pause (start date, optional end date), as many times as they want.
  - The dates are visible to every member; the reason is optional and private *(default)*.
  - Paused weeks never count as empty weeks for that member. A pause neutralises every week it touches, even by one day (decision 2026-11-12).
  - A paused member is not an active member, so a two-person household with one member paused has neutral weeks *(default)*.
- **Blocking freezes progression only.** Logging, reports and editing the split stay available.
- **Logs:** a member only logs what they did themselves. A log's author is always `current_user`.
- **Invitations:**
  - Valid 14 days *(hypothesis)*.
  - Nobody joins a household without accepting, including existing accounts.
- **Household manager:** the creator. Only the manager can delete the household. When the manager leaves, the oldest remaining member becomes manager.
- **Data ownership** (existing rule, see `CLAUDE.md`):
  - Logs belong to their author and survive household deletion or departure.
  - Deleting a log or cancelling an invitation asks for confirmation first (E16, B15).
- Weekly reports, once final, are never rewritten. Until then, every report screen shows "Provisoire · définitif lundi … à 3:00"; afterwards "Définitif · clos le …" (E1, E14, P4).

## Priority 1: quick fixes (makes the prototype usable by two people)

### 1.1 Invitations crash with a 500 — critical, S
`Invitation` validates `token` presence, but the token is generated in `before_create`, which runs after validation. So every invite to a new email raises in `HouseholdMembersController#send_invitation` (`save!`).

**Fix:** generate the token in `before_validation on: :create`. Add a model test and a controller test for inviting an unknown email.

### 1.2 Remove "Fait par" (logging on behalf of someone else) — critical, S
`Chores::CompletionsController` permits `:user_id`, and the form offers every member.

**Fix:**
- The log's user is always `current_user`. Remove the field and the param.
- Test that a posted `user_id` is ignored.

**Screens:** D6, D7.

### 1.3 Email delivery — critical, S
SMTP is not configured: the production host is `example.com`, the Devise sender is the default placeholder and `ApplicationMailer` sends from `from@example.com`.

**Fix:**
- Read SMTP settings and the sender address from credentials or ENV, and set `default_url_options`.
- Pick a provider (product decision).
- **Done when:** invitation and password-reset emails leave in production.

### 1.4 Household time zone — high, S
`config.time_zone` is UTC and the household has no zone.

**Fix:**
- Add `households.time_zone` (default `Europe/Paris`), set at creation.
- Compute every week boundary inside `Time.use_zone(household.time_zone)`.

### 1.5 Navigation and logout — high, S–M
The layout renders no navigation (`shared/_navbar` is never rendered) and nothing in the UI logs out.

**Fix:**
- Add the 4-tab bar from the mockups: Accueil, Tâches, Bilan, Foyer.
- Add a logout in the account screen (F4).

### 1.6 Household name validation — medium, S
`Household` has no validations.

**Fix:** require a name of at most 60 characters, with the error message on B2.

### 1.7 First name on User — medium, S
Every screen addresses people by first name, but `User` has only an email.

**Fix:**
- Add `users.first_name` (required) to sign-up (A2) and to the invitation sign-up (B7).
- Add it to the account screen (F4).

### 1.8 Manager role — medium, S
**Fix:**
- Add `household_members.role` (`manager` / `member`); the creator is the manager.
- Prerequisite for 3.3 and 3.5.

## Priority 2: the engine (what the product is)

### 2.1 Weekly report job and table — critical, M–L
Solid Queue is installed but `config/recurring.yml` is empty and no job exists.

**Fix:**
- **Table:** `household_weeks` with
  - `household_id`, `week_start` (date, local);
  - per member: mental count, execution count, minutes (JSON or a child table `household_week_members`);
  - `status`: `provisional` / `final`;
  - `outcome`: `balanced` / `unbalanced` / `neutral`;
  - `computed_at`.
  - Unique index on `[household_id, week_start]`.
- **Two runs per week, in each household's zone:**
  - Sunday 20:00: provisional report, which drives the Sunday email and notification.
  - Monday 03:00: final report, which includes late Sunday logs and is then never changed.
- **No offline mode** (product decision 2026-11-08): without network, logging is refused with a clear message (G1); nothing is queued on the device.
- **Decisions wait for the close** (product decision 2026-11-08): the Sunday 20:00 report is provisional. Alerts, the absence question, level changes and regressions are computed from the Monday 03:00 final report and sent Monday morning. The absence question can be answered until Wednesday 20:00; without any "Yes", the regression applies then.
- **Arrival week** (product decision 2026-11-08): a week counts only if every member belonged to the household since its Monday 00:00. The week a member joins counts for nobody's level.
- **Closed weeks:** a log can be back-dated up to 7 days. If its day falls in a week whose final report is written, it is stored in the member's journal but changes neither that report nor the level *(default, 2026-11-08)*.
- **Idempotent:** keyed by household and week. On start-up, catch up any missing weeks, in order.
- **Data:** read `chore_logs` by `household_id` and `completed_at`; the indexes exist.

**Screens:** E1, E2.

### 2.2 Levels, non-logging streaks and household state — critical, M
**Fix:**
- **Columns on `households`:** `balanced_weeks_count`, `level` (0–5, where 5 is the ultimate level), `state`.
- **Per member** (on `household_members`): `empty_weeks_streak`, the number of consecutive final weeks with zero logs.
- **`state` values:**
  - `setting_up`
  - `solo`
  - `active`
  - `warned` (a member is at 1 empty week)
  - `blocked`
  - `dormant`
- **Transitions:** they happen only when a final report is written, except creation and the second member joining.
- **Ultimate level:** recomputed at each final report from the rolling 52-week window.
- **Regression:** dropping a level sets `balanced_weeks_count` to the threshold of the new level (level 3 → 2 sets it to 3) *(default, 2026-11-08)*. The block lifts at the first final week where every non-paused member logged at least one task; that week counts normally.
- **`dormant`:** no member logged anything for 3 weeks *(default, not yet validated, not shown in the mockups)*. It sends no alerts and never blocks. A household where only one member stops logging is not dormant: that is the non-logging rule.

**Screens:** D2, E3, E4, E5. The rules are at the top of this file.

### 2.2b Pauses — high, S–M
**Fix:**
- Add `member_pauses` (`household_member_id`, `starts_on`, `ends_on` nullable, `reason` private).
- Add start, end and cancel actions. A member declares their own pause; another member can declare one for an absent member when answering the absence question (E11) or after a regression (E4, F8), which cancels the regression. Notify every member of the dates.
- **Retroactive pauses are limited** (product decision 2026-11-08): only weeks where that member logged nothing, within the last 14 days. The weeks that triggered an absence question or a regression stay eligible beyond 14 days *(default)*. Cancelling a regression restores the previous level and counter value. No agreement is needed: a single declaration, by the absent member or anyone else, is enough (product decision 2026-11-08). The former agreement screen (F9) was removed.
- Exclude paused members from the active members of a week and from `empty_weeks_streak`.
- Show pauses in the weekly report: who was paused, from when to when, and why the week is neutral. Store them on `household_weeks`.

**Screens:** F6, F1.

### 2.2c Weekly proposed split and carried-over gap — high, M
**Fix:**
- Propose a split of the week's tasks every Monday, with a home card (D11) and a notification.
- **Shared tasks** (product decision 2026-11-08): a task assigned to several members counts in full for each of them. There is no "for the household" pool any more: every task has at least one assignee (multi-select).
- **Display:** the proposal shows one bar, the average of the mental and execution shares (product decision 2026-11-08). The weekly report still checks both charges separately. When one charge is in the zone and the other is not, the weekly report says so and tells the household what to change in Monday's split (educational card, E1) (product decision 2026-11-08).
- **Metric:** two shares, mental and execution, each counted in planned task occurrences for the week (a daily task counts 7 times, a weekly one once; a monthly or yearly one counts in the week it falls due) *(default, 2026-11-08)*.
- **Compensation cap:** last week's gap is compensated only within the 40–60 % zone; what exceeds it stays carried over *(default)*.
- **Gap = average of the two charges** (product decision 2026-11-08): the carried gap is measured on the mean of the mental and execution shares, so it can be compensated through either charge. A week still needs both charges in the zone to count as balanced.
- **Before the partner joins:** the creator chooses between a provisional split, recomputed when the partner gives their preferences, and waiting for them (C4).
- When the proposal cannot land exactly on the fair share, store the gap and carry it to the next week's proposal, which compensates it.
  - The gap stays as a balance until it is compensated *(default; open question: carried over several weeks, or only to the next one)*.
- When a member edits the split so that a share leaves the 40–60 % zone (or the zone for that household size), warn without blocking. Saving is still allowed, and the gap is carried over.
- **Reset to zero:** the carried gap can be reset to zero, and an out-of-zone edit can be saved without carrying it (product decision 2026-11-08). Only the member who carries the gap can reset it, from the week's split screen (C9), not from the settings (product decision 2026-11-08).
- **Split settings (C16):** every member can change them (weekly proposal on Monday, carry-over of the gap). A change takes effect only once every member has validated it (product decision 2026-11-08). Store pending changes with one approval per member. Optional **auto-validation** (off by default, 2026-11-08): when on, every proposed split applies immediately, without each member's validation.
  - Only the member the gap favours (the one who carried the surplus) can waive it *(default)*. The other members are notified.

- **Validation status** (product decision 2026-11-08): screens show only two states, "Validée par tous les deux" or "En attente de <prénom>" (C9, D11, F1, C16); no per-member history.
- **Planned share counts frequency**: a task's weight in the proposal is its occurrences per week (daily = 7); the proposal's percentages must follow from the assignments shown (C4–C14).
- **Locked once validated** (product decision 2026-11-08): the split is proposed and edited on Monday; once validated it does not change until the next Monday. The weekly report is computed on tasks actually logged, never on the plan.
- **One-off reassignment:** during the week a member can offer one of their tasks to another member (D5, D15); accepted or refused, it applies to that week only and does not change the validated split (D16).
- **Carried gap source:** the real gap of the closed week, averaged over the two charges; the plan only tries to compensate it.

**Screens:** C8, C9, C12, D11, D15, D16.

### 2.2d Several assignees per chore — medium, M
**Fix:**
- A chore can be assigned to several members (product decision 2026-11-08). Replace `chores.assigned_to_id` with a `chore_assignees` join table; at least one assignee is required.
- Each assignee logs their own completion; the split counts each assignee's planned occurrences.

**Screens:** C5, C6.

### 2.2e Households of 3 or more — medium, M
**Fix:**
- Fair share = 100 / members, zone ± 10 points (33 % and 23–43 % at three). Home, report and split show one bar per member (P3, P4, C14).
- **Absence question at 3+** (product decision 2026-11-08): same rule as at two. Every member is asked, the absent one included, and one "Yes" declares the pause. Without any "Yes" by Wednesday 20:00, the regression applies (P5).
- **Member identity:** each member picks a colour, unique in the household, from a fixed palette; the monogram is the initial, or initial + last letter of the first name when two initials collide (Karim "Km", Karine "Ke"); editable, 2 letters max (P2). Store `colour` and `monogram` on `household_members`.
- From 3 members, assignment uses a bottom sheet with checkboxes (P6), opened from one button per task that shows the current assignees (C14) (product decision 2026-11-08).

**Screens:** P1–P6, C14.

### 2.3 Home and report screens on real data — critical, M
`pages#dashboard` shows only the email.

**Fix:**
- Expose for the current week:
  - mental and execution share per member, with counts ("17 tâches sur 24");
  - time per member;
  - mental load per category;
  - the last 4 weeks.
- Every figure comes from one place: the current week is computed live, past weeks come from `household_weeks`.

**Screens:** D1, D2, D8, E1, E2.

## Priority 3: trust and consent

### 3.1 Consent for existing accounts — critical, M (done, lot 3)
`add_existing_member` adds an existing user to a household immediately, without asking.

**Fix:**
- Every addition goes through an `Invitation` the invitee accepts.
- A signed-in invitee sees an accept screen.
- Signing up from the link joins the household.
- Wrong account: B8 variant.

### 3.2 Complete invitation lifecycle — high, M (done, lot 3; the B10 to B14 screens are lot 2)
**Fix:**
- **Expiry:** add `expires_at` (14 days).
- **States:** pending, accepted, cancelled, expired.
- **Resend:** a new email, same token, expiry reset. At most 3 resends per invitation, at least 15 min between two sends (product decision 2026-11-08); the button shows the remaining wait, then the limit.
- **Cancel.**
- **Joining before the setup is finished:** the invitee's account is created, but they wait (B12) until the manager has chosen the household's tasks; they are notified when preferences and the split are ready.
- **Declining:** the invitee joins only at the last step (B11) and can decline until then. The manager sees « Invitation déclinée » (B13); the household stays solo and its setup is kept.
- **Clear errors**, replacing the silent re-render and the misleading "Invitation sent" flash:
  - own email;
  - already a member;
  - already invited.
- **Unknown or invalid token:** shown at sign-up instead of silently ignored.

**Screens:** B3–B8.

### 3.3 Leave a household — high, M
`household_members` has routes but no destroy action, so nobody can leave.

**Fix:**
- Leaving keeps the member's logs (they follow the user).
- The member's assigned chores are reassigned to the remaining member(s) and flagged for review in the next Monday split (F2). No chore is ever left without an assignee.
- The manager role passes to the oldest member.
- Weeks already final are untouched; the current week is computed without the leaver.

**Screen:** F2.

### 3.4 Retire a catalogue chore without deleting it — high, M
`Households::ChoresSetupController#update` runs `destroy_all` on unticked catalogue chores, without warning.

**Fix:**
- Add `chores.active`. Unticking deactivates the chore after a confirmation that states how many times it was logged.
- Logs stay; re-ticking reactivates the chore.

**Screens:** C1, C2.

### 3.5 Delete a household: manager only — high, S
**Fix:**
- Only the manager can delete, after typing the household name.
- Other members are emailed.
- Logs are detached (the existing `nullify` behaviour).

**Screen:** F3.

### 3.6 Delete an account — high, M
Today, destroying any user who has a membership, a log or an assigned chore raises a foreign-key error (500): `chore_logs.user_id`, `household_members.user_id` and `chores.assigned_to_id` have no delete rule.

**Fix:**
- Refuse while the user manages a shared household.
- Otherwise:
  - leave all households;
  - delete the user's logs (right to erasure);
  - reassign their chores to the remaining member(s).

**Screen:** F5.

### 3.7 Alert emails, rate-limited — high, S (after 1.3 and 2.1)
**Emails** (built on the provisional and final reports):
- Sunday report: one email to every member.
- Warning: a member had a week with zero logs.
- Regression and block: a member had a second week in a row with zero logs.
- Unblock.
- Level reached, including the ultimate level, and loss of the ultimate level.

**Rules:**
- Same words and figures for every member.
- The alert never asks anything of the person carrying the load.
- **Rate limit:** at most one report and one alert per member per week.

**Screens:** E3, E4, E5. Mail mockup in progress.

### 3.8 French translation — high, M
The whole UI and the 49-task catalogue are in English.

**Fix:**
- Make French the default locale.
- Translate all views, flashes and validation messages.
- Translate the catalogue: task names in seeds, with a stable key per task.

## Priority 4: Web Push notifications — medium, L

**Prerequisites:** 2.1 and 3.7. The service worker exists (`app/views/pwa/service-worker.js`) but its push handlers are commented out, and the PWA manifest route is not enabled.

**Fix:**
- Add the `web-push` gem. Store the VAPID keys in credentials.
- Add a `push_subscriptions` table: `user_id`, `endpoint`, `p256dh`, `auth`, `user_agent`, `last_used_at`.
- **Subscription:** ask only after a pre-permission screen that explains what will be sent (H1). It appears at the end of the intro (I3 → H1 → sign-up), and it can be opened again from Mon compte › Notifications › Sur ce téléphone (F4) (product decision 2026-11-08). A refusal is respected and can be changed in F4.
- **What is sent:** the same events as the emails in 3.7, under the same rate limit.
- **Fallback:** email is always the fallback.
- **Cleanup:** delete subscriptions that return 404 or 410.
- **Done when:** a Sunday report arrives as a notification on a subscribed phone and opens the right screen.

**Screens:** the "Notifications" row of the mockups (in progress).

## Later

| Item | Value | Effort |
|---|---|---|
| Undo window of 10 s after a log (D8) | Medium | S |
| Journal CSV export (data portability) — **out of V1**, product decision 2026-11-08 | Medium | S |
| Dormant households: email at 12 months of inactivity, then deletion 30 days later | Low before launch | M |
| Wire `RecurringChoreScheduler` (it exists but is never called) | Medium | S |
