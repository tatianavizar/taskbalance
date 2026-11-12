# Recurring (config/recurring.yml, every 15 minutes): runs the weekly engine of
# every household (WeeklyEngine.run_all, the only loop), then the Monday
# split proposal (WeeklySplit, lot 6), then delivers what each run recorded
# in the engine_events outbox (Notifications::Dispatcher).
# Safe to run at any time and as often as wanted: every step is idempotent,
# and an event is marked delivered only once notified, so a dispatch that
# failed is replayed next time without duplicates. A failure in a later step
# never undoes an earlier one, and never stops the other households.
class WeeklyEngineJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    WeeklyEngine.run_all(now: now) do |household, _result|
      step(household, "split") { WeeklySplit.new(household).run(now: now) }
      step(household, "notifications") { Notifications::Dispatcher.deliver_pending(household, now: now) }
    end
  end

  private

  def step(household, name)
    yield
  rescue StandardError => e
    Rails.error.report(e, context: { household_id: household.id, step: name })
  end
end
