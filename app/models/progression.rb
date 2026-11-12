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

  # Final weeks that count in the ultimate ratio: not neutral, and not made
  # neutral by a retroactive pause (WeekCorrection, D3).
  def counted_weeks(household)
    household.household_weeks.final.where.not(outcome: "neutral").uncorrected
  end

  # Share of balanced weeks among the counted weeks of that window.
  # nil when the window holds no such week.
  def ultimate_ratio(household, week)
    weeks = counted_weeks(household).where(week_start: ultimate_window_start(household, week)..week.monday)
    total = weeks.count
    return nil if total.zero?

    weeks.balanced.count.to_r / total
  end

  # D5 (decision 2026-11-12), « il vous reste N semaines »: how many
  # consecutive unbalanced weeks, from the week after the last final report,
  # the household can still have while keeping the ratio strictly above the
  # keep rate. Simulated week by week in the window (from ultimate_reached_on,
  # capped at ULTIMATE_WINDOW_WEEKS, so the oldest weeks drop out as it
  # slides; neutral and corrected weeks excluded). nil when the household is
  # not at the ultimate level.
  def ultimate_margin(household)
    return nil unless household.level == ULTIMATE

    last_monday = household.household_weeks.final.maximum(:week_start)
    return nil if last_monday.nil?

    outcomes = counted_weeks(household).pluck(:week_start, :outcome).to_h
    margin = 0
    (1..(HouseholdRules::ULTIMATE_WINDOW_WEEKS + 1)).each do |k|
      monday = last_monday + (7 * k)
      start = ultimate_window_start(household, Week.new(monday, household.zone))
      window = outcomes.select { |day, _| day >= start && day <= monday }
      balanced = window.count { |_, outcome| outcome == "balanced" }
      simulated_in_window = (1..k).count { |i| last_monday + (7 * i) >= start }
      total = window.size + simulated_in_window
      break unless total.positive? && Rational(balanced, total) > ULTIMATE_MIN_RATIO

      margin = k
    end
    margin
  end

  # Kept while the ratio is strictly above HouseholdRules::ULTIMATE_KEEP_RATE %.
  # An empty window keeps the level.
  def keeps_ultimate?(household, week)
    ratio = ultimate_ratio(household, week)
    ratio.nil? || ratio > ULTIMATE_MIN_RATIO
  end
end
