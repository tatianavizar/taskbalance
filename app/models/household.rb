class Household < ApplicationRecord
  include TimeZoned

  NAME_MAX_LENGTH = 60

  has_many :household_members, dependent: :destroy
  has_many :users, through: :household_members
  has_many :chores, dependent: :destroy
  has_many :chore_occurrences, dependent: :delete_all
  # Logs are the members' own data and survive the household being deleted.
  has_many :chore_logs, dependent: :nullify
  has_many :invitations, dependent: :destroy
  # Weekly engine (lot 5a). Final reports are read-only records, so they go
  # with SQL deletes (the foreign keys also cascade).
  has_many :household_weeks, dependent: :delete_all
  has_many :level_changes, dependent: :delete_all
  has_many :absence_inquiries, dependent: :delete_all
  has_many :week_corrections, dependent: :delete_all
  # Outbox for lot 8 (EngineEvent): nothing is sent from here.
  has_many :engine_events, dependent: :delete_all
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

  # A member arrived or left (decision 2026-11-12): the level measures the
  # balance between these people, so level, balanced-weeks counter and
  # ultimate window go back to zero. Report history stays. Logs one
  # membership_changed LevelChange, only when something was not already zero
  # (a first member, or a solo household gaining its second, logs nothing).
  def reset_progression_for_membership_change!
    return if level.zero? && balanced_weeks_count.zero? && ultimate_reached_on.nil?

    transaction do
      level_changes.create!(from_level: level, to_level: 0, balanced_weeks_count_before: balanced_weeks_count,
                            balanced_weeks_count_after: 0, reason: :membership_changed, week_start: current_week.monday)
      update!(level: 0, balanced_weeks_count: 0, ultimate_reached_on: nil)
    end
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
    notify_invitees_ready if setup_done?
  end

  # The invited person can give their preferences and see the split (B10,
  # B11, B14) once the set-up is over: tasks chosen and the split proposed,
  # or « Attendre » chosen. Until then they wait on B12.
  def setup_ready_for_invitee?
    setup_done?
  end

  # --- Split -------------------------------------------------------------

  # Invitations still waiting for an answer: pending and not past their date.
  def pending_invitations
    invitations.live.order(:id)
  end

  # The people a split is made for, in display order: members by arrival,
  # then (for the starting split) people invited but not yet in (D15).
  def split_participants(include_invitations: true)
    members = household_members.includes(:user).order(:created_at, :id).to_a
    participants = members.map { |member| SplitParticipant.for_member(member) }
    return participants unless include_invitations

    free_colors = HouseholdMember::COLORS - members.map(&:color)
    participants + pending_invitations.each_with_index.map do |invitation, index|
      SplitParticipant.for_invitation(invitation, color: free_colors[index] || HouseholdMember::COLORS.last,
                                      user: invitation.invitee)
    end
  end

  # The participant acting as `user`: a member, or someone invited who has
  # not joined yet (B10, B11, B14). nil when `user` has no part in the split.
  def split_participant_for(user)
    return if user.nil?

    split_participants.find { |p| !p.provisional? && p.user_id == user.id } || invitee_participant_for(user)
  end

  # Pre-join access (lot 3): the person who claimed a live invitation of this
  # household, while Invitation#grants_setup_access_to? holds.
  def invitee_participant_for(user)
    invitation = invitations.live.find_by(invitee_id: user.id)
    return unless invitation&.grants_setup_access_to?(user)

    split_participants.find { |p| p.invitation_id == invitation.id }
  end

  # The starting split, if the set-up has made one.
  def starting_plan
    week_plans.starting.order(:week_start).last
  end

  # The stream the home and the Tasks tab listen to: a log, an edit or a
  # deletion refreshes both for every member (lot 4).
  def self.home_stream(household_or_id)
    [ "household", household_or_id.respond_to?(:id) ? household_or_id.id : household_or_id, "home" ].join(":")
  end

  def week_plan_for(week = current_week)
    week_plans.find_by(week_start: week.monday)
  end

  # Writes the assignees of several chores at once, { chore_id => [keys] },
  # for this household's chores only. Raises ActiveRecord::RecordInvalid
  # (nothing written) when a chore would have no assignee or an assignee is
  # not a participant.
  #
  # `by`: the person assigning. Members newly given a chore by someone else
  # hear about it (task_assigned); a proposal (no `by`) is announced as a
  # whole instead (monday_split).
  def assign_chores!(assignments, by: nil)
    assignments = assignments.to_h.transform_keys(&:to_i)
    added = []
    transaction do
      chores.where(id: assignments.keys).includes(:chore_assignees, :task).find_each do |chore|
        before = chore.assignee_keys
        chore.assignee_keys = assignments[chore.id]
        chore.save!
        added << [ chore, chore.assignee_keys - before ]
      end
    end
    added.each { |chore, keys| chore.notify_assignees(keys, by: by) } if by
  end

  # Assigns chores from the proposal (D18). `keep`: chore ids whose
  # assignees stay. Returns the proposal.
  def propose_split!(keep: [])
    proposal = SplitProposal.for_household(self, keep: keep)
    assign_chores!(proposal.except(*keep))
    proposal
  end

  private

  # B12 « Prêt »: the people who claimed an invitation and waited.
  def notify_invitees_ready
    invitations.live.where.not(invitee_id: nil).includes(:invitee).find_each do |invitation|
      Notifications::Notifier.call(Notifications::Events::HouseholdReady.new(self, invitation.invitee))
    end
  end
end
