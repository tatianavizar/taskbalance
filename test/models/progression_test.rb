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

  # TODO(D5): provisional reading, see Progression.ultimate_ratio.
  test "the ultimate ratio counts final non-neutral weeks over the last 52 Mondays" do
    household, = build_household("Alice", "Bob")
    last = Week.containing(Date.new(2027, 10, 4), PARIS)
    add = ->(weeks_ago, outcome, status = "final") do
      household.household_weeks.create!(week_start: last.monday - (7 * weeks_ago), time_zone: PARIS, status: status,
        outcome: outcome, neutral_reason: (outcome == "neutral" ? "no_mental_logs" : nil), computed_at: Time.current)
    end

    assert_nil Progression.ultimate_ratio(household, last)
    assert Progression.keeps_ultimate?(household, last)

    add.(52, "unbalanced") # outside the window
    add.(51, "balanced")
    add.(10, "neutral")
    add.(1, "unbalanced", "provisional")
    6.times { add.(_1 + 2, "balanced") }
    add.(0, "unbalanced")

    assert_equal Rational(7, 8), Progression.ultimate_ratio(household, last)
    assert Progression.keeps_ultimate?(household, last)
  end
end
