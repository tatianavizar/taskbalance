class ChoreLog < ApplicationRecord
  # A log belongs to the individual who did the work. Its chore and household
  # are nullified rather than cascaded when they are destroyed, so the log
  # survives them (see CLAUDE.md, "Data ownership rule"). chore_name and
  # category are snapshotted at creation so a detached log stays meaningful.
  belongs_to :user
  belongs_to :chore, optional: true
  belongs_to :household, optional: true
  # The planned occurrence this log ticked off, if it came from « Fait » or
  # from a task of the Tasks tab (lot 4). Nullified with the occurrence.
  belongs_to :occurrence, class_name: "ChoreOccurrence", optional: true

  before_validation :snapshot_chore_details, on: :create
  # The home and the Tasks tab refresh live for every member (lot 4).
  after_commit :broadcast_home_refresh

  validates :chore_name, presence: true
  validates :time_spent, presence: true, numericality: { greater_than: 0 }
  validates :completed_at, presence: true
  validate :at_least_one_load_dimension
  validate :user_must_belong_to_household, on: :create

  # True once the originating chore or household has been destroyed.
  def detached?
    chore_id.nil? || household_id.nil?
  end

  def author?(user)
    user.present? && user_id == user.id
  end

  # The zone the day of this log is read in: its household's, else the
  # author's (a detached log is still the author's).
  def time_zone
    household&.time_zone || user&.time_zone || "Europe/Paris"
  end

  def week
    Week.containing(completed_at, time_zone)
  end

  # The local day it counts for.
  def completed_on
    completed_at.in_time_zone(time_zone).to_date
  end

  # False once the week's final report is stored (it is never rewritten, so a
  # correction then only changes the journal), or when the log has no
  # household left. WeeklyStats reads logs live only for the current week.
  def counts_in_report?
    return false if household_id.nil?

    !HouseholdWeek.final.exists?(household_id: household_id, week_start: week.monday)
  end

private

  def broadcast_home_refresh
    id = household_id || household_id_before_last_save
    return if id.nil?

    Turbo::StreamsChannel.broadcast_refresh_to(Household.home_stream(id))
  end

  def snapshot_chore_details
    return if chore.nil?

    self.chore_name ||= chore.effective_name
    self.category ||= chore.effective_category
    self.household_id ||= chore.household_id
  end

  # The completion form lets you log on another member's behalf, so the posted
  # user_id has to be checked against the household rather than trusted.
  # Skipped when household is nil, which is how a detached log looks.
  def user_must_belong_to_household
    return if household.nil? || user_id.nil?

    unless household.user_ids.include?(user_id)
      errors.add(:user_id, I18n.t("activerecord.errors.models.chore_log.attributes.user_id.not_a_member"))
    end
  end

  def at_least_one_load_dimension
    unless mental_load || execution_load
      errors.add(:base, I18n.t("activerecord.errors.models.chore_log.attributes.base.at_least_one_load"))
    end
  end
end
