class Chore < ApplicationRecord
  CATEGORIES = %w[cooking groceries cleaning laundry childcare admin maintenance other].freeze

  belongs_to :household
  belongs_to :task, optional: true
  belongs_to :assigned_to, class_name: "User", foreign_key: :assigned_to_id, optional: true
  belongs_to :recurring_chore, optional: true
  has_many :chore_logs, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2 }

  validates :household_id, presence: true
  validate :task_or_custom_name_present
  validate :at_least_one_load_dimension, if: :assigned_to_id?

  def catalogue_chore?
    task_id.present?
  end

  def custom_chore?
    task_id.nil?
  end

  def effective_name
    task&.name || custom_name
  end

  def effective_category
    task&.category || category
  end

  def effective_time_required
    time_required || task&.time_required
  end

private

  def task_or_custom_name_present
    return if task_id.present? || custom_name.present?
    errors.add(:base, I18n.t("activerecord.errors.models.chore.attributes.base.task_or_name_required"))
  end

  def at_least_one_load_dimension
    unless mental_load || execution_load
      errors.add(:base, I18n.t("activerecord.errors.models.chore.attributes.base.at_least_one_load"))
    end
  end
end
