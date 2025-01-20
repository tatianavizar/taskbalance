class Task < ApplicationRecord
  has_many :chores
  has_many :liked_tasks

  validates :name, presence: true
  validates :time_required, presence: true, numericality: { greater_than: 0 }
  validates :priority, presence: true, inclusion: { in: 1..5 }
end
