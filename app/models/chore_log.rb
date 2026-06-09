class ChoreLog < ApplicationRecord
  belongs_to :chore
  belongs_to :user
  belongs_to :household

  validates :time_spent, presence: true, numericality: { greater_than: 0 }
  validates :completed_at, presence: true
  validate :at_least_one_load_dimension

private

  def at_least_one_load_dimension
    unless mental_load || execution_load
      errors.add(:base, I18n.t("activerecord.errors.models.chore_log.attributes.base.at_least_one_load"))
    end
  end
end
