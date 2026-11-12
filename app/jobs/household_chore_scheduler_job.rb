# Writes one household's occurrences for its current local week. Idempotent
# (unique index on chore, week and slot), so a duplicate or an overlapping run
# writes nothing new. Retried with a growing delay; if every attempt fails the
# household stays unscheduled and is enqueued again once its claim is stale.
class HouseholdChoreSchedulerJob < ApplicationJob
  queue_as :engine

  limits_concurrency to: 1, key: ->(household_id, *) { household_id }, group: "household_chore_scheduler", duration: 5.minutes

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(household_id)
    RecurringChoreScheduler.run_household(Household.find(household_id))
  end
end
