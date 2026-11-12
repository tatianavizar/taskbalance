# A task of the catalogue (db/seeds.rb). `key` is stable: the seeds find a
# task by its key, so its French name can change without touching the chores
# that use it. The defaults (loads, frequency, duration) prefill the chore a
# household creates from it; the household can change them on its chore.
# `recurring` marks the regular tasks, ticked by default in the catalogue (C1).
class Task < ApplicationRecord
  include Recurrence

  has_many :chores

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :name, presence: true
  validates :time_required, presence: true, numericality: { greater_than: 0 }
  validates :priority, presence: true, inclusion: { in: 1..5 }
  validates :recurring, inclusion: { in: [ true, false ] }

  # The attributes a new household chore takes from this task.
  def chore_defaults
    {
      task_id: id,
      mental_load: default_mental_load,
      execution_load: default_execution_load,
      frequency: frequency,
      times_per_period: times_per_period,
      time_required: time_required
    }
  end
end
