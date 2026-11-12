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
  # Outbox for lot 8 (EngineEvent): nothing is sent from here.
  has_many :engine_events, dependent: :delete_all
  has_many :member_pauses, through: :household_members

  # setting_up is set by the setup flow (lot 2); solo/active follow the member
  # count; warned, blocked and dormant are set by WeeklyEngine at the final
  # report (docs/backend-backlog.md 2.2).
  enum :state, {
    setting_up: "setting_up", solo: "solo", active: "active",
    warned: "warned", blocked: "blocked", dormant: "dormant"
  }, default: "solo", validate: true

  before_validation { self.name = name.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  # Creates the household and makes `user` its manager, in one transaction.
  # Returns the household: check `persisted?` and `errors`. A user who already
  # has a household gets an error on :base and nothing is created.
  def self.create_for(user, attributes = {})
    household = new(attributes)
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
end
