require "test_helper"

class ProgressionTest < ActiveSupport::TestCase
  include WeeklyEngineHelpers

  test "levels from cumulative balanced weeks: 1, 3, 6, 10, 15" do
    expected = { 0 => 0, 1 => 1, 2 => 1, 3 => 2, 5 => 2, 6 => 3, 9 => 3, 10 => 4, 14 => 4, 15 => 5, 40 => 5 }
    expected.each { |count, level| assert_equal level, Progression.level_for(count), "count #{count}" }
  end

  test "thresholds and regression" do
    assert_equal [ 0, 1, 3, 6, 10, 15 ], (0..5).map { Progression.threshold(_1) }
    assert_equal [ 0, 0, 1, 2, 3, 4 ], (0..5).map { Progression.regressed_level(_1) }
  end

  test "rule numbers come from HouseholdRules" do
    assert_equal HouseholdRules::LEVEL_THRESHOLDS, Progression::THRESHOLDS.values
    assert_equal HouseholdRules::LEVEL_THRESHOLDS.size, Progression::ULTIMATE
    assert_equal Rational(85, 100), Progression::ULTIMATE_MIN_RATIO
  end

  def add_week(household, monday, outcome, status = "final")
    household.household_weeks.create!(week_start: monday, time_zone: PARIS, status: status, outcome: outcome,
      neutral_reason: (outcome == "neutral" ? "no_mental_logs" : nil), computed_at: Time.current)
  end

  test "the ultimate ratio counts final non-neutral weeks since the level was first reached" do
    household, = build_household("Alice", "Bob")
    last = Week.containing(Date.new(2027, 10, 4), PARIS)
    ago = ->(n) { last.monday - (7 * n) }

    assert_nil Progression.ultimate_ratio(household, last)
    assert Progression.keeps_ultimate?(household, last)

    add_week(household, ago.(20), "unbalanced") # before the level was reached
    household.update!(ultimate_reached_on: ago.(10))
    add_week(household, ago.(10), "balanced")
    add_week(household, ago.(9), "neutral")
    add_week(household, ago.(1), "unbalanced", "provisional")
    5.times { add_week(household, ago.(_1 + 2), "balanced") }
    add_week(household, ago.(0), "unbalanced")

    assert_equal ago.(10), Progression.ultimate_window_start(household, last)
    assert_equal Rational(6, 7), Progression.ultimate_ratio(household, last)
    assert Progression.keeps_ultimate?(household, last)
  end

  test "the window is capped at the last 52 weeks" do
    household, = build_household("Alice", "Bob")
    last = Week.containing(Date.new(2027, 10, 4), PARIS)
    ago = ->(n) { last.monday - (7 * n) }
    household.update!(ultimate_reached_on: ago.(60))
    add_week(household, ago.(52), "unbalanced") # 53rd week back: outside
    add_week(household, ago.(51), "balanced")
    add_week(household, ago.(0), "balanced")

    assert_equal ago.(51), Progression.ultimate_window_start(household, last)
    assert_equal 1, Progression.ultimate_ratio(household, last)
  end

  test "exactly 85 % does not keep the ultimate level" do
    household, = build_household("Alice", "Bob")
    last = Week.containing(Date.new(2027, 10, 4), PARIS)
    household.update!(ultimate_reached_on: last.monday - (7 * 19))
    20.times { |n| add_week(household, last.monday - (7 * n), n < 3 ? "unbalanced" : "balanced") }

    assert_equal Rational(17, 20), Progression.ultimate_ratio(household, last)
    assert_not Progression.keeps_ultimate?(household, last)
  end

  # ---- D5 margin ------------------------------------------------------------

  # Final weeks ending on `last`, given oldest first, and the first reach date.
  def ultimate_household(outcomes, reached_weeks_ago: outcomes.size - 1, level: Progression::ULTIMATE)
    household, = build_household("Alice", "Bob")
    last = Week.containing(Date.new(2027, 10, 4), PARIS)
    outcomes.reverse.each_with_index { |outcome, n| add_week(household, last.monday - (7 * n), outcome) }
    household.update!(level: level, ultimate_reached_on: last.monday - (7 * reached_weeks_ago))
    household
  end

  test "no margin below the ultimate level" do
    assert_nil Progression.ultimate_margin(ultimate_household([ "balanced" ] * 10, level: 4))
  end

  test "young window: the margin grows with the balanced weeks since the level was reached" do
    assert_equal 0, Progression.ultimate_margin(ultimate_household([ "balanced" ]))      # 1/2 = 50 %
    assert_equal 1, Progression.ultimate_margin(ultimate_household([ "balanced" ] * 6))  # 6/7 = 85.7 %, 6/8 = 75 %
    assert_equal 1, Progression.ultimate_margin(ultimate_household([ "balanced" ] * 10)) # 10/12 = 83 %
    assert_equal 3, Progression.ultimate_margin(ultimate_household([ "balanced" ] * 20)) # 20/23 = 87 %, 20/24 = 83 %
  end

  test "a simulated week landing exactly on 85 % is not absorbable" do
    # 17/19 = 89 % keeps, 17/20 = 85 % does not.
    assert_equal 2, Progression.ultimate_margin(ultimate_household([ "balanced" ] * 17))
  end

  test "weeks before the first reach, neutral weeks and corrected weeks do not count" do
    outcomes = [ "unbalanced" ] * 5 + [ "balanced" ] * 3 + [ "neutral" ] + [ "balanced" ] * 3 + [ "unbalanced" ]
    household = ultimate_household(outcomes, reached_weeks_ago: 7) # from the first of the last 3 + 1 + 3 + 1
    assert_equal 0, Progression.ultimate_margin(household), "6/7 now, 6/8 after one more"

    corrected = household.household_weeks.order(:week_start).last
    household.week_corrections.create!(household_week: corrected, first_name: "Bob", declared_at: Time.current)
    assert_equal 1, Progression.ultimate_margin(household), "6/6 now, 6/7 after one, 6/8 after two"
  end

  test "full 52-week window: the oldest weeks drop out as the window slides" do
    household = ultimate_household([ "balanced" ] * 80)
    # 52 balanced in the window: 45/52 = 86.5 % after 7, 44/52 = 84.6 % after 8.
    # Without sliding it would be 52/61 = 85.2 % after 9.
    assert_equal 7, Progression.ultimate_margin(household)
  end

  test "full window whose oldest weeks are unbalanced: they slide out first" do
    household = ultimate_household([ "balanced" ] * 28 + [ "unbalanced" ] * 3 + [ "balanced" ] * 49)
    # 49/52 now. The 3 unbalanced weeks leave first, so 49/52 holds for 3
    # weeks, then 45/52 after 7, 44/52 after 8. A non-sliding count gives 5.
    assert_equal 7, Progression.ultimate_margin(household)
  end
end
