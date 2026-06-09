class Chore < ApplicationRecord
  belongs_to :household
  belongs_to :task
  belongs_to :assigned_to, class_name: "User", foreign_key: :assigned_to_id, optional: true
  belongs_to :recurring_chore, optional: true
  has_many :chore_logs, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2 }

  validates :task_id, presence: true
  validates :household_id, presence: true
  validate :at_least_one_load_dimension, if: :assigned_to_id?

  def effective_time_required
    time_required || task.time_required
  end

private

  def at_least_one_load_dimension
    unless mental_load || execution_load
      errors.add(:base, I18n.t("activerecord.errors.models.chore.attributes.base.at_least_one_load"))
    end
  end
end
