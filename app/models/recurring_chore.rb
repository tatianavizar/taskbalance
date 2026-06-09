class RecurringChore < ApplicationRecord
  belongs_to :household
  belongs_to :task
  belongs_to :assigned_to, class_name: "User", foreign_key: :assigned_to_id, optional: true
  has_many :chores, dependent: :nullify

  enum :frequency, { daily: 0, weekly: 1, monthly: 2, annually: 3 }

  validates :frequency, presence: true
  validates :task_id, presence: true
  validates :household_id, presence: true

  scope :active, -> { where(active: true) }

  def effective_time_required
    time_required || task.time_required
  end
end
