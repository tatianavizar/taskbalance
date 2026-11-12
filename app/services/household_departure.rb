# A member leaves their household (F2, docs/backend-backlog.md 3.3). Called
# through HouseholdMember#leave!, so every path out of a household (the F2
# button, account deletion, tests) cleans up the same way. One transaction,
# under a lock on the household:
#
#   chores        a chore the leaver shared loses them; a chore only they
#                 carried goes to every remaining member. No chore is left
#                 without an assignee. The next Monday proposal (lot 6) reviews
#                 them like any other assignment.
#   week plans    the current and later plans drop the leaver from their
#                 snapshot with the same rule (WeekPlan#remove_participant!);
#                 past plans are history and stay.
#   validations   the leaver's validation of a pending split-settings change
#                 is withdrawn, and the change applies if everyone left agreed.
#   preferences   their likes on this household's chores go (private, useless
#                 once out).
#   logs          stay theirs: household_id and chore_id are nullified, the
#                 snapshotted chore_name/category keep them readable. The
#                 household keeps its past totals (household_weeks, untouched)
#                 without the detail of the leaver's tasks.
#   absence       any inquiry about the leaver goes with their membership
#                 (cancelled: there is nobody left to ask about).
#   notifications the leaver's ones about this household that are not due yet
#                 (the report or alerts written at 03:00, sent at 08:00) are
#                 withdrawn; the mailer checks membership again at sending.
#   live streams  the leaver's Action Cable connections are dropped: on
#                 reconnecting they can no longer subscribe to this household.
#   manager       the oldest remaining member takes over.
#   progression   reset by HouseholdMember's after_destroy (membership change);
#                 not repeated here.
#
# The last member leaving deletes the household (nobody can reach it again):
# chores, plans and progression go, logs are detached as above, live
# invitations are cancelled.
#
# Returns the new manager's membership, or nil.
class HouseholdDeparture
  def self.call(membership)
    new(membership).call
  end

  def initialize(membership)
    @membership = membership
    @household = membership.household
    @user_id = membership.user_id
  end

  def call
    successor = nil
    Household.transaction do
      household.lock!
      remaining = household.household_members.where.not(id: membership.id).order(:created_at, :id).to_a
      remaining_keys = remaining.map { |member| "user:#{member.user_id}" }

      hand_over_chores!(remaining.map(&:user_id))
      update_week_plans!(remaining_keys) if remaining.any?
      withdraw_setting_approvals!
      drop_preferences!
      detach_logs!
      membership.absence_inquiries.delete_all
      Notification.suppress_for_departure!(user_id: user_id, household_id: household.id)

      was_manager = membership.manager?
      membership.destroy!

      if remaining.empty?
        close_empty_household!
      else
        if was_manager
          successor = remaining.first
          successor.manager!
        end
        household.split_setting_changes.pending.find_each(&:apply_if_complete!)
      end
    end
    membership.user&.association(:household_membership)&.reset
    disconnect_live_streams!
    successor
  end

  private

  attr_reader :membership, :household, :user_id

  def hand_over_chores!(remaining_user_ids)
    leaver_rows = ChoreAssignee.joins(:chore).where(user_id: user_id, chores: { household_id: household.id })
    chore_ids = leaver_rows.pluck(:chore_id)
    ChoreAssignee.where(id: leaver_rows.select(:id)).delete_all
    return if remaining_user_ids.empty?

    orphaned = chore_ids - ChoreAssignee.where(chore_id: chore_ids).distinct.pluck(:chore_id)
    now = Time.current
    rows = orphaned.product(remaining_user_ids).map do |chore_id, id|
      { chore_id: chore_id, user_id: id, created_at: now }
    end
    ChoreAssignee.insert_all!(rows) if rows.any?
    Chore.where(id: orphaned).touch_all if orphaned.any?
  end

  def update_week_plans!(remaining_keys)
    household.week_plans.where(week_start: household.current_week.monday..).find_each do |plan|
      plan.remove_participant!("user:#{user_id}", replacements: remaining_keys)
    end
  end

  def withdraw_setting_approvals!
    Approval.where(user_id: user_id, approvable: household.split_setting_changes.pending).delete_all
  end

  def drop_preferences!
    ChorePreference.where(user_id: user_id, chore_id: household.chores.select(:id)).delete_all
  end

  def detach_logs!
    ChoreLog.where(user_id: user_id, household_id: household.id).update_all(household_id: nil, chore_id: nil)
  end

  def disconnect_live_streams!
    user = membership.user
    ActionCable.server.remote_connections.where(current_user: user).disconnect(reconnect: true) if user
  end

  def close_empty_household!
    household.invitations.live.find_each(&:cancel!)
    Approval.where(approvable: household.week_plans).delete_all
    Approval.where(approvable: household.split_setting_changes).delete_all
    household.reload.destroy!
  end
end
