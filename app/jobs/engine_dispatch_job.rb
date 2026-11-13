# Recurring (config/recurring.yml, every 15 minutes): enqueues one
# HouseholdEngineJob per household that has something due, nothing when
# nothing is. Cheap by design (one indexed UPDATE ... RETURNING per batch of
# 1000); the work is done by the `engine` queue workers. See EngineCycle.
class EngineDispatchJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    EngineCycle.enqueue_due(now: now)
  end
end
