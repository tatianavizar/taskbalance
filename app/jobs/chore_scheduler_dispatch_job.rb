# Recurring (config/recurring.yml, every 15 minutes): enqueues a
# HouseholdChoreSchedulerJob for each household whose Monday has begun in its
# own time zone and whose week is not scheduled yet. Nothing is enqueued the
# rest of the week. See RecurringChoreScheduler.
class ChoreSchedulerDispatchJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    RecurringChoreScheduler.enqueue_due(now: now)
  end
end
