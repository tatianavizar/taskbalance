# Builders for the lot 6 tests: chores with assignees, final reports with
# given shares, households whose set-up is done.
module SplitHelpers
  def chore!(household, name, users, frequency: :weekly, times: 1, mental: true, execution: true)
    household.chores.create!(custom_name: name, category: "cleaning", time_required: 10, frequency: frequency,
                             times_per_period: times, mental_load: mental, execution_load: execution,
                             assignee_keys: Array(users).map { |u| "user:#{u.id}" })
  end

  # A final report whose members carry the given exact shares:
  # { user => [mental, execution] }. `outcome` defaults from the zone.
  def final_week!(household, week, shares = {}, outcome: nil, paused: [], **by_user)
    shares = shares.merge(by_user) # brace-less { user => [...] } arrives as keywords
    members = shares.map do |user, (mental, execution)|
      { "user_id" => user.id, "first_name" => user.first_name, "mental_share" => mental.round,
        "execution_share" => execution.round, "mental_share_exact" => mental.to_f,
        "execution_share_exact" => execution.to_f, "paused" => paused.include?(user), "logs_count" => 1 }
    end
    outcome ||= shares.values.flatten.all? { |s| (s - (100.0 / shares.size)).abs <= 10 } ? "balanced" : "unbalanced"
    household.household_weeks.create!(week_start: week.monday, time_zone: household.time_zone, status: "final",
                                      outcome: outcome, neutral_reason: (outcome == "neutral" ? "no_mental_logs" : nil),
                                      members: members, computed_at: Time.current, finalized_at: Time.current)
  end

  def plan!(household, week, by: nil, kind: :weekly)
    travel_to(week.start_at + 4.hours) { WeekPlan.propose!(household: household, by: by, week: week, kind: kind) }
  end
end
