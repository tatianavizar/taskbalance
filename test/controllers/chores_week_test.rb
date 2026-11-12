require "test_helper"

# D3, D4 (the Tasks tab), « Fait » in one gesture, D5 (a task's detail).
class ChoresWeekTest < ActionDispatch::IntegrationTest
  include WeeklyEngineHelpers

  setup do
    # Wednesday 4 November, 10:00.
    travel_to(paris(2026, 11, 4, 10))
    @alice = users(:alice)
    @bob = users(:bob)
    @household = households(:smith_home)
    @household.chores.destroy_all
    @bills = @household.chores.create!(task: tasks(:pay_bills), assignee_user_ids: [ @alice.id ], frequency: :monthly,
                                       anchor_on: Date.new(2026, 11, 2))
    @cooking = @household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ @bob.id ], frequency: :daily)
    @laundry = @household.chores.create!(task: tasks(:do_laundry), assignee_user_ids: [ @alice.id, @bob.id ],
                                         frequency: :weekly, anchor_on: Date.new(2026, 11, 6))
    @household.chores.update_all(created_at: paris(2026, 11, 2, 9))
    ChoreOccurrence.delete_all
    RecurringChoreScheduler.sync_household(@household)
    sign_in @alice
  end

  teardown { travel_back }

  def occurrence(chore, on)
    ChoreOccurrence.find_by!(chore_id: chore.id, due_on: on)
  end

  test "the tab lists late, today and later, with « Fait » on the tasks I carry" do
    get chores_path

    assert_response :success
    assert_select "#section-late", "En retard"
    assert_select "#section-today", "Aujourd'hui"
    assert_select "#section-later", "Plus tard"
    assert_text "depuis le 2 nov"
    # Mine and shared: a button. Someone else's: none.
    assert_select "form[action=?] button", complete_chore_occurrence_path(occurrence(@bills, Date.new(2026, 11, 2)))
    assert_select "form[action=?]", complete_chore_occurrence_path(occurrence(@cooking, Date.new(2026, 11, 4))), 0
    assert_select "form[action=?] button", complete_chore_occurrence_path(occurrence(@laundry, Date.new(2026, 11, 6)))
  end

  test "a missed daily task stays late and is folded into one line with its count" do
    get chores_path

    assert_select "#section-late"
    assert_text "Cook a meal · 2 en retard"
    assert_text "la plus ancienne depuis le 2 nov"
    assert_equal 1, response.body.scan("Cook a meal · ").size, "one line, not one per missed day"
    # Today's and the following days' occurrences are not late.
    board = TaskBoard.new(user: @alice)
    assert_equal [ Date.new(2026, 11, 2), Date.new(2026, 11, 3) ], board.late.select { |e| e.chore == @cooking }.map(&:due_on)
    assert_equal [ @cooking.id, @bills.id ].sort, board.late_groups.map { |g| g.chore.id }.sort
  end

  test "a missed daily occurrence is late on Thursday of its week and gone the next Monday" do
    travel_to(paris(2026, 11, 5, 10)) # Thursday
    RecurringChoreScheduler.sync_household(@household)
    board = TaskBoard.new(user: @alice)
    assert_equal [ Date.new(2026, 11, 2), Date.new(2026, 11, 3), Date.new(2026, 11, 4) ],
                 board.late.select { |e| e.chore == @cooking }.map(&:due_on)
    assert_equal 3, board.late_groups.find { |g| g.chore == @cooking }.count, "the folded count"

    travel_to(paris(2026, 11, 9, 8)) # next Monday
    RecurringChoreScheduler.sync_household(@household)
    board = TaskBoard.new(user: @alice)
    assert_empty board.late.select { |e| e.chore == @cooking }, "last week's daily occurrences dropped out"
    assert_equal [ Date.new(2026, 11, 9) ], board.due_today.select { |e| e.chore == @cooking }.map(&:due_on)
    get chores_path
    assert_not response.body.include?("en retard")
  end

  test "the folded count stays within the week" do
    travel_to(paris(2026, 11, 11, 10)) # Wednesday of the next week
    RecurringChoreScheduler.sync_household(@household)
    @household.chores.update_all(created_at: paris(2026, 11, 2, 9))

    group = TaskBoard.new(user: @alice).late_groups.find { |g| g.chore == @cooking }
    assert_equal 2, group.count, "Monday and Tuesday of the current week, not last week's seven"
    assert_equal Date.new(2026, 11, 9), group.since
  end

  test "a weekly occurrence behaves the same: late until Sunday, gone the next Monday" do
    travel_to(paris(2026, 11, 8, 20)) # Sunday, laundry was due Friday 6
    RecurringChoreScheduler.sync_household(@household)
    assert_includes TaskBoard.new(user: @alice).late.map(&:chore), @laundry

    travel_to(paris(2026, 11, 9, 8))
    RecurringChoreScheduler.sync_household(@household)
    assert_not_includes TaskBoard.new(user: @alice).late.map(&:chore), @laundry
  end

  test "a monthly occurrence is still late the following week" do
    travel_to(paris(2026, 11, 11, 10))
    RecurringChoreScheduler.sync_household(@household)

    late = TaskBoard.new(user: @alice).late.select { |e| e.chore == @bills }
    assert_equal [ Date.new(2026, 11, 2) ], late.map(&:due_on)
  end

  test "the week is the household's, not UTC's: a Los Angeles household still has its Sunday" do
    la_home, (la_user, _) = build_household("Lou", "Lee", zone: "America/Los_Angeles", joined_at: Time.utc(2026, 9, 1))
    chore = la_home.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ la_user.id ], frequency: :daily)
    la_home.chores.update_all(created_at: Time.utc(2026, 11, 2, 17))
    # 03:00 UTC Monday 9 November: Monday in Paris, still Sunday 8 in Los Angeles.
    travel_to(Time.utc(2026, 11, 9, 3))
    ChoreOccurrence.where(chore_id: chore.id).delete_all
    RecurringChoreScheduler.sync_household(la_home)
    assert_equal 6, TaskBoard.new(user: la_user).late.count { |e| e.chore == chore }, "Mon 2 to Sat 7, Sunday is today"

    # 08:00 UTC: Monday 00:00 in Los Angeles, the new week; last week's drop out.
    travel_to(Time.utc(2026, 11, 9, 8))
    RecurringChoreScheduler.sync_household(la_home)
    assert_equal 0, TaskBoard.new(user: la_user).late.count { |e| e.chore == chore }
  end

  test "logging a late occurrence fulfils it, with the day it was really done, in that week" do
    travel_to(paris(2026, 11, 11, 10))
    RecurringChoreScheduler.sync_household(@household)
    occ = occurrence(@bills, Date.new(2026, 11, 2)) # due in week 45, done in week 46

    post complete_chore_occurrence_path(occ), params: { idempotency_key: "late-1" }

    log = ChoreLog.find_by!(occurrence_id: occ.id)
    assert_equal Time.current, log.completed_at
    assert_equal Week.containing(Time.current, "Europe/Paris").monday, log.week.monday, "counts in the week it was done"
    assert_not_equal occ.week_start, log.week.monday
    assert_equal 1, WeeklyStats.new(@household, @household.current_week).member_for(@alice).logs_count
    assert_equal 0, WeeklyStats.new(@household, Week.containing(Date.new(2026, 11, 2), "Europe/Paris")).member_for(@alice).logs_count
    assert TaskBoard.new(user: @alice).late.none? { |e| e.chore == @bills }, "fulfilled, no longer late"
  end

  test "« Fait » on a folded line fulfils the oldest occurrence, one at a time" do
    sign_in @bob
    get chores_path
    oldest = occurrence(@cooking, Date.new(2026, 11, 2))
    assert_select "form[action=?] button", complete_chore_occurrence_path(oldest)

    post complete_chore_occurrence_path(oldest), params: { idempotency_key: "x" }
    get chores_path
    assert_text "Cook a meal"
    assert_not response.body.include?("2 en retard"), "one left, shown as a plain late line"
    assert_text "depuis le 3 nov"
    assert_select "form[action=?] button", complete_chore_occurrence_path(occurrence(@cooking, Date.new(2026, 11, 3)))
  end

  test "the detail's button logs the oldest open occurrence" do
    get chore_path(@cooking.tap { |c| c.update!(assignee_user_ids: [ @alice.id ]) })
    assert_select "a[href=?]", new_chore_log_path(chore_id: @cooking.id, occurrence_id: occurrence(@cooking, Date.new(2026, 11, 2)).id)
  end

  test "a monthly task of an earlier week stays late until it is done" do
    travel_to(paris(2026, 11, 10, 10))
    RecurringChoreScheduler.sync_household(@household)

    get chores_path
    assert_text "depuis le 2 nov"
  end

  test "the mine filter hides the others' tasks and the empty state points at the next one" do
    get chores_path(scope: "mine")
    assert_select ".chip[aria-current=true]", /Les miennes/
    assert_not response.body.include?("Cook a meal")

    ChoreLog.create!(user: @alice, household: @household, chore: @bills, occurrence: occurrence(@bills, Date.new(2026, 11, 2)),
                     mental_load: true, execution_load: false, time_spent: 20, completed_at: Time.current)
    get chores_path(scope: "mine")
    assert_text "Rien ne vous est assigné aujourd'hui, rien en retard."
    assert_text "Votre prochaine tâche : Do laundry"
  end

  test "the category filter keeps one category" do
    get chores_path(category: "admin")

    assert_text "Payer les factures"
    assert_not response.body.include?("Cook a meal")
  end

  test "« Fait » logs the task as the chore describes it, today, for me only" do
    occurrence = occurrence(@bills, Date.new(2026, 11, 2))

    assert_difference -> { @alice.chore_logs.count }, 1 do
      assert_no_difference -> { @bob.chore_logs.count } do
        post complete_chore_occurrence_path(occurrence), params: { idempotency_key: "tap-1" }
      end
    end

    assert_redirected_to chores_path
    log = @alice.chore_logs.order(:id).last
    assert_equal occurrence, log.occurrence
    assert_equal [ @bills.mental_load, @bills.execution_load, @bills.effective_time_required ],
                 [ log.mental_load, log.execution_load, log.time_spent ]
    assert_equal Time.current, log.completed_at
    follow_redirect!
    assert_select "form[action=?]", complete_chore_occurrence_path(occurrence), 0
  end

  test "a double tap on « Fait » makes one log" do
    occurrence = occurrence(@bills, Date.new(2026, 11, 2))

    assert_difference -> { ChoreLog.count }, 1 do
      2.times { post complete_chore_occurrence_path(occurrence), params: { idempotency_key: "tap-1" } }
    end
  end

  test "a shared task stays open for the other person after I did mine" do
    occurrence = occurrence(@laundry, Date.new(2026, 11, 6))
    post complete_chore_occurrence_path(occurrence), params: { idempotency_key: "a" }
    get chores_path
    assert_select "form[action=?]", complete_chore_occurrence_path(occurrence), 0

    sign_in @bob
    get chores_path
    assert_select "form[action=?] button", complete_chore_occurrence_path(occurrence)
  end

  test "I cannot tick off a task that is not mine, nor one of another household" do
    assert_no_difference -> { ChoreLog.count } do
      post complete_chore_occurrence_path(occurrence(@cooking, Date.new(2026, 11, 4)))
      assert_redirected_to chores_path

      theirs = households(:jones_home).chores.first
      stranger = ChoreOccurrence.create!(household: theirs.household, chore: theirs, week_start: Date.new(2026, 11, 2), slot: 0, due_on: Date.new(2026, 11, 4))
      post complete_chore_occurrence_path(stranger)
      assert_redirected_to chores_path
    end
  end

  test "someone without a household goes back to the home" do
    sign_in users(:dana)
    get chores_path
    assert_redirected_to dashboard_path
  end

  # --- D5 -------------------------------------------------------------------

  test "the detail shows the task, who carries it and its history" do
    ChoreLog.create!(user: @alice, household: @household, chore: @bills, mental_load: true, execution_load: false,
                     time_spent: 25, completed_at: paris(2026, 10, 6, 12))

    get chore_path(@bills)

    assert_response :success
    assert_select "h1", "Payer les factures"
    assert_text "En retard depuis le 2 nov"
    assert_text "Chaque mois"
    assert_text "Alice · 25 min"
    assert_select "a[href=?]", new_chore_log_path(chore_id: @bills.id, occurrence_id: occurrence(@bills, Date.new(2026, 11, 2)).id)
  end

  test "the detail of another household's task is not available" do
    get chore_path(households(:jones_home).chores.first)
    assert_redirected_to chores_path
  end
end
