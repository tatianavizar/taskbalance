require "test_helper"

class WeeklySplitTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers
  include SplitHelpers

  def week(n, zone = PARIS) = Week.containing(Date.new(2026, 10, 5) + (7 * n), zone)
  def monday_03(week) = HouseholdWeek.final_at(week.previous)

  setup do
    @household, (@alice, @bob) = build_household("Alice", "Bob")
    @household.update!(setup_step: "done")
    # Ten daily chores (7 occurrences each, both loads), all on Alice.
    @chores = (1..10).map { |i| chore!(@household, "Tâche #{i}", [ @alice ], frequency: :daily) }
    plan!(@household, week(0), by: @alice).approve!(by: @bob)
  end

  def run_split(now) = travel_to(now) { WeeklySplit.new(@household.reload).run(now: now) }
  def share(plan, user) = plan.split.share_of("user:#{user.id}").average

  test "Monday 03:00 local, after the final report: a weekly plan proposed by the app, once" do
    final_week!(@household, week(0), @alice => [ 50.0, 50.0 ], @bob => [ 50.0, 50.0 ])

    assert_nil run_split(monday_03(week(1)) - 1.minute)
    plan = run_split(monday_03(week(1)))
    assert plan.weekly?
    assert plan.proposed?
    assert_nil plan.proposed_by
    assert_equal week(1).monday, plan.week_start
    assert_in_delta 50.0, share(plan, @alice)

    mondays = -> { Notification.where(kind: "monday_split").where("facts->>'week_start' = ?", week(1).monday.iso8601) }
    assert_equal [ @alice.id, @bob.id ].sort, mondays.call.pluck(:user_id).sort, "monday_split to both members"
    run_split(monday_03(week(1)) + 2.hours)
    assert_equal 1, @household.week_plans.where(week_start: week(1).monday).count
    assert_equal 2, mondays.call.count, "fires once"
  end

  test "no proposal before the previous week's final report exists" do
    assert_nil run_split(monday_03(week(1)) + 1.hour)
    assert_nil @household.week_plan_for(week(1))
  end

  test "the proposal compensates last week's gap, only within the zone" do
    final_week!(@household, week(0), @alice => [ 75.0, 75.0 ], @bob => [ 25.0, 25.0 ]) # Alice +25
    plan = run_split(monday_03(week(1)))

    assert_equal({ "user:#{@alice.id}" => 40, "user:#{@bob.id}" => 60 }, plan.targets)
    assert_in_delta 40.0, share(plan, @alice), 0.01, "ten equal chores: 4 for Alice, 6 for Bob"
    assert_in_delta 25.0, SplitGap.balance_of(@household, @alice), 0.01, "what exceeds the zone stays carried"
  end

  test "with the carry-over off the proposal aims at the fair share" do
    @household.update!(gap_carry_over_enabled: false)
    final_week!(@household, week(0), @alice => [ 75.0, 75.0 ], @bob => [ 25.0, 25.0 ])
    plan = run_split(monday_03(week(1)))

    assert_equal [ 50.0, 50.0 ], plan.targets.values
    assert_in_delta 50.0, share(plan, @alice)
    assert_empty @household.split_gap_entries
  end

  test "with the weekly proposal off: no plan, but the gap still folds" do
    @household.update!(weekly_proposal_enabled: false)
    final_week!(@household, week(0), @alice => [ 60.0, 60.0 ], @bob => [ 40.0, 40.0 ])

    assert_nil run_split(monday_03(week(1)))
    assert_nil @household.week_plan_for(week(1))
    assert_in_delta 10.0, SplitGap.balance_of(@household, @alice)
  end

  test "auto-validation applies the plan at once" do
    @household.update!(auto_validate_splits: true)
    final_week!(@household, week(0), @alice => [ 50.0, 50.0 ], @bob => [ 50.0, 50.0 ])
    plan = run_split(monday_03(week(1)))

    assert plan.validated?
    assert plan.locked?
  end

  test "shared chores keep their assignees" do
    shared = chore!(@household, "Courses", [ @alice, @bob ])
    final_week!(@household, week(0), @alice => [ 50.0, 50.0 ], @bob => [ 50.0, 50.0 ])
    plan = run_split(monday_03(week(1)))

    item = plan.assignments.find { |a| a["chore_id"] == shared.id }
    assert_equal [ "user:#{@alice.id}", "user:#{@bob.id}" ].sort, item["assignees"].sort
  end

  test "households still setting up, or alone, get nothing" do
    final_week!(@household, week(0), @alice => [ 50.0, 50.0 ], @bob => [ 50.0, 50.0 ])
    @household.update!(setup_step: "tasks")
    assert_nil run_split(monday_03(week(1)))

    solo, = build_household("Carol")
    assert_nil travel_to(monday_03(week(1))) { WeeklySplit.new(solo).run(now: monday_03(week(1))) }
  end

  test "a non-Paris household proposes at its own Monday 03:00" do
    zone = "America/New_York"
    household, (alice, bob) = build_household("Alice", "Bob", zone: zone)
    household.update!(setup_step: "done")
    chore!(household, "Tâche", [ alice ], frequency: :daily)
    plan!(household, week(0, zone), by: alice).approve!(by: bob)
    final_week!(household, week(0, zone), alice => [ 50.0, 50.0 ], bob => [ 50.0, 50.0 ])
    monday = local(zone, 2026, 10, 12, 3)

    assert_nil travel_to(monday - 1.minute) { WeeklySplit.new(household).run(now: monday - 1.minute) }
    assert travel_to(monday) { WeeklySplit.new(household).run(now: monday) }
  end

  test "the weekly job runs it after the engine, so a real closed week is used" do
    log!(@household, @alice, at: week(0).start_at + 1.day, count: 3)
    log!(@household, @bob, at: week(0).start_at + 1.day)
    travel_to(monday_03(week(1))) { WeeklyEngineJob.perform_now(now: monday_03(week(1))) }

    assert @household.week_plan_for(week(1))
    assert_in_delta 25.0, SplitGap.balance_of(@household, @alice), 0.01, "75 % − 50 %"
  end
end
