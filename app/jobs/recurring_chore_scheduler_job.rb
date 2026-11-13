# Writes every household's occurrences for its current local week, inline and
# without selection (RecurringChoreScheduler.run_all): for development, tests
# and `bin/rails runner`. Production schedules ChoreSchedulerDispatchJob.
class RecurringChoreSchedulerJob < ApplicationJob
  queue_as :engine

  def perform
    RecurringChoreScheduler.run_all
  end
end
