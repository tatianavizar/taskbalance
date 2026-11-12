# Runs the weekly engine of every household, serially and inline, whether it
# is due or not (EngineCycle.run_all): for development (async adapter, no
# Solid Queue tables), tests and `bin/rails runner WeeklyEngineJob.perform_now`.
# Production schedules EngineDispatchJob instead, which fans out one
# HouseholdEngineJob per due household.
class WeeklyEngineJob < ApplicationJob
  queue_as :engine

  def perform(now: Time.current)
    EngineCycle.run_all(now: now)
  end
end
