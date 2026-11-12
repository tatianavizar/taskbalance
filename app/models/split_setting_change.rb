# A change of the split settings (C16), waiting for every member's
# validation (decision 2026-11-08). One pending change per household: a new
# request withdraws the previous one. The member who asks validates it at
# once; it applies when the last member validates. A household of one
# applies it immediately.
class SplitSettingChange < ApplicationRecord
  SETTINGS = %w[weekly_proposal_enabled gap_carry_over_enabled auto_validate_splits].freeze

  belongs_to :household
  belongs_to :proposed_by, class_name: "User", optional: true
  has_many :approvals, as: :approvable, dependent: :delete_all

  enum :status, { pending: "pending", applied: "applied", withdrawn: "withdrawn" }, validate: true

  validate :changes_are_settings

  # `changes`: { setting => true/false }. Only the settings that differ from
  # the household's are kept; nil when nothing changes.
  def self.request!(household:, by:, changes:)
    wanted = changes.to_h.stringify_keys.slice(*SETTINGS)
                    .transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
                    .reject { |setting, value| household.public_send(setting) == value }
    return nil if wanted.empty?

    transaction do
      household.split_setting_changes.pending.find_each { |change| change.update!(status: :withdrawn) }
      change = household.split_setting_changes.create!(proposed_by: by, changes_requested: wanted)
      change.approve!(by: by)
      change
    end
  end

  def approve!(by:)
    raise WeekPlan::NotAParticipant unless household.users.exists?(by.id)
    return true if applied?

    transaction do
      approvals.find_or_create_by!(user: by)
      apply! if pending_members.empty?
    end
    applied?
  end

  # Members who have not validated yet, oldest first.
  def pending_members
    approved = approvals.pluck(:user_id)
    household.household_members.includes(:user).order(:created_at, :id).reject { |m| approved.include?(m.user_id) }
  end

  private

  def apply!
    household.update!(changes_requested)
    update!(status: :applied, applied_at: Time.current)
  end

  def changes_are_settings
    errors.add(:changes_requested, :invalid) unless changes_requested.is_a?(Hash) && (changes_requested.keys - SETTINGS).empty?
  end
end
