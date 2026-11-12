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
  # Share of balanced weeks, in %, the ultimate level needs to be kept: the
  # ratio must be strictly above it.
  ULTIMATE_KEEP_RATE = 85
  # The ratio is measured over the final weeks since the ultimate level was
  # first reached, capped at this many weeks.
  ULTIMATE_WINDOW_WEEKS = 52

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
