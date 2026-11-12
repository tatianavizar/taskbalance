require "test_helper"

# Happy path through the real HTTP stack, no browser: two people sign up, one
# creates the household and invites the other, both log tasks for a week, the
# weekly job closes the week, and both get the same report.
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
    assert_redirected_to household_path(household)
    assert household.household_members.find_by!(user: virginie).manager?

    # Pick a catalogue task for the household
    task = tasks(:cook_meal)
    patch household_chores_setup_path(household), params: { task_ids: [ task.id ] }
    assert_redirected_to household_path(household)
    chore = household.chores.find_by!(task: task)

    # --- Invitation --------------------------------------------------------------
    assert_emails 1 do
      post household_invitations_path(household), params: { invitation: { email: "karim@exemple.fr" } }
    end
    invitation = household.invitations.find_by!(email: "karim@exemple.fr")
    assert_predicate invitation, :pending?
    delete destroy_user_session_path

    # --- Karim opens the link, signs up, claims, accepts -------------------------
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
    post accept_invitation_path(invitation.token)
    assert_redirected_to household_path(household)
    assert_equal household, karim.reload.household
    assert_predicate invitation.reload, :accepted?
    assert_equal 2, household.reload.household_members.count

    # --- Both log the task during the week, through the completion form ----------
    travel_to(monday + 1.day)
    post chore_completion_path(chore), params: { chore_log: { mental_load: "1", execution_load: "1", time_spent: "30" } }
    assert_redirected_to chores_path
    delete destroy_user_session_path

    sign_in virginie
    travel_to(monday + 2.days)
    post chore_completion_path(chore), params: { chore_log: { mental_load: "1", execution_load: "1", time_spent: "25" } }
    assert_redirected_to chores_path
    assert_equal 2, ChoreLog.where(chore: chore).count

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

    get notifications_path
    assert_response :success
  ensure
    travel_back
  end
end
