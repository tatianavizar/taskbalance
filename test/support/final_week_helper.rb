# Stores the final report of a week, as the weekly engine does on Monday 03:00,
# so a test can ask what happens to a log of a closed week (lot 4).
module FinalWeekHelper
  def close_week!(household, week)
    snapshot = WeeklyStats.new(household, week).to_snapshot
    household.household_weeks.create!(snapshot.merge(status: "final", computed_at: Time.current, finalized_at: Time.current))
  end
end
