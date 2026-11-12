# One person carrying a chore (backlog 2.2d). A chore shared by two members
# has two rows and counts in full for each of them (decision 2026-11-08).
#
# The assignee is a member (user) or, in the starting split, someone invited
# but not yet in the household (invitation, decision D15).
class ChoreAssignee < ApplicationRecord
  belongs_to :chore, inverse_of: :chore_assignees
  belongs_to :user, optional: true
  belongs_to :invitation, optional: true

  validate :exactly_one_assignee

  # Attributes for a participant key ("user:12", "invitation:5"), or nil.
  def self.attributes_for(key)
    kind, id = key.to_s.split(":", 2)
    return unless id.to_s.match?(/\A\d+\z/)

    case kind
    when "user" then { user_id: id.to_i }
    when "invitation" then { invitation_id: id.to_i }
    end
  end

  # Lot 3 calls this when an invitation is accepted: the chores assigned to
  # the invited person move to their account, and the week plans of the
  # household follow.
  def self.transfer_invitation!(invitation, user)
    transaction do
      where(invitation_id: invitation.id).find_each do |assignee|
        if exists?(chore_id: assignee.chore_id, user_id: user.id)
          assignee.destroy!
        else
          assignee.update!(user_id: user.id, invitation_id: nil)
        end
      end
      WeekPlan.where(household_id: invitation.household_id).find_each do |plan|
        plan.rename_participant!("invitation:#{invitation.id}", "user:#{user.id}")
      end
    end
  end

  def participant_key
    user_id ? "user:#{user_id}" : "invitation:#{invitation_id}"
  end

  private

  def exactly_one_assignee
    errors.add(:base, :one_assignee) unless user_id.present? ^ invitation_id.present?
  end
end
