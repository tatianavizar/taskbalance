# Product rules shared by the screens (intro, rules screen) and the weekly
# engine (WeeklyStats, Progression). The values come from
# docs/backend-backlog.md: change them here and every screen and computation
# that uses them follows. No other file repeats these numbers.
module HouseholdRules
  # A week is balanced when every member stays within this many points of the
  # fair share, on both mental load and execution. The check uses the exact
  # (unrounded) share; only the fair share itself is rounded.
  ZONE = 10
  # Cumulative balanced weeks needed for levels 1 to 4, then the ultimate level.
  LEVEL_THRESHOLDS = [ 1, 3, 6, 10, 15 ].freeze
  # The ultimate level is kept while the household has at most this many
  # unbalanced weeks in its window (decision 2026-11-12, replaces the 85 %
  # ratio). Neutral weeks, including those a retroactive pause neutralised
  # (D3), don't count.
  ULTIMATE_UNBALANCED_QUOTA = 7
  # The window starts at the last reach of the ultimate level, capped at this
  # many weeks.
  ULTIMATE_WINDOW_WEEKS = 52

  # A member who logs nothing for this many consecutive counting weeks opens
  # the absence question (E11, P5).
  EMPTY_WEEKS_FOR_INQUIRY = 2
  # The answers to the absence question are open until Wednesday (2 days after
  # the Monday of the closing) at this hour, household time zone.
  ABSENCE_DEADLINE_DAY_OFFSET = 2
  ABSENCE_DEADLINE_HOUR = 20
  # The week report is provisional from Sunday 20:00 and final on the
  # following Monday at 3:00, household time zone.
  REPORT_PROVISIONAL_HOUR = 20
  REPORT_FINAL_HOUR = 3
  # A pause can start this many days back at most (D3).
  PAUSE_RETROACTIVE_DAYS = 14

  # Fair share of one member, in %, for a household of `members` people
  # (100 / members, rounded half up). nil for an empty household.
  def self.fair_share(members)
    return nil if members.to_i <= 0

    (100r / members).round
  end

  # Balanced zone of a member, in %: fair share +/- ZONE.
  def self.zone(members)
    fair = fair_share(members)
    fair && ((fair - ZONE)..(fair + ZONE))
  end
end
