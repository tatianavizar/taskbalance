# One household's turn of the weekly engine (EngineCycle.run): engine, Monday
# split, delivery of the outbox. Enqueued in batches by EngineDispatchJob.
#
# Safe to run twice, even at the same time: the engine locks the household
# row and every step is idempotent. The concurrency limit (one run per
# household, Solid Queue) only keeps a duplicate from waiting on the lock.
# An error is isolated to this household and retried with a growing delay;
# if every attempt fails the household stays due and the dispatcher enqueues
# it again once its claim has gone stale.
class HouseholdEngineJob < ApplicationJob
  queue_as :engine

  limits_concurrency to: 1, key: ->(household_id, *) { household_id }, group: "household_engine", duration: 15.minutes

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound # household deleted since

  def perform(household_id, now: nil)
    EngineCycle.run(Household.find(household_id), now: now || Time.current)
  end
end
