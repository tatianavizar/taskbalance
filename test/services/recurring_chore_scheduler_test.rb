require "test_helper"

# Lot 4: the week's occurrences, written from the chores' own recurrence, in
# the household's zone, idempotently.
class RecurringChoreSchedulerTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  setup do
    travel_to(paris(2026, 11, 2, 9)) # Monday of week 45
    @household, (@alice, @bob) = build_household("Alice", "Bob", joined_at: paris(2026, 9, 1, 9))
    # Made on a Monday, so the whole week is planned.
    @household.chores.destroy_all
  end

  teardown { travel_back }

  def make_chore(task: tasks(:cook_meal), **attributes)
    @household.chores.create!(task: task, assignee_user_ids: [ @alice.id ], **attributes)
  end

  def occurrences(chore, week = @household.current_week)
    ChoreOccurrence.where(chore_id: chore.id, week_start: week.monday).order(:slot)
  end

  test "a daily chore has an occurrence every day, a weekly one its number of times" do
    daily = make_chore(frequency: :daily)
    twice = make_chore(task: tasks(:do_laundry), frequency: :weekly, times_per_period: 2)

    assert_equal (Date.new(2026, 11, 2)..Date.new(2026, 11, 8)).to_a, occurrences(daily).map(&:due_on)
    assert_equal [ Date.new(2026, 11, 2), Date.new(2026, 11, 5) ], occurrences(twice).map(&:due_on)
  end

  test "the number of occurrences is the planned weight of the split" do
    week = @household.current_week
    [ { frequency: :daily, times_per_period: 2 }, { frequency: :weekly, times_per_period: 3 }, { frequency: :weekly } ].each do |attrs|
      chore = make_chore(**attrs)
      assert_equal chore.occurrences_in(week), occurrences(chore).count, attrs.inspect
    end
  end

  test "a monthly or one-off chore only has one in the week it falls due" do
    monthly = make_chore(task: tasks(:pay_bills), frequency: :monthly, anchor_on: Date.new(2026, 10, 12))
    due = make_chore(task: tasks(:pay_bills), frequency: :monthly, anchor_on: Date.new(2026, 10, 5))
    once = @household.chores.create!(custom_name: "Renouveler l'assurance", category: "admin", mental_load: true,
                                     time_required: 30, frequency: :once, anchor_on: Date.new(2026, 11, 6),
                                     assignee_user_ids: [ @bob.id ])

    assert_empty occurrences(monthly), "the 12th is not this week"
    assert_equal [ Date.new(2026, 11, 5) ], occurrences(due).map(&:due_on)
    assert_equal [ Date.new(2026, 11, 6) ], occurrences(once).map(&:due_on)
  end

  test "creating a chore writes its occurrences at once" do
    assert_difference -> { ChoreOccurrence.count }, 7 do
      make_chore(frequency: :daily)
    end
  end

  test "it is idempotent: a rerun, the job and a second sync write nothing new" do
    chore = make_chore(frequency: :daily)
    ids = occurrences(chore).pluck(:id)

    assert_no_difference -> { ChoreOccurrence.count } do
      RecurringChoreScheduler.sync_chore(chore)
      RecurringChoreScheduler.sync_household(@household)
      RecurringChoreSchedulerJob.perform_now
      RecurringChoreSchedulerJob.perform_now
    end
    assert_equal ids, occurrences(chore).pluck(:id)
  end

  test "a chore made mid-week has nothing late before its first day" do
    travel_to(paris(2026, 11, 4, 12)) # Wednesday
    chore = make_chore(frequency: :daily)

    assert_equal (Date.new(2026, 11, 4)..Date.new(2026, 11, 8)).to_a, occurrences(chore).map(&:due_on)
  end

  test "a changed recurrence moves the open occurrences and keeps the ones with a log" do
    chore = make_chore(frequency: :daily)
    done = occurrences(chore).first
    ChoreLog.create!(user: @alice, household: @household, chore: chore, occurrence: done, mental_load: false,
                     execution_load: true, time_spent: 10, completed_at: Time.current)

    chore.update!(frequency: :weekly, times_per_period: 1)

    assert_equal [ done.id ], occurrences(chore).pluck(:id), "the six open days go, the logged one stays"
  end

  test "a retired chore loses its open occurrences" do
    chore = make_chore(frequency: :daily)
    chore.update!(active: false)

    assert_empty occurrences(chore)
  end

  test "deleting the chore deletes its occurrences and detaches the logs of them" do
    chore = make_chore(frequency: :daily)
    log = ChoreLog.create!(user: @alice, household: @household, chore: chore, occurrence: occurrences(chore).first,
                           mental_load: false, execution_load: true, time_spent: 10, completed_at: Time.current)

    chore.destroy!

    assert_equal 0, ChoreOccurrence.where(chore_id: chore.id).count
    assert_nil log.reload.occurrence_id
    assert_equal "Cook a meal", log.chore_name
  end

  test "a week with a daylight-saving change keeps seven local days" do
    # Paris: the clocks go forward on Sunday 29 March 2026, inside the week.
    travel_to(paris(2026, 3, 23, 9))
    household, (alice, _bob) = build_household("Alice", "Bob", joined_at: paris(2026, 3, 1, 9))
    chore = household.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ alice.id ], frequency: :daily)

    week = household.current_week
    assert_equal (Date.new(2026, 3, 23)..Date.new(2026, 3, 29)).to_a,
                 ChoreOccurrence.where(chore_id: chore.id, week_start: week.monday).order(:slot).map(&:due_on)

    # Sunday 29 March at 23:30 local is still that week; the next local Monday
    # opens the next one, although UTC is still on Sunday 22:30.
    travel_to(paris(2026, 3, 29, 23, 30))
    RecurringChoreScheduler.sync_household(household)
    assert_equal Date.new(2026, 3, 23), ChoreOccurrence.where(chore_id: chore.id).minimum(:week_start)

    travel_to(paris(2026, 3, 30, 0, 30))
    assert_equal Time.utc(2026, 3, 29, 22, 30), Time.current.utc
    RecurringChoreScheduler.sync_household(household)
    assert_equal 7, ChoreOccurrence.where(chore_id: chore.id, week_start: Date.new(2026, 3, 30)).count
    assert_equal 14, ChoreOccurrence.where(chore_id: chore.id).count
  end

  test "each household is written in its own time zone" do
    # 03:00 UTC on Monday 9 November: Monday already in Paris, still Sunday in Los Angeles.
    travel_to(Time.utc(2026, 11, 9, 3, 0))
    paris_home, (paris_user, _) = build_household("Pia", "Paul", zone: "Europe/Paris", joined_at: Time.utc(2026, 9, 1))
    la_home, (la_user, _) = build_household("Lou", "Lee", zone: "America/Los_Angeles", joined_at: Time.utc(2026, 9, 1))
    paris_chore = paris_home.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ paris_user.id ], frequency: :weekly)
    la_chore = la_home.chores.create!(task: tasks(:cook_meal), assignee_user_ids: [ la_user.id ], frequency: :weekly)
    ChoreOccurrence.delete_all

    RecurringChoreSchedulerJob.perform_now

    assert_equal [ Date.new(2026, 11, 9) ], ChoreOccurrence.where(chore_id: paris_chore.id).pluck(:week_start)
    assert_equal [ Date.new(2026, 11, 2) ], ChoreOccurrence.where(chore_id: la_chore.id).pluck(:week_start)
  end

  test "the job is a recurring task" do
    config = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    assert_equal "ChoreSchedulerDispatchJob", config.dig("production", "recurring_chore_scheduler", "class")
  end
end
