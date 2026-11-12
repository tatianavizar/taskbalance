# Product rules shared by the screens (intro, rules screen) and, later, the
# weekly engine. The values come from docs/backend-backlog.md: change them here
# and every screen that quotes them follows.
module HouseholdRules
  # A week is balanced when every member stays within this many points of the
  # fair share, on both mental load and execution.
  ZONE = 10
  # Cumulative balanced weeks needed for levels 1 to 4, then the ultimate level.
  LEVEL_THRESHOLDS = [ 1, 3, 6, 10, 15 ].freeze
  # Share of balanced weeks over the last 52 needed to keep the ultimate level.
  ULTIMATE_KEEP_RATE = 85

  # Fair share of one member, in %, for a household of `members` people.
  def self.fair_share(members)
    (100.0 / members).round
  end

  # Balanced zone of a member, in %: fair share +/- ZONE.
  def self.zone(members)
    fair = fair_share(members)
    (fair - ZONE)..(fair + ZONE)
  end
end
