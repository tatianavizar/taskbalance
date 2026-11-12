# What the levels screen shows (E8, E9, E13): where the household stands on
# the ladder, how far the next level is and, at the ultimate level, the margin
# before it is lost. Read only; the numbers come from HouseholdRules and
# Progression, the history from LevelChange.
#
#   summary = LevelSummary.new(household)
#   summary.level / weeks                      # level 0..5, balanced weeks counted
#   summary.ladder                             # [{ level:, weeks:, reached:, current: }]
#   summary.next_level / weeks_to_next         # nil at the ultimate level
#   summary.ultimate?
#   summary.margin                             # Progression.ultimate_margin: weeks left, nil below
#   summary.unbalanced_in_window / neutral_in_window / weeks_in_window
#   summary.last_change                        # the latest LevelChange, or nil
#   summary.history                            # latest changes, newest first
#   summary.carrier_of(change)                 # who carried more in the week that dropped the level
class LevelSummary
  HISTORY_SIZE = 10

  attr_reader :household

  def initialize(household)
    @household = household
  end

  def level = household.level

  def weeks = household.balanced_weeks_count

  def ultimate? = household.ultimate_level?

  def ladder
    (1..Progression::ULTIMATE).map do |n|
      { level: n, weeks: Progression.threshold(n), reached: level >= n, current: level == n }
    end
  end

  def next_level = ultimate? ? nil : level + 1

  def weeks_to_next
    return nil if ultimate?

    [ Progression.threshold(level + 1) - weeks, 0 ].max
  end

  def margin = Progression.ultimate_margin(household)

  # The window of the ultimate level, as Progression measures it.
  def window
    return @window if defined?(@window)

    last = household.household_weeks.final.maximum(:week_start)
    reference = last ? Week.new(last, household.zone) : household.current_week
    start = Progression.ultimate_window_start(household, reference)
    @window = { reference: reference, start: start, range: start..reference.monday }
  end

  def weeks_in_window
    ((window[:range].end - window[:range].begin) / 7).to_i + 1
  end

  def unbalanced_in_window
    Progression.unbalanced_weeks_in_window(household, window[:reference])
  end

  # Neutral weeks of the window, those a pause neutralised afterwards included:
  # none of them counts against the quota.
  def neutral_in_window
    weeks = household.household_weeks.final.where(week_start: window[:range])
    corrected = weeks.where(id: WeekCorrection.select(:household_week_id)).where.not(outcome: "neutral").count
    weeks.neutral.count + corrected
  end

  def last_change
    @last_change ||= household.level_changes.chronological.last
  end

  def history
    @history ||= household.level_changes.chronological.reverse_order.limit(HISTORY_SIZE).to_a
  end

  # The final report that took the level down (E13): who carried more.
  def carrier_of(change)
    record = change.household_week
    return unless record

    report = WeekReport.from_record(household, record)
    report.headline
  end
end
