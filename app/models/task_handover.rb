# One-off reassignment (D15, D16; backlog 2.2c). During the week, a member
# offers one of their tasks to another member; the other accepts or refuses.
# It applies to that week only and never changes the validated split nor the
# chore's standing assignees: the weekly report counts logs, never the plan.
# Text (D2): the task is « prévue » in the other person's charge.
#
#   TaskHandover.offer!(chore:, from:, to:, week:)   D15
#   handover.accept!(by:) / refuse!(by:) / cancel!(by:)   D16
#   TaskHandover.planned_assignee_keys(household, week, chore, keys)
#     the chore's assignees for that week, accepted handovers applied
#     (for the Tasks tab, lot 4)
class TaskHandover < ApplicationRecord
  class Refused < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("task handover refused: #{reason}")
    end
  end

  belongs_to :household
  belongs_to :chore
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"

  enum :status, { pending: "pending", accepted: "accepted", refused: "refused", cancelled: "cancelled" }, validate: true

  scope :live, -> { where(status: %w[pending accepted]) }
  scope :for_week, ->(week) { where(week_start: week.monday) }

  # The chores `user` may offer this week: theirs in the week's plan (the
  # standing assignees when there is no plan), not already offered.
  def self.offerable_chores(household, user, week = household.current_week)
    key = "user:#{user.id}"
    plan = household.week_plan_for(week)
    ids =
      if plan && !plan.awaiting_proposal?
        plan.assignments.select { |item| item["assignees"].include?(key) && item["occurrences"].to_i.positive? }.map { |item| item["chore_id"] }
      else
        household.chores.active.joins(:chore_assignees).where(chore_assignees: { user_id: user.id }).pluck(:id)
      end
    offered = household.task_handovers.live.for_week(week).where(from_user: user).pluck(:chore_id)
    household.chores.where(id: ids - offered).order(:id)
  end

  def self.offer!(chore:, from:, to:, week: chore.household.current_week)
    household = chore.household
    raise Refused, :not_a_member unless household.users.exists?(from.id) && household.users.exists?(to&.id)
    raise Refused, :same_person if from == to
    raise Refused, :not_yours unless offerable_chores(household, from, week).exists?(chore.id)
    raise Refused, :already_assigned if planned_assignee_keys(household, week, chore).include?("user:#{to.id}")

    handover = household.task_handovers.create!(chore: chore, from_user: from, to_user: to, week_start: week.monday)
    Notifications::Notifier.call(Notifications::Events::TaskOffered.new(handover))
    handover
  rescue ActiveRecord::RecordNotUnique
    raise Refused, :already_offered
  end

  # The chore's assignees planned for `week`: the plan's (else the standing
  # ones), with accepted handovers applied.
  def self.planned_assignee_keys(household, week, chore)
    plan = household.week_plan_for(week)
    item = plan&.assignments&.find { |i| i["chore_id"] == chore.id }
    keys = item ? item["assignees"].dup : chore.assignee_keys
    household.task_handovers.accepted.for_week(week).where(chore: chore).find_each do |handover|
      keys.delete("user:#{handover.from_user_id}")
      keys << "user:#{handover.to_user_id}" unless keys.include?("user:#{handover.to_user_id}")
    end
    keys
  end

  def week
    Week.new(week_start, household.zone)
  end

  def open?(now = Time.current)
    pending? && now <= week.end_at
  end

  def accept!(by:, now: Time.current)
    answer!(by, :accepted, now)
  end

  def refuse!(by:, now: Time.current)
    answer!(by, :refused, now)
  end

  def cancel!(by:, now: Time.current)
    raise Refused, :not_yours unless by == from_user
    raise Refused, :closed unless open?(now)

    update!(status: :cancelled, responded_at: now)
  end

  private

  def answer!(by, status, now)
    raise Refused, :not_for_you unless by == to_user
    raise Refused, :closed unless open?(now)

    update!(status: status, responded_at: now)
    Notifications::Notifier.call(Notifications::Events::TaskOfferAnswered.new(self))
    self
  end
end
