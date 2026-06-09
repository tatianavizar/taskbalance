class Chore < ApplicationRecord
  belongs_to :household
  belongs_to :task
  belongs_to :user, optional: true

  enum :status, { pending: 0, in_progress: 1, completed: 2 }

  validates :task_id, presence: true
  validates :household_id, presence: true
  validate :at_least_one_load_dimension, if: :user_id?

private

  def at_least_one_load_dimension
    unless mental_load || execution_load
      errors.add(:base, "Au moins une dimension de charge doit être renseignée (mentale ou exécution)")
    end
  end
end
