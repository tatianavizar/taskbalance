require "test_helper"

# D3 (decision 2026-11-12): a pause declared after the fact over final weeks.
class RetroactivePauseTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  JOINED = -> { ActiveSupport::TimeZone["Europe/Paris"].local(2026, 10, 4, 9) }

  def week(n) = Week.containing(Date.new(2026, 10, 5) + (7 * n), PARIS)
  def mid(week) = week.start_at + 2.days + 10.hours
  def report(household, week) = household.household_weeks.find_by!(week_start: week.monday)

  # Level 1 after week 0; Bob logs nothing in weeks 1 and 2; the regression
  # applies on Wednesday 28 Oct 20:00 (level 0, blocked). Its window closes at
  # the next final report, Monday 2 Nov 03:00.
  def regressed_household
    household, (alice, bob) = build_household("Alice", "Bob", joined_at: JOINED.call)
    log_balanced_week!(household, [ alice, bob ], week(0))
    log!(household, alice, at: mid(week(1)))
    log!(household, alice, at: mid(week(2)))
    run_engine(household, paris(2026, 10, 28, 21))
    assert household.blocked?
    assert_equal [ 0, 0 ], [ household.level, household.balanced_weeks_count ]
    [ household, alice, bob ]
  end

  def declare(household, member_user, by:, from:, to:, at:)
    travel_to(at) do
      MemberPause.declare!(member: membership(household, member_user), declared_by: by, starts_on: from, ends_on: to)
    end
  end

  test "a pause over the weeks that caused a regression corrects them and cancels the regression" do
    household, alice, bob = regressed_household
    stored = household.household_weeks.final.order(:week_start).map(&:attributes)
    regression = household.level_changes.regressed.sole

    pause = declare(household, bob, by: alice, from: week(1).monday, to: week(2).sunday, at: paris(2026, 10, 29, 9))
    household.reload

    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ]
    assert household.active?
    assert_nil household.blocked_at
    assert_equal 0, membership(household, bob).empty_weeks_streak
    assert household.absence_inquiries.sole.cancelled?

    cancel = household.level_changes.regression_cancelled.sole
    assert_equal regression, cancel.cancelled_level_change
    assert_equal [ 0, 1, 0, 1 ], [ cancel.from_level, cancel.to_level, cancel.balanced_weeks_count_before, cancel.balanced_weeks_count_after ]
    assert_empty household.level_changes.standing_regressions

    corrections = household.week_corrections.order(:household_week_id)
    assert_equal [ week(1).monday, week(2).monday ], corrections.map { _1.household_week.week_start }
    assert(corrections.all? { _1.first_name == "Bob" && _1.declared_by == alice && _1.member_pause == pause && _1.user == bob })
    assert_equal pause.created_at, corrections.first.declared_at

    assert_equal stored, household.household_weeks.final.order(:week_start).map(&:attributes), "stored reports are never rewritten"
    corrected = report(household, week(2))
    assert corrected.unbalanced?
    assert_equal "neutral", corrected.effective_outcome
    assert_equal "pause_declared", corrected.effective_neutral_reason
    assert_raises(ActiveRecord::ReadOnlyRecord) { corrected.update!(computed_at: Time.current) }
    assert_equal "balanced", report(household, week(0)).effective_outcome
  end

  test "idempotent: declaring again, or a second overlapping pause, changes nothing more" do
    household, alice, bob = regressed_household
    pause = declare(household, bob, by: alice, from: week(1).monday, to: week(2).sunday, at: paris(2026, 10, 29, 9))

    again = travel_to(paris(2026, 10, 29, 10)) { WeeklyEngine.new(household.reload).pause_declared(pause) }
    assert_empty again.corrections
    assert_empty again.level_changes

    declare(household, bob, by: bob, from: week(2).monday, to: week(2).sunday, at: paris(2026, 10, 30, 9))
    household.reload
    assert_equal 2, household.week_corrections.count
    assert_equal 1, household.level_changes.regression_cancelled.count
    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ]

    run_engine(household, paris(2026, 10, 31, 9))
    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ], "the engine does not regress again"
  end

  test "covering only the first empty week cancels the regression and leaves a streak of 1" do
    household, alice, bob = regressed_household
    declare(household, bob, by: alice, from: week(1).monday, to: week(1).sunday, at: paris(2026, 10, 29, 9))
    household.reload

    assert_equal 1, household.level
    assert_equal 1, membership(household, bob).empty_weeks_streak
    assert household.warned?
    assert_equal [ week(1).monday ], household.week_corrections.map { _1.household_week.week_start }
  end

  test "covering only the second empty week cancels the regression and resets the streak" do
    household, alice, bob = regressed_household
    declare(household, bob, by: alice, from: week(2).monday + 3, to: week(2).sunday, at: paris(2026, 10, 29, 9))
    household.reload

    assert_equal 1, household.level
    assert_equal 0, membership(household, bob).empty_weeks_streak
    assert household.active?
  end

  test "after the next final report the regression stands; weeks still within 14 days are corrected" do
    household, alice, bob = regressed_household
    log!(household, alice, at: mid(week(3)))
    run_engine(household, paris(2026, 11, 2, 3))
    assert_equal 3, membership(household, bob).empty_weeks_streak

    too_late = travel_to(paris(2026, 11, 2, 9)) do
      MemberPause.new(household_member: membership(household, bob), declared_by: alice, starts_on: week(1).monday, ends_on: week(1).sunday)
    end
    travel_to(paris(2026, 11, 2, 9)) { assert_not too_late.valid? }
    assert too_late.errors.added?(:starts_on, :too_far_back, days: 14)

    declare(household, bob, by: alice, from: Date.new(2026, 10, 19), to: Date.new(2026, 10, 25), at: paris(2026, 11, 2, 9))
    household.reload
    assert_equal [ week(2).monday ], household.week_corrections.map { _1.household_week.week_start }
    assert household.blocked?
    assert_equal 0, household.level
    assert_empty household.level_changes.regression_cancelled
    assert household.absence_inquiries.sole.regressed?
    assert_equal 1, membership(household, bob).empty_weeks_streak
  end

  test "out of the window, or on a week the member logged, nothing is corrected" do
    household, alice, bob = regressed_household
    travel_to(paris(2026, 11, 20, 9)) do
      MemberPause.new(household_member: membership(household, bob), declared_by: alice,
                      starts_on: week(-1).monday, ends_on: week(2).sunday).save!(validate: false)
    end
    household.reload

    assert_empty household.week_corrections
    assert household.blocked?
    assert_empty household.level_changes.regression_cancelled
  end

  test "a pause over a week that caused no regression corrects it and clears the warning" do
    household, (alice, bob) = build_household("Alice", "Bob", joined_at: JOINED.call)
    log_balanced_week!(household, [ alice, bob ], week(0))
    log!(household, alice, at: mid(week(1)))
    run_engine(household, HouseholdWeek.final_at(week(1)))
    assert household.warned?

    result = nil
    travel_to(paris(2026, 10, 20, 9)) do
      pause = MemberPause.declare!(member: membership(household, bob), declared_by: bob, starts_on: week(1).monday, ends_on: week(1).sunday)
      result = WeeklyEngine.new(household.reload).pause_declared(pause)
    end
    household.reload

    assert_equal 1, household.week_corrections.count
    assert_empty result.corrections, "the after_create call already recorded it"
    assert_empty household.level_changes.where(reason: %w[regressed regression_cancelled])
    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ]
    assert_equal 0, membership(household, bob).empty_weeks_streak
    assert household.active?
  end

  test "a 'Yes' to a pending inquiry also corrects the two final weeks, with no level change" do
    household, (alice, bob) = build_household("Alice", "Bob", joined_at: JOINED.call)
    log_balanced_week!(household, [ alice, bob ], week(0))
    log!(household, alice, at: mid(week(1)))
    log!(household, alice, at: mid(week(2)))
    run_engine(household, HouseholdWeek.final_at(week(2)))

    travel_to(paris(2026, 10, 27, 12)) { household.absence_inquiries.sole.answer_yes!(by: alice) }
    household.reload
    assert household.absence_inquiries.sole.paused?
    assert_equal 2, household.week_corrections.count
    assert_empty household.level_changes.where(reason: %w[regressed regression_cancelled])
  end

  test "two absent members: the block lifts only when the last standing regression is cancelled" do
    household, (alice, bob, chloe) = build_household("Alice", "Bob", "Chloé", joined_at: JOINED.call)
    [ alice, bob, chloe ].each { |u| log!(household, u, at: mid(week(0))) }
    log!(household, alice, at: mid(week(1)))
    log!(household, alice, at: mid(week(2)))
    run_engine(household, paris(2026, 10, 28, 21))
    assert_equal 2, household.absence_inquiries.regressed.count
    regression = household.level_changes.regressed.sole

    declare(household, bob, by: alice, from: week(1).monday, to: week(2).sunday, at: paris(2026, 10, 29, 9))
    household.reload
    assert household.blocked?, "Chloé's regression still stands"
    assert_equal 0, household.level
    assert_empty household.level_changes.regression_cancelled

    declare(household, chloe, by: alice, from: week(1).monday, to: week(2).sunday, at: paris(2026, 10, 29, 10))
    household.reload
    assert_not household.blocked?
    assert_equal [ 1, 1 ], [ household.level, household.balanced_weeks_count ]
    assert_equal regression, household.level_changes.regression_cancelled.sole.cancelled_level_change
    assert_equal 2, household.absence_inquiries.cancelled.count
  end

  test "deleting the household deletes its corrections" do
    household, alice, bob = regressed_household
    declare(household, bob, by: alice, from: week(1).monday, to: week(2).sunday, at: paris(2026, 10, 29, 9))
    household.destroy!
    assert_equal 0, WeekCorrection.count
  end
end
