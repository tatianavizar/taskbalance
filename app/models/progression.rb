# Household levels, from cumulative balanced weeks (docs/backend-backlog.md,
# "Levels"). Level 0 is the start, 1-4 the levels, 5 the ultimate level.
module Progression
  ULTIMATE = 5
  # Total balanced weeks needed for each level.
  THRESHOLDS = { 1 => 1, 2 => 3, 3 => 6, 4 => 10, ULTIMATE => 15 }.freeze

  ULTIMATE_WINDOW_WEEKS = 52
  ULTIMATE_MIN_RATIO = 0.85r

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

  # Share of balanced weeks among the final, non-neutral weeks of the window
  # ending with `week` (52 weeks, or since creation for a younger household).
  # nil when the window holds no such week.
  #
  # TODO(D5): the ultimate-level margin over the sliding 52-week window is an
  # open product decision (docs/plan-de-travail.md, D5). Until it is decided
  # this is the simplest reading of the backlog: balanced / (balanced +
  # unbalanced) over the final weeks whose Monday is within the last 52
  # Mondays, neutral weeks excluded, "more than 85 %" read as strictly > 0.85.
  # Reaching the ultimate level (the 15th balanced week) is unconditional; the
  # ratio is checked at every later final report.
  def ultimate_ratio(household, week)
    weeks = household.household_weeks.final.where.not(outcome: "neutral")
      .where(week_start: (week.monday - (7 * (ULTIMATE_WINDOW_WEEKS - 1)))..week.monday)
    total = weeks.count
    return nil if total.zero?

    weeks.balanced.count.to_r / total
  end

  # TODO(D5): see ultimate_ratio. An empty window keeps the level.
  def keeps_ultimate?(household, week)
    ratio = ultimate_ratio(household, week)
    ratio.nil? || ratio > ULTIMATE_MIN_RATIO
  end
end
