# The carried-over gap (backlog 2.2c, decisions of 2026-11-08 and D4).
#
# == The formula
# For a closed week (its final HouseholdWeek, not neutral), each active
# member's real gap is
#
#   gap = (mental share + execution share) / 2 − 100 / active members
#
# with the exact (unrounded) shares of the report: the average of the two
# charges, so it can be compensated through either. A member's balance is the
# sum of their real gaps since the last reset: it stays until real weeks
# compensate it. Monday's proposal aims each participant at
#
#   target = 100 / participants − balance, kept inside the zone
#            (HouseholdRules.zone: fair share ± 10)
#
# so only what fits in the zone is compensated in one week; the rest of the
# balance stays carried, and the next real gap moves it.
#
# Worked example, two members, fair share 50, zone 40–60:
#   week 1 closes with Alice mental 70 %, execution 60 % → average 65 →
#     Alice +15, Bob −15.
#   Monday: targets Alice 50 − 15 = 35 → kept at 40; Bob 65 → kept at 60.
#   week 2 closes with Alice 42 % on both → gap −8 → balance +15 − 8 = +7.
#   Monday: targets Alice 43, Bob 57.
#
# Not folded in: neutral weeks (nothing moves), weeks before the household's
# first plan, weeks while gap_carry_over_enabled is off, and a week whose plan
# was saved out of the zone « sans reporter l'écart » (WeekPlan#carry_gap).
#
# == Reset (C9, D4)
# Only a member who carried the surplus (positive balance) can reset, and it
# waives their own surplus: their balance goes to zero, and the members on
# the other side see theirs reduced in proportion (at two, both reach zero).
# The others are notified (gap_reset).
module SplitGap
  # A balance smaller than this shows as « 0 % » and gives no right to reset.
  CARRIER_MIN = 0.5

  class NotACarrier < StandardError; end

  module_function

  # { user_id => Float } for the household's current members (0.0 when none).
  def balances(household)
    ids = household.household_members.pluck(:user_id)
    sums = household.split_gap_entries.where(user_id: ids).group(:user_id).sum(:amount)
    ids.index_with { |id| sums.fetch(id, 0).to_f }
  end

  def balance_of(household, user)
    balances(household).fetch(user&.id, 0.0)
  end

  # Members who carried the surplus: the ones who may reset (D4).
  def carrier_ids(household)
    balances(household).select { |_, balance| balance >= CARRIER_MIN }.keys
  end

  def carrier?(household, user)
    user.present? && carrier_ids(household).include?(user.id)
  end

  # Real gaps of one final week: { user_id => Float }, empty when neutral.
  def week_gaps(household_week)
    return {} if household_week.effective_outcome == "neutral"

    active = household_week.members.reject { |m| m["paused"] }
    return {} if active.empty?

    fair = 100.0 / active.size
    active.each_with_object({}) do |m, gaps|
      shares = [ m["mental_share_exact"] || m["mental_share"], m["execution_share_exact"] || m["execution_share"] ].compact
      gaps[m["user_id"]] = (shares.sum.to_f / shares.size) - fair if shares.any?
    end
  end

  # Folds every final week not folded yet, oldest first, from the household's
  # first plan. Idempotent (households.gap_folded_through).
  def fold!(household)
    household.with_lock do
      start = household.gap_folded_through ? household.gap_folded_through + 7 : household.week_plans.minimum(:week_start)
      next if start.nil?

      household.household_weeks.final.where(week_start: start..).order(:week_start).each do |household_week|
        plan = household.week_plans.find_by(week_start: household_week.week_start)
        if household.gap_carry_over_enabled && (plan.nil? || plan.gap_carried?)
          week_gaps(household_week).each do |user_id, gap|
            next if gap.abs < 0.0005

            household.split_gap_entries.create!(kind: :week, week_start: household_week.week_start,
                                                user_id: user_id, amount: gap.round(3))
          end
        end
        household.update!(gap_folded_through: household_week.week_start)
      end
    end
  end

  # Monday's targets, { participant key => % }: fair share minus balance,
  # kept inside the zone. Fair shares when the carry-over is off.
  def targets(household, participants)
    return {} if participants.empty?

    fair = 100.0 / participants.size
    zone = HouseholdRules.zone(participants.size)
    current = household.gap_carry_over_enabled ? balances(household) : {}
    participants.to_h do |participant|
      [ participant.key, (fair - current.fetch(participant.user_id, 0.0)).clamp(zone.min, zone.max) ]
    end
  end

  # C9. Returns the resetter's entry. Raises NotACarrier for anyone else.
  def reset!(household, by:, week: household.current_week)
    entry = household.with_lock do
      current = balances(household)
      waived = current.fetch(by&.id, 0.0)
      raise NotACarrier if by.nil? || waived < CARRIER_MIN

      owed = current.select { |_, balance| balance.negative? }
      owed_total = owed.values.sum.abs
      owed.each do |user_id, balance|
        back = owed_total.zero? ? 0 : [ waived * balance.abs / owed_total, balance.abs ].min
        household.split_gap_entries.create!(kind: :reset, week_start: week.monday, user_id: user_id,
                                            amount: back.round(3), reset_by: by)
      end
      household.split_gap_entries.create!(kind: :reset, week_start: week.monday, user_id: by.id,
                                          amount: -waived.round(3), reset_by: by)
    end
    others = household.users.where.not(id: by.id).to_a
    Notifications::Notifier.call(Notifications::Events::GapReset.new(household, week, token: "reset-#{entry.id}"), to: others)
    entry
  end
end
