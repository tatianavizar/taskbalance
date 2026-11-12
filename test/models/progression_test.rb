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
    assert_equal 7, HouseholdRules::ULTIMATE_UNBALANCED_QUOTA
    assert_equal 52, HouseholdRules::ULTIMATE_WINDOW_WEEKS
  end

  def add_week(household, monday, outcome, status = "final")
    household.household_weeks.create!(week_start: monday, time_zone: PARIS, status: status, outcome: outcome,
      neutral_reason: (outcome == "neutral" ? "no_mental_logs" : nil), computed_at: Time.current)
  end

  LAST = Week.containing(Date.new(2027, 10, 4), "Europe/Paris")
  def ago(n) = LAST.monday - (7 * n)

  # A household at the ultimate level since `reached` weeks ago, with the
  # given final weeks (weeks ago => outcome).
  def ultimate_household(weeks, reached: 51, level: Progression::ULTIMATE)
    household, = build_household("Alice", "Bob")
    household.update_columns(level: level, balanced_weeks_count: 20, ultimate_reached_on: ago(reached))
    weeks.each { |n, outcome| add_week(household, ago(n), outcome) }
    household
  end

  def unbalanced(*weeks_ago) = weeks_ago.to_h { [ _1, "unbalanced" ] }

  test "quota: 7 unbalanced weeks in the window keep the ultimate level, 8 lose it" do
    seven = ultimate_household(unbalanced(0, 1, 2, 3, 4, 5, 6).merge(7 => "balanced"))
    assert_equal 7, Progression.unbalanced_weeks_in_window(seven, LAST)
    assert Progression.keeps_ultimate?(seven, LAST)

    eight = ultimate_household(unbalanced(0, 1, 2, 3, 4, 5, 6, 30))
    assert_equal 8, Progression.unbalanced_weeks_in_window(eight, LAST)
    assert_not Progression.keeps_ultimate?(eight, LAST)
  end

  test "neutral, provisional and corrected weeks do not count" do
    household = ultimate_household(unbalanced(0, 1, 2, 3, 4, 5, 6).merge(7 => "neutral", 8 => "unbalanced"))
    add_week(household, ago(-1), "unbalanced", "provisional")
    assert_equal 8, Progression.unbalanced_weeks_in_window(household, LAST)

    corrected = household.household_weeks.find_by!(week_start: ago(8))
    household.week_corrections.create!(household_week: corrected, first_name: "Bob", declared_at: Time.current)
    assert_equal 7, Progression.unbalanced_weeks_in_window(household, LAST)
    assert Progression.keeps_ultimate?(household, LAST)
  end

  test "the window starts at the reach, capped at the last 52 weeks" do
    young = ultimate_household(unbalanced(10, 11, 12, 13, 14, 15, 16, 17, 18), reached: 5)
    assert_equal ago(5), Progression.ultimate_window_start(young, LAST)
    assert_equal 0, Progression.unbalanced_weeks_in_window(young, LAST), "weeks before the reach don't count"

    old = ultimate_household(unbalanced(52, 53, 51), reached: 80)
    assert_equal ago(51), Progression.ultimate_window_start(old, LAST)
    assert_equal 1, Progression.unbalanced_weeks_in_window(old, LAST), "the 53rd week back is out"
  end

  test "margin: quota minus the unbalanced weeks, never below 0, nil below the ultimate level" do
    assert_equal 7, Progression.ultimate_margin(ultimate_household({ 0 => "balanced" }))
    assert_equal 4, Progression.ultimate_margin(ultimate_household(unbalanced(0, 3, 9)))
    assert_equal 0, Progression.ultimate_margin(ultimate_household(unbalanced(0, 1, 2, 3, 4, 5, 6)))
    assert_equal 0, Progression.ultimate_margin(ultimate_household(unbalanced(0, 1, 2, 3, 4, 5, 6, 7, 8)))
    assert_nil Progression.ultimate_margin(ultimate_household(unbalanced(0), level: 4))
  end

  test "margin with no final report yet uses the current week" do
    household = ultimate_household({}, reached: 0)
    assert_equal 7, Progression.ultimate_margin(household)
  end
end
