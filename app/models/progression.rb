# Household levels, from cumulative balanced weeks (docs/backend-backlog.md,
# "Levels"). Level 0 is the start, 1-4 the levels, the last one the ultimate
# level. Every number comes from HouseholdRules.
module Progression
  # Level n needs HouseholdRules::LEVEL_THRESHOLDS[n - 1] balanced weeks.
  THRESHOLDS = HouseholdRules::LEVEL_THRESHOLDS.each_with_index.to_h { |weeks, i| [ i + 1, weeks ] }.freeze
  ULTIMATE = HouseholdRules::LEVEL_THRESHOLDS.size
  ULTIMATE_MIN_RATIO = Rational(HouseholdRules::ULTIMATE_KEEP_RATE, 100)

  module_function

  def threshold(level)
    level.zero? ? 0 : THRESHOLDS.fetch(level)
  end

  # Highest level whose threshold `count` reaches.
  def level_for(count)
    THRESHOLDS.select { |_, needed| count >= needed }.keys.max || 0
  end

  # One level down after two empty weeks; the counter goes back to the
  # threshold of the new level (level 3 -> 2 sets it to 3). Level 0 stays 0.
  def regressed_level(level)
    [ level - 1, 0 ].max
  end

  # First Monday of the window that keeps the ultimate level, for a report on
  # `week`: the week the household first reached the ultimate level
  # (households.ultimate_reached_on), capped at the last
  # HouseholdRules::ULTIMATE_WINDOW_WEEKS weeks (`week` included). Losing and
  # regaining the level does not restart it (product owner, 2026-11-12).
  def ultimate_window_start(household, week)
    cap = week.monday - (7 * (HouseholdRules::ULTIMATE_WINDOW_WEEKS - 1))
    [ household.ultimate_reached_on, cap ].compact.max
  end

  # Share of balanced weeks among the final, non-neutral weeks of that window.
  # nil when the window holds no such week.
  def ultimate_ratio(household, week)
    weeks = household.household_weeks.final.where.not(outcome: "neutral")
      .where(week_start: ultimate_window_start(household, week)..week.monday)
    total = weeks.count
    return nil if total.zero?

    weeks.balanced.count.to_r / total
  end

  # Kept while the ratio is strictly above HouseholdRules::ULTIMATE_KEEP_RATE %.
  # An empty window keeps the level.
  def keeps_ultimate?(household, week)
    ratio = ultimate_ratio(household, week)
    ratio.nil? || ratio > ULTIMATE_MIN_RATIO
  end
end
