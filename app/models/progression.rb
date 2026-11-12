# Household levels, from cumulative balanced weeks (docs/backend-backlog.md,
# "Levels"). Level 0 is the start, 1-4 the levels, the last one the ultimate
# level. Every number comes from HouseholdRules.
module Progression
  # Level n needs HouseholdRules::LEVEL_THRESHOLDS[n - 1] balanced weeks.
  THRESHOLDS = HouseholdRules::LEVEL_THRESHOLDS.each_with_index.to_h { |weeks, i| [ i + 1, weeks ] }.freeze
  ULTIMATE = HouseholdRules::LEVEL_THRESHOLDS.size

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
  # `week` (decision 2026-11-12): households.ultimate_reached_on, capped at the
  # last HouseholdRules::ULTIMATE_WINDOW_WEEKS weeks (`week` included).
  # ultimate_reached_on moves at each reach by thresholds (the first one, or
  # one after a regression or a membership reset); a regain after the quota
  # was exceeded does not move it, or the quota could be dodged.
  def ultimate_window_start(household, week)
    cap = week.monday - (7 * (HouseholdRules::ULTIMATE_WINDOW_WEEKS - 1))
    [ household.ultimate_reached_on, cap ].compact.max
  end

  # Unbalanced final weeks of that window. Neutral weeks don't count, nor
  # weeks a retroactive pause neutralised (WeekCorrection, D3).
  def unbalanced_weeks_in_window(household, week)
    household.household_weeks.final.unbalanced.uncorrected
      .where(week_start: ultimate_window_start(household, week)..week.monday).count
  end

  # Kept while the window holds at most HouseholdRules::ULTIMATE_UNBALANCED_QUOTA
  # unbalanced weeks.
  def keeps_ultimate?(household, week)
    unbalanced_weeks_in_window(household, week) <= HouseholdRules::ULTIMATE_UNBALANCED_QUOTA
  end

  # « Il vous reste N semaines » (E9): quota minus the unbalanced weeks in the
  # window ending with the last final report, never below 0. nil below the
  # ultimate level.
  def ultimate_margin(household)
    return nil unless household.level == ULTIMATE

    last_monday = household.household_weeks.final.maximum(:week_start)
    week = last_monday ? Week.new(last_monday, household.zone) : household.current_week
    [ HouseholdRules::ULTIMATE_UNBALANCED_QUOTA - unbalanced_weeks_in_window(household, week), 0 ].max
  end
end
