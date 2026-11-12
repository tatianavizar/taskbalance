class Household < ApplicationRecord
  include TimeZoned

  NAME_MAX_LENGTH = 60

  has_many :household_members, dependent: :destroy
  has_many :users, through: :household_members
  has_many :chores, dependent: :destroy
  has_many :recurring_chores, dependent: :destroy
  # Logs are the members' own data and survive the household being deleted.
  has_many :chore_logs, dependent: :nullify
  has_many :invitations, dependent: :destroy
  # Weekly engine (lot 5a). Final reports are read-only records, so they go
  # with SQL deletes (the foreign keys also cascade).
  has_many :household_weeks, dependent: :delete_all
  has_many :level_changes, dependent: :delete_all
  has_many :absence_inquiries, dependent: :delete_all
  has_many :week_corrections, dependent: :delete_all
  has_many :member_pauses, through: :household_members
  # Split (lot 2): week plans and pending changes of the split settings.
  has_many :week_plans, dependent: :delete_all
  has_many :split_setting_changes, dependent: :delete_all

  # Set-up checklist (« Mise en place 2 sur 4 »): the step to resume at.
  # Step 1, naming the household, is done once it exists.
  SETUP_STEPS = %w[partner tasks split].freeze
  SETUP_STEP_LABELS = %w[household partner tasks split].freeze

  # setting_up is set by the setup flow (lot 2); solo/active follow the member
  # count; warned, blocked and dormant are set by WeeklyEngine at the final
  # report (docs/backend-backlog.md 2.2).
  enum :state, {
    setting_up: "setting_up", solo: "solo", active: "active",
    warned: "warned", blocked: "blocked", dormant: "dormant"
  }, default: "solo", validate: true

  before_validation { self.name = name.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :setup_step, inclusion: { in: SETUP_STEPS + [ "done" ] }

  # Creates the household and makes `user` its manager, in one transaction.
  # Returns the household: check `persisted?` and `errors`. A user who already
  # has a household gets an error on :base and nothing is created.
  def self.create_for(user, attributes = {})
    household = new(attributes)
    household.setup_step = SETUP_STEPS.first
    # The household starts in its creator's time zone unless one is given.
    household.time_zone = user.time_zone if attributes.to_h.with_indifferent_access[:time_zone].blank?

    if user.household_membership.present?
      household.errors.add(:base, :user_already_in_household)
      return household
    end

    transaction do
      raise ActiveRecord::Rollback unless household.save

      household.household_members.create!(user: user, role: :manager)
    end
    household
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    household.errors.add(:base, :user_already_in_household)
    household
  end

  def ultimate_level?
    level == Progression::ULTIMATE
  end

  # Called when a member arrives or leaves: the only state transitions that do
  # not wait for a final report. Blocked and setting_up are left alone.
  def refresh_membership_state!
    return if blocked? || setting_up?

    count = household_members.count
    if count < 2 && !solo?
      update!(state: "solo")
    elsif count >= 2 && solo?
      update!(state: "active")
    end
  end

  def manager
    household_members.manager.order(:created_at, :id).first&.user
  end

  # --- Set-up ------------------------------------------------------------

  def setup_done?
    setup_step == "done"
  end

  # 1 to 4, the step shown as current (« Mise en place 2 sur 4 »).
  def setup_step_number
    setup_done? ? SETUP_STEP_LABELS.size : SETUP_STEPS.index(setup_step) + 2
  end

  # Moves the checklist past `step`. Never goes back: finishing an earlier
  # step again (editing the tasks from the household page) changes nothing.
  def complete_setup_step!(step)
    return if setup_done?

    index = SETUP_STEPS.index(step.to_s)
    return if index.nil? || index < SETUP_STEPS.index(setup_step)

    update!(setup_step: SETUP_STEPS[index + 1] || "done")
  end

  # --- Split -------------------------------------------------------------

  # Invitations still waiting for an answer. Lot 3 adds their states; until
  # then an invitation whose email already belongs to a member is the only
  # one that is not pending.
  def pending_invitations
    invitations.where.not(email: users.select(:email)).order(:id)
  end

  # The people a split is made for, in display order: members by arrival,
  # then (for the starting split) people invited but not yet in (D15).
  def split_participants(include_invitations: true)
    members = household_members.includes(:user).order(:created_at, :id).to_a
    participants = members.map { |member| SplitParticipant.for_member(member) }
    return participants unless include_invitations

    free_colors = HouseholdMember::COLORS - members.map(&:color)
    participants + pending_invitations.each_with_index.map do |invitation, index|
      SplitParticipant.for_invitation(invitation, color: free_colors[index] || HouseholdMember::COLORS.last)
    end
  end

  # The participant acting as `user`: a member, or someone invited who has
  # not joined yet (B10, B11, B14). nil when `user` has no part in the split.
  def split_participant_for(user)
    return if user.nil?

    split_participants.find { |p| p.user_id == user.id } || invitee_participant_for(user)
  end

  # Stub until lot 3 links an invitation to the invited person's account
  # (invitations.invitee_id): pre-join access to the preferences and the
  # split goes through here.
  def invitee_participant_for(_user)
    nil
  end

  # The starting split, if the set-up has made one.
  def starting_plan
    week_plans.starting.order(:week_start).last
  end

  def week_plan_for(week = current_week)
    week_plans.find_by(week_start: week.monday)
  end

  # Writes the assignees of several chores at once, { chore_id => [keys] },
  # for this household's chores only. Raises ActiveRecord::RecordInvalid
  # (nothing written) when a chore would have no assignee or an assignee is
  # not a participant.
  def assign_chores!(assignments)
    assignments = assignments.to_h.transform_keys(&:to_i)
    transaction do
      chores.where(id: assignments.keys).includes(:chore_assignees, :task).find_each do |chore|
        chore.assignee_keys = assignments[chore.id]
        chore.save!
      end
    end
  end

  # Assigns chores from the proposal (D18). `keep`: chore ids whose
  # assignees stay. Returns the proposal.
  def propose_split!(keep: [])
    proposal = SplitProposal.for_household(self, keep: keep)
    assign_chores!(proposal.except(*keep))
    proposal
  end
end
