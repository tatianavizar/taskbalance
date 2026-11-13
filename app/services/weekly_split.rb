# The Monday proposal (backlog 2.2c, D11). Run by WeeklyEngineJob after each
# household's engine run, so the last week's final report is there:
#
#   WeeklySplit.new(household).run(now: Time.current)   # => WeekPlan or nil
#
# From Monday 03:00 (household zone), once the previous week's final report
# exists:
#   1. the carried gap folds in the closed weeks (SplitGap.fold!), even when
#      the weekly proposal is off;
#   2. when weekly_proposal_enabled and the week has no plan yet, the chores
#      are proposed again (SplitProposal, D18) towards compensated targets
#      (SplitGap.targets; fair shares when gap_carry_over_enabled is off),
#      shared chores keeping their assignees, and the week plan is proposed
#      by the app: monday_split goes to every member, and with
#      auto_validate_splits it is validated at once.
# Idempotent: one plan per household and week (a starting plan made this
# week counts), the fold remembers where it stopped. Households still
# setting up, or with fewer than two members, get nothing.
class WeeklySplit
  attr_reader :household

  def initialize(household)
    @household = household
  end

  def run(now: Time.current)
    week = household.week_containing(now)
    return unless due?(week, now)

    SplitGap.fold!(household)
    return unless household.reload.weekly_proposal_enabled
    return if household.week_plan_for(week)

    propose(week)
  end

  private

  def due?(week, now)
    household.setup_done? && household.household_members.count >= 2 &&
      now >= HouseholdWeek.final_at(week.previous) &&
      household.household_weeks.final.exists?(week_start: week.previous.monday)
  end

  def propose(week)
    participants = household.split_participants(include_invitations: false)
    targets = SplitGap.targets(household, participants)
    shared = household.chores.active.joins(:chore_assignees).group(:id).having("count(*) > 1").pluck(:id)

    household.with_lock do
      next household.week_plan_for(week) if household.week_plan_for(week)

      household.propose_split!(keep: shared, targets: targets, participants: participants)
      plan = WeekPlan.propose!(household: household, by: nil, week: week, kind: :weekly)
      plan.update!(targets: targets)
      plan
    end
  rescue ActiveRecord::RecordNotUnique
    household.week_plan_for(week)
  end
end
