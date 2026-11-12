# The split of one week, as the household validated it (backlog 2.2c,
# decisions D14, D15, D18 and those of 2026-11-08).
#
#   kind      starting: the first split, made during the set-up (C4, C12,
#             B11, B14). It can count someone invited but not yet in
#             (provisional, D15). weekly: the Monday proposal (lot 6).
#   status    awaiting_proposal: the creator chose « Attendre » (C12); the
#             invited person proposes when joining (B14).
#             proposed: waiting for validations. Any participant can edit it;
#             an edit counts as the editor's validation and asks the others
#             again.
#             validated: everyone validated, or the household validates
#             automatically (C16). Locked until the next Monday: edits to the
#             chores then go to the next proposal (D14).
#
# The snapshot (participants, assignments, shares) is written at each
# proposal or edit, so a validated plan stays as it was whatever happens to
# the chores: a chore removed mid-week stays planned until Sunday, a chore
# added mid-week is logged « hors répartition » (planned_chore_ids).
#
# Interface for lots 4 and 6:
#   WeekPlan.propose!(household:, by:, week:, kind:)  snapshot + validation
#   plan.update_assignments!(by:, assignments: { chore_id => [keys] })
#   plan.approve!(by:)             one person's validation
#   plan.split                     PlannedSplit (items, shares, exact?)
#   plan.pending_participants      who has not validated yet
#   plan.planned_chore_ids         chores in this week's split
#   plan.recompute!               C12: again from the preferences (lot 3)
#   plan.locked? / validated?
class WeekPlan < ApplicationRecord
  class Locked < StandardError; end
  class NotAParticipant < StandardError; end

  belongs_to :household
  belongs_to :proposed_by, class_name: "User", optional: true
  has_many :approvals, as: :approvable, dependent: :delete_all

  enum :status, { awaiting_proposal: "awaiting_proposal", proposed: "proposed", validated: "validated" },
       validate: true
  enum :kind, { starting: "starting", weekly: "weekly" }, validate: true

  validates :week_start, presence: true, uniqueness: { scope: :household_id }
  validate :week_start_is_a_monday

  # Starts the week's split from the household's chores and their current
  # assignees, with `by`'s validation (nil: proposed by the app, lot 6).
  # Validated at once when every participant has validated or the household
  # validates automatically.
  def self.propose!(household:, by:, week: household.current_week, kind: :weekly)
    plan = household.week_plans.find_or_initialize_by(week_start: week.monday)
    raise Locked if plan.validated?

    plan.kind = kind
    plan.transaction do
      plan.write_snapshot(by: by)
      plan.save!
      plan.approvals.delete_all
      plan.record_approval(by) if by
      plan.validate_if_complete!
    end
    plan.announce_proposal(by)
    plan
  end

  # C12 « Attendre » : the set-up ends without a split; the invited person
  # proposes it when joining (B14).
  def self.await_proposal!(household:, week: household.current_week)
    plan = household.week_plans.find_or_initialize_by(week_start: week.monday)
    raise Locked if plan.validated?

    plan.update!(kind: :starting, status: :awaiting_proposal, proposed_by: nil, proposed_at: nil,
                 provisional: household.pending_invitations.any?,
                 participants: household.split_participants.map(&:to_h), assignments: [], shares: {})
    plan
  end

  def week
    Week.new(week_start, household.zone)
  end

  def locked?
    validated?
  end

  def participant_list
    participants.map { |hash| SplitParticipant.from_h(hash) }
  end

  def split
    PlannedSplit.new(items: assignments.map { |hash| PlannedSplit::Item.from_h(hash) },
                     participants: participant_list, week: week)
  end

  def planned_chore_ids
    assignments.map { |item| item["chore_id"] }
  end

  def includes_chore?(chore)
    planned_chore_ids.include?(chore.id)
  end

  # `user` takes part in this plan (a member, or an invited person with an
  # account).
  def participant?(user)
    user && participant_list.any? { |p| participant_user_id(p) == user.id }
  end

  # Participants still expected to validate, in display order. A person
  # invited without an account yet is always pending.
  def pending_participants
    approved = approvals.pluck(:user_id)
    participant_list.reject { |p| (id = participant_user_id(p)) && approved.include?(id) }
  end

  def approved_by?(user)
    approvals.exists?(user_id: user.id)
  end

  # Edit by a participant: writes the household's assignments for the given
  # chores, takes a new snapshot, and asks the others to validate again. The
  # edit counts as `by`'s validation.
  def update_assignments!(by:, assignments:)
    raise Locked if locked?
    raise NotAParticipant unless household.split_participant_for(by)

    transaction do
      household.assign_chores!(assignments, by: by)
      write_snapshot(by: by)
      save!
      approvals.delete_all
      record_approval(by)
      validate_if_complete!
    end
    self
  end

  # One person's validation. Returns true once the plan is validated.
  def approve!(by:)
    raise NotAParticipant unless participant?(by)
    return true if validated?

    transaction do
      record_approval(by)
      validate_if_complete!
    end
    validated?
  end

  # C12 « Proposer maintenant »: the provisional split is recomputed once the
  # invited person has given their preferences (lot 3 calls this). Every
  # assignment is proposed again (D18), the proposer's validation stays, the
  # others are asked again.
  def recompute!
    raise Locked if locked?
    return self if awaiting_proposal?

    transaction do
      household.propose_split!
      write_snapshot(by: proposed_by)
      save!
      approvals.where.not(user_id: proposed_by_id).delete_all
      validate_if_complete!
    end
    self
  end

  # Lot 3: an invitation became a member account.
  # The key only names the person: a locked plan is renamed too, its split
  # does not change.
  def rename_participant!(from_key, to_key)
    user_id = to_key.split(":").last.to_i
    self.participants = participants.map do |p|
      p["key"] == from_key ? p.merge("key" => to_key, "user_id" => user_id, "provisional" => false) : p
    end
    self.assignments = assignments.map { |item| item.merge("assignees" => item["assignees"].map { |k| k == from_key ? to_key : k }) }
    self.shares = shares.transform_keys { |k| k == from_key ? to_key : k }
    self.provisional = participant_list.any?(&:provisional?)
    save!
  end

  # --- used by the class methods above ---

  def write_snapshot(by:)
    participants = household.split_participants(include_invitations: starting?)
    split = PlannedSplit.from_household(household, week: week, participants: participants)
    self.status = :proposed
    self.proposed_by = by
    self.proposed_at = Time.current
    self.provisional = participants.any?(&:provisional?)
    self.participants = participants.map(&:to_h)
    self.assignments = split.items.map(&:to_h)
    self.shares = split.shares.transform_values { |s| { "mental" => s.mental, "execution" => s.execution, "average" => s.average } }
  end

  # Lot 8a: the members other than the proposer hear that a split waits for
  # them (monday_split), with how many tasks each member has this week.
  def announce_proposal(by)
    members = household.users.to_a
    recipients = members.reject { |user| user == by }
    return if recipients.empty?

    counts = members.to_h do |user|
      [ user, assignments.count { |item| item["occurrences"].to_i.positive? && item["assignees"].include?("user:#{user.id}") } ]
    end
    Notifications::Notifier.call(Notifications::Events::MondaySplit.new(household, week, counts), to: recipients)
  end

  def record_approval(user)
    approvals.find_or_create_by!(user: user)
  end

  def validate_if_complete!
    return unless household.auto_validate_splits? || pending_participants.empty?

    update!(status: :validated, validated_at: Time.current)
  end

  private

  # An invited person in the snapshot may have claimed the invitation since
  # (lot 3): their account is read from the invitation.
  def participant_user_id(participant)
    participant.user_id || (participant.invitation_id && Invitation.where(id: participant.invitation_id).pick(:invitee_id))
  end

  def week_start_is_a_monday
    errors.add(:week_start, :not_a_monday) if week_start && !week_start.monday?
  end
end
