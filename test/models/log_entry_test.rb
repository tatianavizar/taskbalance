require "test_helper"

# D6, D7, D10, E12: the rules of logging a task.
class LogEntryTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers
  include FinalWeekHelper

  setup do
    travel_to(paris(2026, 11, 8, 18, 40)) # Sunday of week 45
    @household, (@alice, @bob) = build_household("Alice", "Bob")
    @chore = @household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ @alice.id, @bob.id ])
  end

  teardown { travel_back }

  def entry(user = @alice, **attributes)
    LogEntry.new(user: user, chore_id: @chore.id, mental_load: false, execution_load: true, time_spent: 45, **attributes)
  end

  test "it logs today for the author, with the chore's name and category" do
    e = entry
    assert e.save, e.errors.full_messages.to_sentence

    log = e.log
    assert_equal @alice, log.user
    assert_equal @household, log.household
    assert_equal "Cook a meal", log.chore_name
    assert_equal "cooking", log.category
    assert_equal Time.current, log.completed_at
    assert_not log.off_split?
  end

  test "the day can be up to 7 days back, at that day's local date" do
    e = entry(day: "2026-11-01")
    assert e.save, e.errors.full_messages.to_sentence
    assert_equal Date.new(2026, 11, 1), e.log.completed_on
    assert_equal Week.containing(Date.new(2026, 11, 1), PARIS).label, e.log.week.label
  end

  test "8 days back is refused, and so is tomorrow" do
    too_old = entry(day: "2026-10-31")
    assert_not too_old.save
    assert too_old.errors[:day].any?
    assert_no_difference -> { ChoreLog.count } do
      assert_not entry(day: "2026-11-09").save
    end
  end

  test "the limit follows the household's zone, not UTC" do
    # 23:30 UTC on Saturday is Sunday 00:30 in Paris: 7 days back is Sunday 1 November.
    travel_to(Time.utc(2026, 11, 7, 23, 30))
    assert entry(day: "2026-11-01").save
    assert_not entry(day: "2026-10-31").save
  end

  test "at least one load and a duration are required" do
    e = entry(mental_load: false, execution_load: false, time_spent: nil)

    assert_not e.save
    assert e.errors[:loads].any?
    assert e.errors[:time_spent].any?
  end

  test "a task of another household is refused" do
    other = households(:jones_home).chores.first

    e = LogEntry.new(user: @alice, chore_id: other.id, mental_load: true, time_spent: 10)
    assert_not e.save
    assert e.errors[:chore_id].any?
  end

  test "without a task, a typed name and category are logged off the split (D6)" do
    e = LogEntry.new(user: @bob, custom_name: "Ranger le garage", category: "maintenance", mental_load: true,
                     execution_load: true, time_spent: 90)
    assert e.save, e.errors.full_messages.to_sentence

    assert_nil e.log.chore_id
    assert_equal "Ranger le garage", e.log.chore_name
    assert_equal "maintenance", e.log.category
    assert e.log.off_split?
  end

  test "a name is asked when there is no task" do
    e = LogEntry.new(user: @bob, custom_name: "  ", mental_load: true, time_spent: 10)
    assert_not e.save
    assert e.errors[:custom_name].any?
  end

  test "a task added after the validated split is off the split (D14), the others are not" do
    plan = WeekPlan.propose!(household: @household, by: @alice, week: @household.current_week, kind: :weekly)
    assert plan.planned_chore_ids.include?(@chore.id)
    added = @household.chores.create!(task: tasks(:pay_bills), assignee_user_ids: [ @bob.id ])

    on_split = entry
    assert on_split.save
    assert_not on_split.log.off_split?

    off = LogEntry.new(user: @bob, chore_id: added.id, mental_load: true, time_spent: 20)
    assert off.save
    assert off.log.off_split?
  end

  test "the author is always the user, whatever the request carries" do
    e = LogEntry.new(user: @alice, chore_id: @chore.id, mental_load: true, time_spent: 10, **{})
    assert_not_respond_to e, :user_id=
    assert e.save
    assert_equal @alice, e.log.user
  end

  test "the same idempotency key makes one log" do
    first = entry(idempotency_key: "abc-123")
    assert first.save
    again = entry(idempotency_key: "abc-123")

    assert_no_difference -> { ChoreLog.count } do
      assert again.save
    end
    assert again.duplicate?
    assert_equal first.log.id, again.log.id
  end

  test "an idempotency key is per person" do
    assert entry(@alice, idempotency_key: "k").save
    assert_difference -> { ChoreLog.count }, 1 do
      assert entry(@bob, idempotency_key: "k").save
    end
  end

  test "a log in a closed week reaches the journal and leaves the report as it is" do
    week = Week.containing(Date.new(2026, 10, 28), PARIS)
    close_week!(@household, week)

    e = entry(day: "2026-11-01")
    assert e.save
    assert_not e.log.counts_in_report?
    assert_not e.week_open?(Date.new(2026, 11, 1))
    assert e.week_open?(Date.new(2026, 11, 8))
  end

  test "a shared occurrence is ticked off by each person, once" do
    occurrence = ChoreOccurrence.create!(household: @household, chore: @chore, week_start: Date.new(2026, 11, 2), slot: 99, due_on: Date.new(2026, 11, 8))

    first = entry(@alice, occurrence_id: occurrence.id)
    assert first.save
    assert_equal occurrence, first.log.occurrence
    assert_equal [ @alice.id ], occurrence.reload.done_by_ids

    second = entry(@bob, occurrence_id: occurrence.id)
    assert second.save
    assert_equal [ @alice.id, @bob.id ].sort, occurrence.reload.done_by_ids.sort

    third = entry(@alice, occurrence_id: occurrence.id)
    assert third.save
    assert_nil third.log.occurrence, "already done by this person: logged, not ticked again"
  end

  # --- E12 -----------------------------------------------------------------

  test "only the author corrects a log" do
    log = entry.tap(&:save).log

    assert LogEntry.update(log, user: @alice, mental_load: true, execution_load: true, time_spent: 50)
    assert_equal 50, log.reload.time_spent
    assert log.mental_load

    stranger = LogEntry.new(user: @bob, log: log, time_spent: 5)
    assert_not stranger.update
    assert_equal 50, log.reload.time_spent
  end

  test "a correction keeps the day unless it is changed, and refuses a day too far back" do
    log = entry(day: "2026-11-03").tap(&:save).log

    assert LogEntry.new(user: @alice, log: log, mental_load: true, execution_load: false, time_spent: 20).update
    assert_equal Date.new(2026, 11, 3), log.reload.completed_on

    moved = LogEntry.new(user: @alice, log: log, mental_load: true, execution_load: false, time_spent: 20, day: "2026-10-20")
    assert_not moved.update
    assert moved.errors[:day].any?
  end

  test "an old log can still be corrected on its duration" do
    log = ChoreLog.create!(user: @alice, household: @household, chore: @chore, mental_load: true, execution_load: false,
                           time_spent: 10, completed_at: paris(2026, 9, 20, 10))

    assert LogEntry.update(log, user: @alice, mental_load: true, execution_load: false, time_spent: 15)
    assert_equal 15, log.reload.time_spent
    assert_equal Date.new(2026, 9, 20), log.completed_on
  end
end
