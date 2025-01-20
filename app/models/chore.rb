class Chore < ApplicationRecord
  belongs_to :household
  belongs_to :task
  belongs_to :user, optional: true

  enum status: { pending: 0, in_progress: 1, completed: 2 }

  validates :task_id, presence: true
  validates :household_id, presence: true
  validates :status, presence: true, inclusion: { in: ["pending", "in_progress", "completed"] }
end
