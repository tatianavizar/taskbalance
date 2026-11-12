# One planned occurrence of a chore in a local week (lot 4). Written by
# RecurringChoreScheduler, never by a person. It has no status of its own:
# each assignee has done it when one of their ChoreLogs points at it, and
# deleting that log reopens it for them. A chore shared by two people has
# one occurrence that each of them ticks off (decision D6: every assignee
# carries it in full).
#
# Deleting the chore deletes its occurrences; the logs stay, detached.
class ChoreOccurrence < ApplicationRecord
  belongs_to :household
  belongs_to :chore
  has_many :chore_logs, foreign_key: :occurrence_id, inverse_of: :occurrence, dependent: :nullify

  validates :week_start, :due_on, presence: true
  validates :slot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :in_week, ->(week) { where(week_start: week.monday) }
  scope :of_active_chores, -> { joins(:chore).merge(Chore.active) }

  # Chores that come back by themselves (daily, weekly) lapse with their
  # week: tomorrow's occurrence replaces them. The others (monthly, yearly,
  # one-off) stay late until someone does them.
  def self.carried_over(household, week)
    of_active_chores.where(household_id: household.id).where(week_start: ...week.monday)
      .where(chores: { frequency: Chore.frequencies.values_at("monthly", "annually", "once") })
  end

  def done_by?(user_id)
    done_by_ids.include?(user_id)
  end

  def done_by_ids
    chore_logs.map(&:user_id)
  end
end
