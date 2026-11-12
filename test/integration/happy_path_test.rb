require "test_helper"

# Happy path through the real HTTP stack, no browser: two people sign up, one
# creates the household, invites the other, chooses the tasks and proposes the
# split; the other gives preferences, accepts the split and joins; both log
# tasks for a week, the weekly job closes the week, and both get the same
# report.
class HappyPathTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "sign up, household, invitation, logs, weekly report and notification" do
    monday = ActiveSupport::TimeZone["Europe/Paris"].local(2026, 11, 2, 9)
    travel_to(monday)

    # --- Virginie signs up and creates the household -----------------------------
    post user_registration_path, params: { user: {
      first_name: "Virginie", email: "virginie@exemple.fr", password: "motdepasse",
      password_confirmation: "motdepasse", time_zone: "Europe/Paris"
    } }
    follow_redirect!
    assert_response :success
    virginie = User.find_by!(email: "virginie@exemple.fr")
    virginie.confirm

    post households_path, params: { household: { name: "Chez Virginie et Karim" } }
    household = virginie.reload.household
    assert household, "household not created"
    assert_redirected_to household_setup_path(household)
    assert household.household_members.find_by!(user: virginie).manager?

    # --- Set-up step 2: the partner (B3) ------------------------------------------
    assert_emails 1 do
      post household_invitations_path(household), params: { invitation: { first_name: "Karim", email: "karim@exemple.fr" } }
    end
    invitation = household.invitations.find_by!(email: "karim@exemple.fr")
    assert_predicate invitation, :pending?
    get household_setup_path(household)
    assert_select "h1", "Avec qui partagez-vous le foyer ?"
    patch household_setup_path(household)
    assert_equal "tasks", household.reload.setup_step

    # --- Step 3: the household's tasks (C1) -----------------------------------------
    task = tasks(:cook_meal)
    patch household_chores_setup_path(household), params: { task_ids: [ task.id, tasks(:pay_bills).id ] }
    assert_redirected_to household_setup_path(household)
    chore = household.chores.find_by!(task: task)
    assert chore.daily?, "catalogue defaults"

    # --- Step 4: Karim has not joined, Virginie proposes now (C12, C4) --------------
    get household_split_path(household)
    assert_redirected_to choice_household_split_path(household)
    get household_split_path(household, mode: "now")
    assert_response :success
    assert_select "input.assign-input[value=?]", "invitation:#{invitation.id}"
    assert_text "Provisoire : elle sera recalculée quand Karim aura rejoint"
    assignments = household.chores.active.to_h { |c| [ c.id, c.assignee_keys ] }
    patch household_split_path(household), params: { commit_action: "validate", assignments: assignments }
    assert_redirected_to dashboard_path
    assert household.reload.setup_done?
    plan = household.starting_plan
    assert plan.proposed? && plan.provisional?, "D15: Karim counts in the starting split"
    assert_equal "Répartition enregistrée. En attente de Karim.", flash[:notice]
    delete destroy_user_session_path

    # --- Karim opens the link and signs up: straight to his preferences (B10) ------
    get invitation_path(invitation.token)
    assert_response :success
    post user_registration_path, params: { invitation_token: invitation.token, user: {
      first_name: "Karim", email: "karim@exemple.fr", password: "motdepasse",
      password_confirmation: "motdepasse", time_zone: "Europe/Paris"
    } }
    karim = User.find_by!(email: "karim@exemple.fr")
    assert_nil karim.household, "an invitee must not join before accepting"
    post claim_invitation_path(invitation.token) unless invitation.reload.invitee_id == karim.id
    assert_equal karim.id, invitation.reload.invitee_id

    get invitation_path(invitation.token)
    assert_redirected_to household_preferences_path(household)
    follow_redirect!
    assert_response :success
    assert_text "Étape 1 sur 2"
    patch household_preferences_path(household), params: { preferences: { chore.id => "like" } }
    assert_redirected_to household_split_path(household)
    assert_equal "like", ChorePreference.find_by!(user: karim, chore: chore).choice
    # The provisional split is recomputed with his preferences (C12, D18).
    assert_equal [ "invitation:#{invitation.id}" ], chore.reload.assignee_keys

    # --- B11: the split Virginie proposed; Karim accepts it and joins ----------------
    follow_redirect!
    assert_response :success
    assert_text "Proposée par Virginie"
    assert_select "button", "Rejoindre le foyer"
    assert_select "form[action=?]", decline_invitation_path(invitation.token)
    shown = household.reload.starting_plan.assignments.to_h { |item| [ item["chore_id"], item["assignees"] ] }
    patch household_split_path(household), params: { commit_action: "validate", assignments: shown }

    assert_redirected_to household_path(household)
    assert_equal household, karim.reload.household
    assert_predicate invitation.reload, :accepted?
    assert_equal 2, household.reload.household_members.count
    # His assignments and his place in the split now belong to his account.
    assert_equal [ "user:#{karim.id}" ], chore.reload.assignee_keys
    plan = household.starting_plan
    assert plan.validated?, "validated by both: Virginie when proposing, Karim when joining"
    assert_not plan.provisional?
    follow_redirect!
    assert_text "Validée par tous les deux"

    # --- Both log the task during the week, through the completion form ----------
    travel_to(monday + 1.day)
    get new_chore_log_path(chore_id: chore.id)
    assert_response :success
    post chore_logs_path, params: { log_entry: { chore_id: chore.id, mental_load: "1", execution_load: "1",
                                                 time_spent: "30", idempotency_key: SecureRandom.uuid } }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_text "Karim"
    delete destroy_user_session_path

    sign_in virginie
    travel_to(monday + 2.days)
    post chore_logs_path, params: { log_entry: { chore_id: chore.id, mental_load: "1", execution_load: "1",
                                                 time_spent: "25", idempotency_key: SecureRandom.uuid } }
    assert_redirected_to dashboard_path
    assert_equal 2, ChoreLog.where(chore: chore).count

    # The home reads the same figures as WeeklyStats: 50 % each, in the zone.
    get dashboard_path
    assert_response :success
    live = WeeklyStats.new(household.reload, household.current_week)
    assert_equal [ 50, 50 ], live.members.map(&:mental_share)
    assert_select "section.card b", text: "50 %", count: 4 # two dimensions, two people
    assert_text "ne compte pas pour le niveau"

    stats = WeeklyStats.new(household.reload, household.current_week)
    assert_equal :neutral, stats.outcome, "Karim's arrival week is neutral"
    assert_equal :member_arrived, stats.neutral_reason
    assert stats.members.all?(&:in_zone), "both carry 50 %"

    # --- The weekly job closes the week ------------------------------------------
    # The household was created this week: the arrival week is neutral, so the
    # level only moves on a full week. Log the next week too, then close both.
    week2 = monday + 7.days
    travel_to(week2 + 1.day)
    [ virginie, karim ].each do |user|
      ChoreLog.create!(user: user, household: household, chore: chore, mental_load: true,
                       execution_load: true, time_spent: 20, completed_at: Time.current)
    end

    # The recurring job runs every 15 min; simulate its runs at the key moments.
    sunday_2030 = week2 + 6.days + 11.5.hours   # week2 is Monday 09:00
    [ week2 - 6.hours,                          # Monday 03:00 + : closes week 1
      sunday_2030 ].each do |at|                # provisional week 2 (no message)
      travel_to(at)
      perform_enqueued_jobs { WeeklyEngineJob.perform_now }
    end

    # Both log again on Sunday at 21:00, after the provisional report.
    travel_to(sunday_2030 + 30.minutes)
    [ virginie, karim ].each do |user|
      ChoreLog.create!(user: user, household: household, chore: chore, mental_load: true,
                       execution_load: true, time_spent: 15, completed_at: Time.current)
    end

    [ sunday_2030 + 7.hours,                    # Monday 03:30: final week 2
      sunday_2030 + 12.hours ].each do |at|     # Monday 08:30: report delivery
      travel_to(at)
      perform_enqueued_jobs { WeeklyEngineJob.perform_now }
    end

    weeks = HouseholdWeek.where(household: household).order(:week_start)
    assert_operator weeks.count, :>=, 2
    assert weeks.all?(&:final?), "closed weeks must be final"
    assert_equal "neutral", weeks.first.outcome
    assert_equal "balanced", weeks.second.outcome
    assert_equal 1, household.reload.level, "one balanced week reaches level 1"

    # --- Both get the same report, with the same figures -------------------------
    # The report of week 2 comes from the final report: Sunday 21:00 logs
    # included, not provisional, and the level that report gave.
    week2_start = week2.to_date.iso8601
    reports = Notification.where(household: household, kind: "weekly_report").where("facts->>'week_start' = ?", week2_start)
    assert_equal [ karim.id, virginie.id ].sort, reports.pluck(:user_id).sort
    assert_equal 1, reports.map(&:facts).uniq.size, "D8: same facts for every recipient"
    facts = reports.first.facts
    assert_equal false, facts["provisional"]
    assert_equal 1, facts["level"]
    assert_equal [ 2, 2 ], facts["members"].map { _1["logs_count"] }, "Sunday 21:00 logs are in the report"
    assert(reports.all? { _1.channel.present? }, "sent, not suppressed")

    # --- A week with no run on Sunday: the job next runs on Tuesday ---------------
    week3 = week2 + 7.days
    travel_to(week3 + 2.days) # Wednesday
    [ virginie, karim ].each do |user|
      ChoreLog.create!(user: user, household: household, chore: chore, mental_load: true,
                       execution_load: true, time_spent: 20, completed_at: Time.current)
    end
    travel_to(week3 + 8.days) # Tuesday after, 09:00: the first run since Wednesday
    perform_enqueued_jobs { WeeklyEngineJob.perform_now }

    week3_reports = Notification.where(household: household, kind: "weekly_report")
      .where("facts->>'week_start' = ?", week3.to_date.iso8601)
    assert_equal [ karim.id, virginie.id ].sort, week3_reports.pluck(:user_id).sort
    assert(week3_reports.all? { _1.channel.present? && _1.facts["provisional"] == false })
    assert_equal [ 1, 2 ], [ household.reload.level, household.balanced_weeks_count ], "week 3 counted too"

    # --- The final report of week 2, on the Bilan tab (E14) ----------------------
    # Read from the stored report, not recomputed: closed Monday 03:00, balanced
    # for both, naming no one, and the level that closing gave.
    get report_path(semaine: week2_start)
    assert_response :success
    assert_text "Définitif · clos le lundi 16 nov à 3:00"
    assert_select "#report-outcome h2", "Équilibrée"
    assert_select "#report-outcome", text: /Virginie|Karim/, count: 0
    assert_select "section.card b", text: "50 %", count: 4
    assert_select "#report-level-#{household.level_changes.reached.first.id}", text: /Niveau 1 atteint à ce bilan/
    # The report notification opens on that week, not on the one in progress.
    get notification_path(reports.find_by!(user: virginie))
    assert_redirected_to report_path(semaine: week2_start)
    get levels_path
    assert_select "#level-now h2", "Niveau 1"

    get notifications_path
    assert_response :success
  ensure
    travel_back
  end
end
