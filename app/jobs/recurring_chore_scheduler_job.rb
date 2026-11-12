# Writes every household's occurrences for its current local week. Idempotent,
# so it runs often (config/recurring.yml): a household whose Monday has just
# begun in its time zone gets its week within minutes.
class RecurringChoreSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    RecurringChoreScheduler.run_all
  end
end
