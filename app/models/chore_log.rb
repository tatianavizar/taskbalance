class ChoreLog < ApplicationRecord
  # A log belongs to the individual who did the work. Its chore and household
  # are nullified rather than cascaded when they are destroyed, so the log
  # survives them (see CLAUDE.md, "Data ownership rule"). chore_name and
  # category are snapshotted at creation so a detached log stays meaningful.
  belongs_to :user
  belongs_to :chore, optional: true
  belongs_to :household, optional: true

  before_validation :snapshot_chore_details, on: :create

  validates :chore_name, presence: true
  validates :time_spent, presence: true, numericality: { greater_than: 0 }
  validates :completed_at, presence: true
  validate :at_least_one_load_dimension
  validate :user_must_belong_to_household, on: :create

  # True once the originating chore or household has been destroyed.
  def detached?
    chore_id.nil? || household_id.nil?
  end

private

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
